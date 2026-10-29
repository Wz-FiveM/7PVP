import type { CSSProperties } from 'react';
import { Icon } from '../components/icons/Icon';
import { ItemIcon } from '../components/inventory/ItemIcon';
import { Panel } from '../components/ui/Panel';
import { useGame } from '../store/GameContext';
import { formatChance, rarityOf, rewardCountLabel, sortedRewards, totalWeight } from '../utils/cases';
import { entriesOf, itemLabel, stashIds } from '../utils/inventory';
import type { ItemStacks } from '../types/game';
import { formatMoney, formatPoints } from '../utils/format';
import '../components/cases/cases.css';
import './pages.css';

/** Caisses : achat chez l'armurier, ouverture n'importe où hors combat, contenu et chances affichés. */
export function CasesPage() {
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  if (!player) return null;

  // Caisses portées (sac + conteneur protégé) : celles des coffres doivent d'abord en sortir
  const countIn = (stacks: ItemStacks[], id: string) =>
    stacks.flatMap(entriesOf)
      .filter(([name]) => name === id)
      .reduce((total, [, count]) => total + count, 0);
  const carried = (id: string) => countIn([player.inventory.bag, player.inventory.protected], id);
  const stored = (id: string) => countIn(stashIds(config).map((stash) => player.inventory[stash] ?? []), id);

  const points = config.shopPoints;
  const balance = player.shopPoints ?? 0;

  return (
    <>
      <div className="cases__bar">
        <p className="hint cut-s">
          {menu.near.shop
            ? 'Les caisses achetées vont dans le sac : perdues à la mort tant qu\'elles ne sont pas ouvertes ou protégées.'
            : 'Achat auprès de l\'armurier, en zone safe. Les caisses s\'ouvrent partout, hors combat.'}
          {' '}Payée en {(points?.label ?? 'points boutique').toLowerCase()}, une caisse s'ouvre aussitôt, partout.
        </p>
        <span className="cases__points">
          <Icon name="gem" size={18} strokeWidth={2} />
          <span className="mono">{formatPoints(balance, points?.short)}</span>
          {points?.storeUrl && (
            <button className="btn btn--small cut-s" onClick={actions.openStore}>
              Boutique
            </button>
          )}
        </span>
      </div>
      <div className="cases">
        {(config.cases ?? []).map((definition) => {
          const locked = player.level < (definition.level ?? 1);
          const owned = carried(definition.id);
          const inStash = stored(definition.id);
          const total = totalWeight(definition);
          const item = config.items[definition.id];
          return (
            <Panel key={definition.id} className="case-card">
              <div className="case-card__head">
                <span className="case-card__icon cut-s">
                  <ItemIcon name={definition.id} type={item?.type ?? 'case'} />
                </span>
                <span className="case-card__title">
                  <span className="disp case-card__name">{definition.label}</span>
                  {definition.description && <span className="muted case-card__description">{definition.description}</span>}
                </span>
              </div>

              <ul className="case-card__rewards">
                {sortedRewards(config, definition).map((reward, i) => {
                  const rarity = rarityOf(config, reward.rarity);
                  return (
                    <li key={i} className="case-card__reward" style={{ '--rarity': rarity.color } as CSSProperties}>
                      <span className="case-card__rarity" title={rarity.label} />
                      <span className="case-card__reward-name">
                        {reward.item === 'money' ? 'Argent' : itemLabel(config, reward.item)}
                        <span className="mono muted"> {rewardCountLabel(reward)}</span>
                      </span>
                      <span className="mono case-card__chance">{formatChance((reward.weight / total) * 100)}</span>
                    </li>
                  );
                })}
              </ul>

              <div className="case-card__footer">
                <span className="mono muted case-card__owned">
                  PORTÉES {owned}{inStash > 0 ? ` · COFFRE ${inStash}` : ''}
                </span>
                {definition.price !== undefined ? (
                  <button
                    className="btn btn--small cut-s"
                    disabled={locked || !menu.near.shop || player.money < definition.price}
                    onClick={() => actions.buyCase(definition.id)}
                  >
                    {locked ? `Niv. ${definition.level}` : formatMoney(definition.price)}
                  </button>
                ) : (
                  <span className="chip chip--outline">Butin uniquement</span>
                )}
                {definition.points !== undefined && (
                  <button
                    className="btn btn--small cut-s case-card__points"
                    title={`Acheter et ouvrir avec des ${(points?.label ?? 'points boutique').toLowerCase()}`}
                    disabled={locked || balance < definition.points || state.caseSpin !== null}
                    onClick={() => actions.openCase(definition.id, true)}
                  >
                    <Icon name="gem" size={14} strokeWidth={2} />
                    {formatPoints(definition.points, points?.short)}
                  </button>
                )}
                <button
                  className="btn btn--primary btn--small cut-s"
                  disabled={owned <= 0 || state.caseSpin !== null}
                  onClick={() => actions.openCase(definition.id)}
                >
                  Ouvrir
                </button>
              </div>
            </Panel>
          );
        })}
      </div>
    </>
  );
}
