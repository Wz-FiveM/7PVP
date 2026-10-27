import type { ReactNode } from 'react';
import type { ZoneType } from '../../types/game';

interface PanelProps {
  /** Bande d'alerte en haut, dans la couleur de la zone */
  stripes?: ZoneType;
  className?: string;
  children: ReactNode;
}

/** Panneau plein aux coins coupés. */
export function Panel({ stripes, className = '', children }: PanelProps) {
  return (
    <section className={`panel cut ${stripes ? `zone-${stripes}` : ''} ${className}`}>
      {stripes && <div className="stripes" />}
      <div className="panel__body">{children}</div>
    </section>
  );
}

interface PanelHeaderProps {
  title: string;
  icon?: ReactNode;
  badge?: ReactNode;
  aside?: ReactNode;
}

export function PanelHeader({ title, icon, badge, aside }: PanelHeaderProps) {
  return (
    <header className="panel__header">
      {icon}
      <h2 className="disp panel__title">{title}</h2>
      {badge}
      {aside && <span className="mono panel__aside">{aside}</span>}
    </header>
  );
}
