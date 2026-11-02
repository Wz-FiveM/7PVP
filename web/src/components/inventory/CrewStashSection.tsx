import type { MouseEvent } from 'react';
import { formatNumber, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CrewData, ItemStack } from '../../types/game';
import { itemLabel, stacksOf, weightOf } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';
import { SegmentBar } from '../ui/SegmentBar';
import { useDrag } from './DragProvider';
import { DropZone } from './DropZone';
import { ItemTile } from './ItemTile';

interface CrewStashSectionProps {
  crew: CrewData;
  selected: string | null;
  onSelect: (name: string) => void;
  /** Alt + clic ou double-clic : prend toute la pile (ce qui tient) dans le sac */
  onQuickTake: (stack: ItemStack) => void;
  onItemContextMenu: (event: MouseEvent, stack: ItemStack) => void;
}

/** Date courte du journal : « 02/11 18:42 ». */
function formatLogDate(at: number): string {
  const date = new Date(at * 1000);
  const pad = (value: number) => String(value).padStart(2, '0');
  return `${pad(date.getDate())}/${pad(date.getMonth() + 1)} ${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

/** Coffre commun du crew, chez le banquier : contenu et journal de qui a déposé ou retiré quoi. */
export function CrewStashSection({ crew, selected, onSelect, onQuickTake, onItemContextMenu }: CrewStashSectionProps) {
  const t = useT();
  const { state } = useGame();
  const { drag, begin } = useDrag();
  const { config } = state;
  const stacks = stacksOf(crew.stash, config);
  const capacity = config.crew?.stashCapacity ?? 0;
  const weight = weightOf(crew.stash, config);
  const log = Array.isArray(crew.stashLog) ? crew.stashLog : [];

  return (
    <section className="container container--stash">
      <SectionTitle
        title={t('Coffre du crew')}
        icon={<Icon name="lock" size={15} strokeWidth={2.4} className="stash-icon" />}
        badge={<span className="muted container__note">{t('Commun aux membres')}</span>}
        aside={`${weight.toFixed(1)}KG / ${capacity.toFixed(0)}KG`}
      />
      <SegmentBar value={weight} max={capacity} segments={50} color="var(--toxine)" warnFrom={0.9} height={3} />
      <DropZone target={{ kind: 'crew' }} className="tile-grid container__grid">
        {stacks.map((stack) => (
          <ItemTile
            key={stack.name}
            name={stack.name}
            item={stack.item}
            corner={stack.item.type === 'money' ? formatNumber(stack.count) : `x${stack.count}`}
            selected={selected === stack.name}
            dragging={drag?.source.kind === 'crew' && drag.source.item === stack.name}
            onClick={(event) => (event.altKey ? onQuickTake(stack) : onSelect(stack.name))}
            onDragBegin={(event) => begin({ kind: 'crew', item: stack.name, count: stack.count }, event)}
            onDoubleClick={() => onQuickTake(stack)}
            onContextMenu={(event) => onItemContextMenu(event, stack)}
          />
        ))}
      </DropZone>

      <div className="crew-stash-log">
        <span className="label">{t('Journal du coffre')}</span>
        {log.length === 0 && <p className="muted crew-stash-log__empty">{t('Aucune opération pour l\'instant.')}</p>}
        <ul className="crew-stash-log__list">
          {log.map((entry, index) => (
            <li key={`${entry.at}-${index}`} className="crew-stash-log__row">
              <span className="mono crew-stash-log__date">{formatLogDate(entry.at)}</span>
              <span className="crew-stash-log__text">
                {t(entry.taken ? '{name} retire {count} x {item}' : '{name} dépose {count} x {item}', {
                  name: t(entry.name),
                  count: formatNumber(entry.count),
                  item: itemLabel(config, entry.item),
                })}
              </span>
            </li>
          ))}
        </ul>
      </div>
    </section>
  );
}
