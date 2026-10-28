import type { MouseEvent } from 'react';
import { useGame } from '../../store/GameContext';
import type { ContainerId, ItemStack, ItemStacks } from '../../types/game';
import { entriesOf, fittedAttachments, stacksOf, weightOf } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';
import { SegmentBar } from '../ui/SegmentBar';
import { useDrag } from './DragProvider';
import { DropZone } from './DropZone';
import { ItemTile } from './ItemTile';

export interface Selection {
  name: string;
  container: ContainerId;
}

interface ContainerSectionProps {
  id: ContainerId;
  stacks: ItemStacks;
  selection: Selection | null;
  /** coffre hors zone safe : contenu caché, rien ne peut y entrer ni en sortir */
  locked?: boolean;
  onSelect: (selection: Selection) => void;
  onItemContextMenu: (event: MouseEvent, stack: ItemStack, container: ContainerId) => void;
  onItemDoubleClick: (stack: ItemStack) => void;
}

/** Apparence de chaque conteneur : badge, couleur de la jauge, nombre de segments. */
const STYLES: Record<ContainerId, { note: string; outline: boolean; color?: string; segments: number }> = {
  bag: { note: 'Perdu à la mort', outline: true, segments: 40 },
  protected: { note: 'Conservé à la mort', outline: false, color: 'var(--abri)', segments: 20 },
  stash: { note: 'Zone safe uniquement', outline: false, color: 'var(--toxine)', segments: 50 },
};

/** Quantité (ou montant) et nombre d'accessoires fixés sur une arme. */
function cornerText(stack: ItemStack, attachments: number): string {
  if (stack.item.type === 'money') return `${stack.count.toLocaleString('fr-FR')}`;
  return attachments > 0 ? `x${stack.count} +${attachments}` : `x${stack.count}`;
}

export function ContainerSection({
  id, stacks, selection, locked, onSelect, onItemContextMenu, onItemDoubleClick,
}: ContainerSectionProps) {
  const { state } = useGame();
  const { drag, begin } = useDrag();
  const { config } = state;
  const definition = config.containers[id];
  if (!definition) return null;

  const weight = weightOf(stacks, config);
  const style = STYLES[id];
  const isProtected = id === 'protected';
  const keepsItems = id !== 'bag';

  return (
    <section className={`container container--${id}${locked ? ' container--locked' : ''}`}>
      <SectionTitle
        title={definition.label}
        icon={keepsItems ? <Icon name="lock" size={15} strokeWidth={2.4} className={`${id}-icon`} /> : undefined}
        badge={
          style.outline
            ? <span className="chip chip--outline">{style.note}</span>
            : <span className="muted container__note">{style.note}</span>
        }
        aside={`${weight.toFixed(1)}KG / ${definition.capacity.toFixed(0)}KG`}
      />
      <SegmentBar
        value={weight}
        max={definition.capacity}
        segments={style.segments}
        color={style.color}
        warnFrom={0.9}
        height={3}
      />
      {locked ? (
        <p className="mono container__locked">
          {entriesOf(stacks).length} OBJET(S) EN SÉCURITÉ · REJOINS UNE ZONE SAFE POUR OUVRIR LE COFFRE
        </p>
      ) : (
        <DropZone target={{ kind: 'container', container: id }} className="tile-grid container__grid">
          {stacksOf(stacks, config).map((stack) => {
            const isDragged =
              drag?.source.kind === 'container' && drag.source.container === id && drag.source.item === stack.name;
            return (
              <ItemTile
                key={stack.name}
                name={stack.name}
                item={stack.item}
                corner={cornerText(stack, fittedAttachments(state.player?.inventory ?? {}, stack.name).length)}
                selected={selection?.name === stack.name && selection.container === id}
                protectedItem={isProtected}
                dragging={isDragged}
                onClick={() => onSelect({ name: stack.name, container: id })}
                onDragBegin={(event) =>
                  begin({ kind: 'container', container: id, item: stack.name, count: stack.count }, event)
                }
                onDoubleClick={() => id !== 'stash' && onItemDoubleClick(stack)}
                onContextMenu={(event) => onItemContextMenu(event, stack, id)}
              />
            );
          })}
        </DropZone>
      )}
    </section>
  );
}
