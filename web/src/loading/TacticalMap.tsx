import { useEffect, useRef } from 'react';
import { drawTerrain, MAP_HEIGHT, MAP_WIDTH } from './terrain';

/** Le trajet d'insertion, un tronçon par drapeau : le chargement fait avancer le joueur et capturer les drapeaux. */
const ROUTE = [
  'M675 625 C 750 610, 835 575, 900 500',
  'M900 500 C 955 430, 1030 310, 1120 255',
  'M1120 255 C 1215 205, 1335 300, 1385 420',
];
const FLAGS = [
  { letter: 'A', x: 900, y: 500 },
  { letter: 'B', x: 1120, y: 255 },
  { letter: 'C', x: 1385, y: 420 },
];
/** Ennemis révélés au passage du balayage */
const BLIPS = [
  { x: 1015, y: 165 },
  { x: 1060, y: 425 },
  { x: 1245, y: 505 },
  { x: 1310, y: 135 },
  { x: 1480, y: 250 },
  { x: 1505, y: 545 },
];
const SWEEP_SECONDS = 14;

const clamp01 = (value: number): number => Math.min(Math.max(value, 0), 1);

const percentX = (x: number): string => `${(x / MAP_WIDTH) * 100}%`;
const percentY = (y: number): string => `${(y / MAP_HEIGHT) * 100}%`;

export function TacticalMap({ fraction }: { fraction: number }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const segments = useRef<(SVGPathElement | null)[]>([]);
  const player = useRef<SVGGElement>(null);

  const legProgress = (leg: number) => clamp01(fraction * ROUTE.length - leg);
  const activeLeg = Math.min(Math.floor(fraction * ROUTE.length), ROUTE.length - 1);

  useEffect(() => {
    if (canvas.current) drawTerrain(canvas.current);
  }, []);

  // Le marqueur du joueur suit le trajet et regarde dans le sens de la marche
  useEffect(() => {
    const path = segments.current[activeLeg];
    if (!path || !player.current) return;
    const length = path.getTotalLength();
    const distance = length * legProgress(activeLeg);
    const at = path.getPointAtLength(distance);
    const behind = path.getPointAtLength(Math.max(distance - 2, 0));
    const ahead = path.getPointAtLength(Math.min(distance + 2, length));
    const angle = (Math.atan2(ahead.y - behind.y, ahead.x - behind.x) * 180) / Math.PI;
    player.current.setAttribute('transform', `translate(${at.x} ${at.y}) rotate(${angle})`);
  });

  return (
    <div className="loading__stage" aria-hidden="true">
      <canvas ref={canvas} className="loading__terrain" />

      <svg className="loading__route" viewBox={`0 0 ${MAP_WIDTH} ${MAP_HEIGHT}`}>
        {ROUTE.map((path, leg) => (
          <g key={path}>
            <path className="loading__route-todo" d={path} />
            <path
              ref={(element) => { segments.current[leg] = element; }}
              className="loading__route-done"
              d={path}
              pathLength={1}
              strokeDashoffset={1 - legProgress(leg)}
            />
          </g>
        ))}
        <g ref={player}>
          <path className="loading__player" d="M11 0 L-8 -8 L-4 0 L-8 8 Z" />
        </g>
      </svg>

      {BLIPS.map((blip) => (
        <span
          key={`${blip.x}-${blip.y}`}
          className="loading__blip"
          style={{
            left: percentX(blip.x),
            top: percentY(blip.y),
            animationDelay: `${(blip.x / MAP_WIDTH) * SWEEP_SECONDS}s`,
          }}
        />
      ))}

      {FLAGS.map((flag, leg) => {
        const captured = legProgress(leg) >= 1;
        const state = captured ? 'captured' : leg === activeLeg ? 'active' : 'idle';
        return (
          <div
            key={flag.letter}
            className={`loading__flag loading__flag--${state}`}
            style={{ left: percentX(flag.x), top: percentY(flag.y) }}
          >
            <svg viewBox="0 0 48 48">
              <circle className="loading__flag-base" cx="24" cy="24" r="20" />
              <circle
                className="loading__flag-ring"
                cx="24"
                cy="24"
                r="20"
                pathLength={1}
                strokeDashoffset={1 - legProgress(leg)}
              />
            </svg>
            <span>{flag.letter}</span>
          </div>
        );
      })}

      <span className="loading__sweep" style={{ animationDuration: `${SWEEP_SECONDS}s` }} />
    </div>
  );
}
