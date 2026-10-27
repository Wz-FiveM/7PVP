import type { ReactNode } from 'react';

interface SectionTitleProps {
  title: string;
  icon?: ReactNode;
  badge?: ReactNode;
  aside?: ReactNode;
}

export function SectionTitle({ title, icon, badge, aside }: SectionTitleProps) {
  return (
    <div className="section-title">
      {icon}
      <span className="section-title__text">{title}</span>
      {badge}
      {aside && <span className="mono section-title__aside">{aside}</span>}
    </div>
  );
}
