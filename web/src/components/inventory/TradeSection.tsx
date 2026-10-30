import type { MouseEvent } from 'react';
import { formatNumber, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { ItemStack, TradeData, TradeOffer } from '../../types/game';
import { stacksOf, weightOf } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';
import { useDrag } from './DragProvider';
import { DropZone } from './DropZone';
import { ItemTile } from './ItemTile';

interface TradeSectionProps {
  trade: TradeData;
  selected: string | null;
  onSelect: (name: string) => void;
  /** Double-clic ou Alt + clic sur son offre : l'objet est retiré de l'échange */
  onRemove: (stack: ItemStack) => void;
  onItemContextMenu: (event: MouseEvent, stack: ItemStack) => void;
}

const corner = (stack: ItemStack): string =>
  stack.item.type === 'money' ? formatNumber(stack.count) : `x${stack.count}`;

/** État d'une offre : en cours, prête, confirmée. */
function OfferStatus({ offer }: { offer: TradeOffer }) {
  const t = useT();
  if (offer.confirmed) return <span className="chip trade__status trade__status--confirmed">{t('Confirmé')}</span>;
  if (offer.ready) return <span className="chip trade__status trade__status--ready">{t('Prêt')}</span>;
  return <span className="chip chip--outline trade__status">{t('En cours')}</span>;
}

/**
 * Échange avec un autre joueur (/trade) : on glisse ses objets dans « Ton offre », chacun passe
 * « Prêt », puis les deux confirment. Toute modification d'une offre retire les « Prêt ».
 */
export function TradeSection({ trade, selected, onSelect, onRemove, onItemContextMenu }: TradeSectionProps) {
  const t = useT();
  const { state, actions } = useGame();
  const { drag, begin } = useDrag();
  const { config } = state;
  const mine = stacksOf(trade.mine.items, config);
  const theirs = stacksOf(trade.theirs.items, config);
  const bothReady = trade.mine.ready && trade.theirs.ready;

  return (
    <section className="container container--trade">
      <SectionTitle
        title={t('Échange · {name}', { name: trade.partner.name })}
        icon={<Icon name="trade" size={15} strokeWidth={2.4} className="trade-icon" />}
        badge={<span className="muted container__note">ID {trade.partner.id}</span>}
        aside={
          <button className="btn btn--small btn--danger" onClick={() => void actions.tradeCancel()}>
            {t('Annuler')}
          </button>
        }
      />

      <div className="trade__side">
        <div className="trade__head">
          <span className="disp trade__title">{t('Ton offre')}</span>
          <OfferStatus offer={trade.mine} />
        </div>
        <DropZone target={{ kind: 'trade' }} className="tile-grid container__grid trade__grid">
          {mine.map((stack) => (
            <ItemTile
              key={stack.name}
              name={stack.name}
              item={stack.item}
              corner={corner(stack)}
              selected={selected === stack.name}
              dragging={drag?.source.kind === 'trade' && drag.source.item === stack.name}
              onClick={(event) => (event.altKey ? onRemove(stack) : onSelect(stack.name))}
              onDragBegin={(event) => begin({ kind: 'trade', item: stack.name, count: stack.count }, event)}
              onDoubleClick={() => onRemove(stack)}
              onContextMenu={(event) => onItemContextMenu(event, stack)}
            />
          ))}
          {mine.length === 0 && <p className="mono trade__empty">{t('GLISSE ICI CE QUE TU DONNES')}</p>}
        </DropZone>
      </div>

      <div className="trade__side">
        <div className="trade__head">
          <span className="disp trade__title">{t('Offre de {name}', { name: trade.partner.name })}</span>
          <OfferStatus offer={trade.theirs} />
        </div>
        <div className="tile-grid container__grid trade__grid">
          {theirs.map((stack) => (
            <ItemTile key={stack.name} name={stack.name} item={stack.item} corner={corner(stack)} />
          ))}
          {theirs.length === 0 && <p className="mono trade__empty">{t('RIEN POUR L\'INSTANT')}</p>}
        </div>
      </div>

      <p className="muted trade__note">
        {t('Tu reçois dans ton sac ({weight} KG). Toute modification d\'une offre retire les « Prêt » des deux joueurs.', {
          weight: weightOf(trade.theirs.items, config).toFixed(1),
        })}
      </p>

      <div className="trade__actions">
        <button
          className={trade.mine.ready ? 'btn btn--active' : 'btn btn--primary'}
          onClick={() => void actions.tradeReady(!trade.mine.ready)}
        >
          {trade.mine.ready ? t('Modifier mon offre') : t('Prêt')}
        </button>
        <button
          className="btn btn--primary"
          disabled={!bothReady || trade.mine.confirmed}
          onClick={() => void actions.tradeConfirm()}
        >
          {trade.mine.confirmed ? t('En attente de {name}…', { name: trade.partner.name }) : t('Confirmer l\'échange')}
        </button>
      </div>
    </section>
  );
}
