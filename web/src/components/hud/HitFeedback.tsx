import { useCallback, useRef, useState, type CSSProperties } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { HitEvent } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { playHitSound } from '../../utils/hitSound';
import './hitFeedback.css';

/** armor : seule l'armure a encaissé ; head : tir à la tête ; kill : coup mortel */
type HitKind = 'armor' | 'body' | 'head' | 'kill';

const MARKER_DURATION = 300;
const NUMBER_DURATION = 900;
/** Coups rapprochés (rafale, pompe) : un seul nombre qui s'additionne */
const MERGE_WINDOW = 350;
const MAX_NUMBERS = 6;
const KIND_PRIORITY: HitKind[] = ['armor', 'body', 'head', 'kill'];

interface DamageNumber {
  id: number;
  value: number;
  kind: HitKind;
  at: number;
  /** colonne (0, 1, 2) pour que les nombres successifs ne se recouvrent pas */
  offset: number;
}

function hitKind(hit: HitEvent): HitKind {
  if (hit.fatal) return 'kill';
  if (hit.headshot) return 'head';
  if (hit.armor >= hit.damage) return 'armor';
  return 'body';
}

function strongest(a: HitKind, b: HitKind): HitKind {
  return KIND_PRIORITY.indexOf(a) >= KIND_PRIORITY.indexOf(b) ? a : b;
}

/** Hitmarker au centre de l'écran et dégâts infligés à côté, quand on touche un joueur. */
export function HitFeedback() {
  const [marker, setMarker] = useState<{ id: number; kind: HitKind } | null>(null);
  const [numbers, setNumbers] = useState<DamageNumber[]>([]);
  const nextId = useRef(0);

  const onHit = useCallback((hit: HitEvent) => {
    const id = ++nextId.current;
    const kind = hitKind(hit);
    const now = Date.now();

    setMarker({ id, kind });
    playHitSound(kind);
    window.setTimeout(() => setMarker((current) => (current?.id === id ? null : current)), MARKER_DURATION);

    setNumbers((list) => {
      const last = list[list.length - 1];
      if (last && last.kind !== 'kill' && now - last.at < MERGE_WINDOW) {
        // Nouvel id : l'animation du nombre repart, il « gonfle » à chaque coup
        const merged = { ...last, id, value: last.value + hit.damage, kind: strongest(last.kind, kind), at: now };
        return [...list.slice(0, -1), merged];
      }
      return [...list, { id, value: hit.damage, kind, at: now, offset: list.length % 3 }].slice(-MAX_NUMBERS);
    });
    window.setTimeout(() => setNumbers((list) => list.filter((n) => n.id !== id)), NUMBER_DURATION);
  }, []);

  const handleMessage = useCallback(
    (message: NuiMessage) => {
      if (message.action === 'hit') onHit(message.data);
    },
    [onHit],
  );
  useNuiMessage(handleMessage);

  return (
    <div className="hit-feedback">
      {marker && (
        <span key={marker.id} className={`hitmarker hit--${marker.kind}`}>
          <i />
          <i />
          <i />
          <i />
        </span>
      )}
      <div className="hit-numbers">
        {numbers.map((n) => (
          <span
            key={n.id}
            className={`mono hit-number hit--${n.kind}`}
            style={{ '--offset': n.offset } as CSSProperties}
          >
            {n.value}
          </span>
        ))}
      </div>
    </div>
  );
}
