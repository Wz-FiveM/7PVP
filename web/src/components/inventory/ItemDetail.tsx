import { useGame } from '../../store/GameContext';
import type { ContainerId, ItemStack } from '../../types/game';
import { entriesOf, itemLabel, otherContainer } from '../../utils/inventory';
import { Panel } from '../ui/Panel';

const TYPE_LABEL = { weapon: 'Arme', ammo: 'Munitions', consumable: 'Soin', money: 'Argent' } as const;

interface ItemDetailProps {
  stack: ItemStack | null;
  container: ContainerId | null;
  onMove: () => void;
  onDrop: () => void;
}

/** Fiche de l'objet sélectionné et ses actions. */
export function ItemDetail({ stack, container, onMove, onDrop }: ItemDetailProps) {
  const { state, actions } = useGame();
  const { config, player } = state;

  if (!stack || !container || !player) {
    return (
      <Panel className="detail detail--empty">
        <span className="label">Objet sélectionné</span>
        <p className="muted">Clique sur un objet pour voir sa fiche.</p>
      </Panel>
    );
  }

  const { item } = stack;
  const ammoCount = item.ammo
    ? [player.inventory.bag, player.inventory.protected]
        .flatMap((stacks) => entriesOf(stacks))
        .filter(([name]) => name === item.ammo)
        .reduce((total, [, count]) => total + count, 0)
    : null;

  const meta = [TYPE_LABEL[item.type], item.ammo && itemLabel(config, item.ammo), `${item.weight} KG`]
    .filter(Boolean)
    .join(' · ');

  return (
    <Panel className="detail">
      <span className="label">Objet sélectionné</span>
      <h3 className="disp detail__name">{item.label}</h3>
      <span className="mono muted detail__meta">{meta.toUpperCase()}</span>

      <dl className="detail__facts">
        <div>
          <dt className="muted">Quantité</dt>
          <dd className="mono">{stack.count}</dd>
        </div>
        {ammoCount !== null && (
          <div>
            <dt className="muted">Munitions disponibles</dt>
            <dd className="mono">{ammoCount}</dd>
          </div>
        )}
        {item.heal !== undefined && (
          <div>
            <dt className="muted">Soigne</dt>
            <dd className="mono">+{item.heal} PV</dd>
          </div>
        )}
        {item.armor !== undefined && (
          <div>
            <dt className="muted">Armure</dt>
            <dd className="mono">+{item.armor}</dd>
          </div>
        )}
      </dl>

      <div className="detail__actions">
        {item.type === 'weapon' && (
          <button className="btn btn--primary cut-s" onClick={() => actions.equip(stack.name)}>
            Équiper
          </button>
        )}
        {item.type === 'consumable' && (
          <button className="btn btn--primary cut-s" onClick={() => actions.consumeItem(stack.name)}>
            Utiliser
          </button>
        )}
        <button className="btn cut-s" onClick={onMove}>
          {otherContainer(container) === 'protected' ? 'Protéger' : 'Vers le sac'}
        </button>
        <button className="btn btn--danger cut-s" onClick={onDrop}>
          Jeter
        </button>
      </div>
    </Panel>
  );
}
