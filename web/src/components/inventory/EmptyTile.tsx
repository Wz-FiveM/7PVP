interface EmptyTileProps {
  /** Texte en bas à droite (ex : numéro de touche) */
  corner?: string;
}

/** Emplacement vide. */
export function EmptyTile({ corner }: EmptyTileProps) {
  return (
    <div className="tile-wrap">
      <div className="tile tile--empty cut">
        {corner && <span className="tile__corner mono">{corner}</span>}
      </div>
    </div>
  );
}
