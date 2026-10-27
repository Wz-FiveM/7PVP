import type { ReactNode } from 'react';

interface SectionTitleProps {
  title: string;
  aside?: ReactNode;
}

export function SectionTitle({ title, aside }: SectionTitleProps) {
  return (
    <div className="section-title">
      <span className="label">{title}</span>
      {aside && <span className="mono section-title__aside">{aside}</span>}
    </div>
  );
}
