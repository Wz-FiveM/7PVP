import { useEffect, useState } from 'react';
import { numberLocale, useT } from '../i18n';

const TYPE_INTERVAL = 32;

/** Date et heure du PC du joueur, jamais de décalage de largeur (chiffres à deux positions) */
const stamp = (date: Date): string => {
  const day = date.toLocaleDateString(numberLocale(), { day: '2-digit', month: '2-digit', year: 'numeric' });
  const time = date.toLocaleTimeString(numberLocale(), { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
  return `${day} — ${time}`;
};

/** Le texte tapé à la machine des débuts de mission : la date, le lieu, le joueur. */
export function Briefing({ name }: { name?: string }) {
  const t = useT();
  const [now, setNow] = useState(() => new Date());
  const [typed, setTyped] = useState(0);

  const lines = [
    stamp(now),
    'LOS SANTOS, SAN ANDREAS',
    '34.0522 N / 118.2437 W',
    ...(name ? [`${t('Opérateur').toUpperCase()} ${name.toUpperCase()}`] : []),
  ];
  const total = lines.reduce((sum, line) => sum + line.length, 0);
  const done = typed >= total;

  useEffect(() => {
    const timer = window.setInterval(() => setNow(new Date()), 1000);
    return () => window.clearInterval(timer);
  }, []);

  useEffect(() => {
    if (done) return undefined;
    const timer = window.setInterval(() => setTyped((count) => count + 1), TYPE_INTERVAL);
    return () => window.clearInterval(timer);
  }, [done]);

  let remaining = typed;
  return (
    <div className="loading__briefing">
      {lines.map((line, index) => {
        const shown = line.slice(0, Math.max(remaining, 0));
        const typing = remaining >= 0 && remaining < line.length;
        remaining -= line.length;
        const last = index === lines.length - 1;
        return (
          <p key={index}>
            {shown}
            {(typing || (done && last)) && <i className="loading__caret" />}
          </p>
        );
      })}
    </div>
  );
}
