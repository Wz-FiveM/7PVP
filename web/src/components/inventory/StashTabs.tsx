import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { StashId } from '../../types/game';
import { formatMoney } from '../../utils/format';
import { isUnlocked, stashIds } from '../../utils/inventory';
import { Icon } from '../icons/Icon';

/** Onglet affiché chez le banquier : un coffre personnel, celui du crew ou les sets d'équipement. */
export type BankerTab = StashId | 'crew' | 'sets';

interface StashTabsProps {
  active: BankerTab;
  onChange: (id: BankerTab) => void;
}

/** Onglets des coffres chez le banquier : les coffres payants pas encore achetés sont cadenassés. */
export function StashTabs({ active, onChange }: StashTabsProps) {
  const t = useT();
  const { state } = useGame();
  const { player, config, crew } = state;
  if (!player) return null;

  return (
    <div className="stash-tabs">
      {stashIds(config).map((id) => {
        const open = isUnlocked(player.inventory, config, id);
        return (
          <button
            key={id}
            className={`btn btn--small cut-s stash-tabs__tab${id === active ? ' btn--active' : ''}${open ? '' : ' stash-tabs__tab--locked'}`}
            onClick={() => onChange(id)}
          >
            {!open && <Icon name="lock" size={13} strokeWidth={2.4} />}
            {t(config.containers[id]?.label ?? id)}
          </button>
        );
      })}
      {crew && (
        <button className={`btn btn--small cut-s stash-tabs__tab${active === 'crew' ? ' btn--active' : ''}`} onClick={() => onChange('crew')}>
          {t('Crew [{tag}]', { tag: crew.tag })}
        </button>
      )}
      <button className={`btn btn--small cut-s stash-tabs__tab${active === 'sets' ? ' btn--active' : ''}`} onClick={() => onChange('sets')}>
        {t('Sets')}
      </button>
    </div>
  );
}

/** Coffre pas encore acheté : prix et bouton d'achat (argent porté, vérifié par le serveur). */
export function StashPurchase({ id }: { id: StashId }) {
  const t = useT();
  const { state, actions } = useGame();
  const definition = state.config.containers[id];
  if (!definition?.price || !state.player) return null;
  const affordable = state.player.money >= definition.price;

  return (
    <section className="container stash-purchase">
      <p className="mono stash-purchase__text">
        {t(definition.label).toUpperCase()} · {t('{capacity}KG EN SÉCURITÉ · ACHAT DÉFINITIF', { capacity: definition.capacity.toFixed(0) })}
      </p>
      <button className="btn btn--primary btn--small cut-s" disabled={!affordable} onClick={() => actions.unlockStash(id)}>
        {t('Acheter · {price}', { price: formatMoney(definition.price) })}
      </button>
      {!affordable && <p className="muted stash-purchase__hint">{t('Il te faut l\'argent sur toi (sac ou conteneur protégé).')}</p>}
    </section>
  );
}
