import type { MouseEvent } from 'react';
import { useGame } from '../../store/GameContext';
import type { ContainerId, ItemStack, ItemStacks } from '../../types/game';
import { stacksOf, weightOf } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';
import { SegmentBar } from '../ui/SegmentBar';
import type { DragSource } from './drag';
import { DropZone } from './DropZone';
import { ItemTile } from './ItemTile';

export interface Selection {
  name: string;
  container: ContainerId;
}

interface ContainerSectionProps {
  id: ContainerId;
  stacks: ItemStacks;
  drag: DragSource | null;
  selection: Selection | null;
  onSelect: (selection: Selection) => void;
  onDragStart: (source: DragSource) => void;
  onDragEnd: () => void;
  onDrop: (target: ContainerId) => void;
  onItemContextMenu: (event: MouseEvent, stack: ItemStack, container: ContainerId) => void;
  onItemDoubleClick: (stack: ItemStack) => void;
}

export function ContainerSection({
  id, stacks, drag, selection,
  onSelect, onDragStart, onDragEnd, onDrop, onItemContextMenu, onItemDoubleClick,
}: ContainerSectionProps) {
  const { state } = useGame();
  const { config } = state;
  const definition = config.containers[id];
  const weight = weightOf(stacks, config);
  const isProtected = id === 'protected';
  const accepts = drag?.kind === 'container' && drag.container !== id;

  return (
    <section className={isProtected ? 'container container--protected' : 'container'}>
      <SectionTitle
        title={definition.label}
        icon={isProtected ? <Icon name="lock" size={15} strokeWidth={2.4} className="protected-icon" /> : undefined}
        badge={
          isProtected
            ? <span className="muted container__note">Conservé à la mort</span>
            : <span className="chip chip--outline">Perdu à la mort</span>
        }
        aside={`${weight.toFixed(1)}KG / ${definition.capacity.toFixed(0)}KG`}
      />
      <SegmentBar
        value={weight}
        max={definition.capacity}
        segments={isProtected ? 20 : 40}
        color={isProtected ? 'var(--abri)' : undefined}
        warnFrom={0.9}
        height={3}
      />
      <DropZone className="tile-grid container__grid" accepts={accepts} onDrop={() => onDrop(id)}>
        {stacksOf(stacks, config).map((stack) => (
          <ItemTile
            key={stack.name}
            name={stack.name}
            item={stack.item}
            corner={stack.item.type === 'money' ? `$${stack.count.toLocaleString('fr-FR')}` : `x${stack.count}`}
            selected={selection?.name === stack.name && selection.container === id}
            protectedItem={isProtected}
            onClick={() => onSelect({ name: stack.name, container: id })}
            onDragStart={() => onDragStart({ kind: 'container', container: id, item: stack.name, count: stack.count })}
            onDragEnd={onDragEnd}
            onDoubleClick={() => onItemDoubleClick(stack)}
            onContextMenu={(event) => onItemContextMenu(event, stack, id)}
          />
        ))}
      </DropZone>
    </section>
  );
}
