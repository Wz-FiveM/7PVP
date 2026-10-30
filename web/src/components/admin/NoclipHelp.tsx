import { formatNumber, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { NoclipKeyId } from '../../types/admin';
import './noclipHelp.css';

/** Touches du pavé de déplacement, ligne par ligne (null = case vide) */
const MOVE_GRID: (NoclipKeyId | null)[] = [null, 'forward', null, 'left', 'back', 'right'];

const multiplier = (value: number) => `×${formatNumber(value)}`;

/** Touche du clavier, allumée quand elle est maintenue. */
function Key({ label, held, wide }: { label: string; held?: boolean; wide?: boolean }) {
  const classes = ['noclip-key', 'cut-s', 'mono'];
  if (held) classes.push('noclip-key--held');
  if (wide) classes.push('noclip-key--wide');
  return <span className={classes.join(' ')}>{label}</span>;
}

/** Aide des touches affichée pendant le noclip admin, à droite de l'écran. */
export function NoclipHelp() {
  const t = useT();
  const { state } = useGame();
  const { keys, held, toggleKey, speed, fastMultiplier, slowMultiplier } = state.noclip;
  if (!keys) return null;

  const isHeld = (id: NoclipKeyId) => held.includes(id);
  // Même priorité que le Lua : Maj l'emporte sur Alt
  const pace = isHeld('fast') ? 'fast' : isHeld('slow') ? 'slow' : 'normal';
  const currentSpeed = speed * (pace === 'fast' ? fastMultiplier : pace === 'slow' ? slowMultiplier : 1);
  const paceLabel = { fast: t('Rapide'), slow: t('Lent'), normal: t('Normal') }[pace];

  const rows: { id?: NoclipKeyId; key: string; action: string }[] = [
    { id: 'up', key: keys.up, action: t('Monter') },
    { id: 'down', key: keys.down, action: t('Descendre') },
    { id: 'fast', key: keys.fast, action: t('Rapide {multiplier}', { multiplier: multiplier(fastMultiplier) }) },
    { id: 'slow', key: keys.slow, action: t('Lent {multiplier}', { multiplier: multiplier(slowMultiplier) }) },
    { key: t('Souris'), action: t('Orienter') },
    { key: toggleKey, action: t('Quitter le noclip') },
  ];

  return (
    <aside className="noclip-help">
      <div className="stripes" />
      <div className="noclip-help__body">
        <header className="noclip-help__head">
          <span className="disp noclip-help__title">Noclip</span>
          <span className={`mono noclip-help__speed noclip-help__speed--${pace}`}>
            {Math.round(currentSpeed)} m/s · {paceLabel}
          </span>
        </header>

        <div className="noclip-help__move">
          <div className="noclip-help__grid">
            {MOVE_GRID.map((id, index) =>
              id ? <Key key={id} label={keys[id]} held={isHeld(id)} /> : <span key={index} />,
            )}
          </div>
          <span className="label noclip-help__hint">{t('Avancer vers la caméra')}</span>
        </div>

        <ul className="noclip-help__rows">
          {rows.map((row) => (
            <li key={row.action} className="noclip-help__row">
              <Key label={row.key} held={row.id ? isHeld(row.id) : false} wide />
              <span className="noclip-help__action">{row.action}</span>
            </li>
          ))}
        </ul>
      </div>
    </aside>
  );
}
