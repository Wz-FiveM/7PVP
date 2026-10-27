import type { ItemType } from '../../types/game';

export type BagFilter = ItemType | 'all';

const FILTERS: { id: BagFilter; label: string }[] = [
  { id: 'all', label: 'Tout' },
  { id: 'weapon', label: 'Armes' },
  { id: 'ammo', label: 'Munitions' },
  { id: 'consumable', label: 'Soins' },
  { id: 'money', label: 'Argent' },
];

interface BagFiltersProps {
  value: BagFilter;
  onChange: (filter: BagFilter) => void;
}

export function BagFilters({ value, onChange }: BagFiltersProps) {
  return (
    <div className="bag-filters">
      {FILTERS.map((filter) => (
        <button
          key={filter.id}
          className={filter.id === value ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
          onClick={() => onChange(filter.id)}
        >
          {filter.label}
        </button>
      ))}
    </div>
  );
}
