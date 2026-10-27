import type { MouseEvent, ReactNode } from 'react';
import { useGame } from '../../store/GameContext';
import type { ContainerId, ItemStack, ItemStacks, ItemType } from '../../types/game';
import { stacksOf, weightOf } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { Panel, PanelHeader } from '../ui/Panel';
import { SegmentBar } from '../ui/SegmentBar';
import type { DragSource } from './drag';
import { DropZone } from './DropZone';
import { EmptyTile } from './EmptyTile';
import { ItemTile } from './ItemTile';

/** Mise en forme propre à chaque conteneur */
const LAYOUT: Record<ContainerId, { columns: number; minSlots: number }> = {
  bag: { columns: 6, minSlots: 12 },
  protected: { columns: 3, minSlots: 3 },
};

export interface Selection {
  name: string;
  container: ContainerId;
}

interface ContainerPanelProps {
  id: ContainerId;
  stacks: ItemStacks;
  drag: DragSource | null;
  selection: Selection | null;
  filter?: ItemType | 'all';
  /** Contenu ajouté sous la jauge (ex : filtres) */
  toolbar?: ReactNode;
  className?: string;
  onSelect: (selection: Selection) => void;
  onDragStart: (source: DragSource) => void;
  onDragEnd: () => void;
  onDrop: (target: ContainerId) => void;
  onItemContextMenu: (event: MouseEvent, stack: ItemStack, container: ContainerId) => void;
  onItemDoubleClick: (stack: ItemStack) => void;
}

export function ContainerPanel({
  id, stacks, drag, selection, filter = 'all', toolbar, className,
  onSelect, onDragStart, onDragEnd, onDrop, onItemContextMenu, onItemDoubleClick,
}: ContainerPanelProps) {
  const { state } = useGame();
  const { config } = state;
  const definition = config.containers[id];
  const weight = weightOf(stacks, config);
  const isProtected = id === 'protected';
  const accepts = drag?.kind === 'container' && drag.container !== id;
  const layout = LAYOUT[id];

  const visible = stacksOf(stacks, config).filter((stack) => filter === 'all' || stack.item.type === filter);
  const emptySlots = Math.max(0, layout.minSlots - visible.length);

  return (
    <Panel stripes={isProtected ? 'safe' : undefined} className={className}>
      <PanelHeader
        title={definition.label}
        icon={isProtected ? <Icon name="lock" size={18} strokeWidth={2.4} className="protected-icon" /> : undefined}
        badge={isProtected ? undefined : <span className="chip chip--outline">Perdu à la mort</span>}
        aside={`${weight.toFixed(1)} / ${definition.capacity.toFixed(1)} KG`}
      />
      <SegmentBar
        value={weight}
        max={definition.capacity}
        segments={isProtected ? 10 : 20}
        color={isProtected ? 'var(--abri)' : undefined}
        warnFrom={0.9}
      />
      {isProtected && <p className="muted container__hint">Conservé à la mort. Glisse ici ce que tu ne veux pas perdre.</p>}
      {toolbar}
      <DropZone
        className="tile-grid container__grid"
        style={{ gridTemplateColumns: `repeat(${layout.columns}, minmax(0, 1fr))` }}
        accepts={accepts}
        onDrop={() => onDrop(id)}
      >
        {visible.map((stack) => (
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
        {Array.from({ length: emptySlots }, (_, i) => (
          <EmptyTile key={`empty-${i}`} />
        ))}
      </DropZone>
    </Panel>
  );
}
