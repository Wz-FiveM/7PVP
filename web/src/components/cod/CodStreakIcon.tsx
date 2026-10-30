import type { ReactNode } from 'react';

const UAV = <path d="M11 2h2l.6 7.5L23 11v2l-9.5.5-.5 5 3 1.5v2l-4-.8-4 .8v-2l3-1.5-.5-5L1 13v-2l9.4-1.5z" />;
const PARACHUTE = <path d="M3 10a9 9 0 0 1 18 0h-4.2l-3.2 4h1.9v-.2h-7v.2h1.9l-3.2-4zM7 15h10v7H7z" />;
const HELICOPTER = (
  <path d="M2 4h20v1.6h-9.2V8H14c3.6 0 6 2.3 6 5s-2 4.6-4.6 4.8v1.6H20V21H6v-1.6h2.8v-1.8L6.6 13H2.5L1 9.6h1.6L4 11.4h3.2L9 8h2.2V5.6H2z" />
);

function Crosshair({ cx = 12, cy = 12, r = 7 }: { cx?: number; cy?: number; r?: number }) {
  return (
    <g fill="none" stroke="currentColor" strokeWidth="1.8">
      <circle cx={cx} cy={cy} r={r} />
      <path d={`M${cx} ${cy - r - 3}v5M${cx} ${cy + r + 3}v-5M${cx - r - 3} ${cy}h5M${cx + r + 3} ${cy}h-5`} />
    </g>
  );
}

const ICONS: Record<string, ReactNode> = {
  uav: UAV,
  counter_uav: (
    <>
      {UAV}
      <path d="M3 3l18 18" fill="none" stroke="currentColor" strokeWidth="2.4" />
    </>
  ),
  care_package: PARACHUTE,
  airdrop: (
    <>
      <g transform="translate(-1 -1) scale(0.58)">{PARACHUTE}</g>
      <g transform="translate(11 10) scale(0.58)">{PARACHUTE}</g>
    </>
  ),
  sentry: (
    <>
      <path d="M4 6h12v2h7v2.4h-7V12H4z" />
      <path d="M10 12v4M10 16l-6 6M10 16l6 6" fill="none" stroke="currentColor" strokeWidth="2" />
    </>
  ),
  predator: <path d="M10 5.6V2L6.5 1v6l3.5 2v8l2 6 2-6V9l3.5-2V1L14 2v3.6z" />,
  precision: (
    <>
      <Crosshair />
      <circle cx="12" cy="12" r="2.4" />
    </>
  ),
  harrier: <path d="M12 1l1.8 7.5L22 15v2.4l-8.2-3-.5 4.4 3 2.2V23L12 21.6 7.7 23v-2l3-2.2-.5-4.4L2 17.4V15l8.2-6.5z" />,
  helicopter: HELICOPTER,
  pave_low: (
    <>
      {HELICOPTER}
      <path d="M1 1.5h22v1.2H1z" />
    </>
  ),
  chopper_gunner: (
    <>
      <g transform="translate(0 -2) scale(0.78)">{HELICOPTER}</g>
      <Crosshair cx={18} cy={18} r={3} />
    </>
  ),
  juggernaut: (
    <path
      fillRule="evenodd"
      d="M12 2c5 0 8.4 3.4 8.4 8.2V16L16 22H8l-4.4-6v-5.8C3.6 5.4 7 2 12 2zM6.8 10.2v3h10.4v-3zM11 16v4h2v-4z"
    />
  ),
  stealth: <path d="M12 5l11 11.5-3.6 1.2-2.2-2.2-2.6 2.5-2.6-1.8-2.6 1.8-2.6-2.5-2.2 2.2L1 16.5z" />,
  ac130: <path d="M11 1h2l1 5v3.5l9 1.5v2.4l-9-.6v6l3 1.5V23H7v-2.7l3-1.5v-6l-9 .6V11l9-1.5V6zM4.5 7h1.8v3.5H4.5zM7.8 6.5h1.8V10H7.8zM14.4 6.5h1.8V10h-1.8zM17.7 7h1.8v3.5h-1.8z" />,
  emp: <path d="M14 1L4 14h6.5L9 23l11-14h-7z" />,
  nuke: (
    <>
      <circle cx="12" cy="12" r="2.2" />
      {[0, 120, 240].map((angle) => (
        <path key={angle} transform={`rotate(${angle} 12 12)`} d="M6.5 2.47A11 11 0 0 1 17.5 2.47L13.75 8.97A3.5 3.5 0 0 0 10.25 8.97Z" />
      ))}
    </>
  ),
};

/** Pictogramme d'une série d'éliminations, teinté par la couleur du texte. */
export function CodStreakIcon({ id }: { id: string }) {
  return (
    <svg className="cod-streak__icon" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
      {ICONS[id] ?? <path d="M12 2l10 10-10 10L2 12z" />}
    </svg>
  );
}
