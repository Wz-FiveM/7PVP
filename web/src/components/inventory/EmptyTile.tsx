interface EmptyTileProps {
  keyLabel?: string;
  compact?: boolean;
}

/** Emplacement vide, hachuré. */
export function EmptyTile({ keyLabel, compact }: EmptyTileProps) {
  return (
    <div className="tile-wrap">
      <div className={compact ? 'tile tile--compact tile--empty cut hatched' : 'tile tile--empty cut hatched'}>
        {keyLabel && <span className="tile__key tile__key--off">{keyLabel}</span>}
      </div>
    </div>
  );
}
