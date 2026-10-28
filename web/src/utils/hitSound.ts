/**
 * Son du hitmarker, synthétisé avec Web Audio (aucun fichier audio) :
 * « tic » sec sur le corps, plus aigu sur la tête, double coup grave sur un coup mortel.
 */
export type HitSoundKind = 'body' | 'armor' | 'head' | 'kill';

const VOLUME = 0.35;
/** Plusieurs touches dans la même rafale : un son toutes les 45 ms au plus */
const MIN_INTERVAL = 45;

let context: AudioContext | null = null;
let lastPlayed = 0;

function getContext(): AudioContext | null {
  try {
    context = context ?? new AudioContext();
    if (context.state === 'suspended') void context.resume();
    return context;
  } catch {
    return null;
  }
}

/** Un « clic » court : fréquence de départ, chute rapide du volume. */
function click(ctx: AudioContext, at: number, frequency: number, duration: number, gain: number, type: OscillatorType) {
  const oscillator = ctx.createOscillator();
  const envelope = ctx.createGain();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, at);
  oscillator.frequency.exponentialRampToValueAtTime(frequency * 0.55, at + duration);
  envelope.gain.setValueAtTime(gain * VOLUME, at);
  envelope.gain.exponentialRampToValueAtTime(0.0001, at + duration);
  oscillator.connect(envelope).connect(ctx.destination);
  oscillator.start(at);
  oscillator.stop(at + duration + 0.02);
}

export function playHitSound(kind: HitSoundKind): void {
  const now = performance.now();
  if (kind !== 'kill' && now - lastPlayed < MIN_INTERVAL) return;
  lastPlayed = now;

  const ctx = getContext();
  if (!ctx) return;
  const t = ctx.currentTime;

  switch (kind) {
    case 'head':
      click(ctx, t, 2600, 0.06, 0.9, 'triangle');
      click(ctx, t, 5200, 0.04, 0.35, 'sine');
      break;
    case 'kill':
      click(ctx, t, 900, 0.09, 1, 'triangle');
      click(ctx, t + 0.07, 600, 0.14, 0.9, 'triangle');
      break;
    case 'armor':
      click(ctx, t, 1400, 0.05, 0.7, 'square');
      break;
    default:
      click(ctx, t, 1900, 0.05, 0.8, 'triangle');
  }
}
