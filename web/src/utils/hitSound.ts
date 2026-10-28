/**
 * Son du hitmarker, façon FPS moderne :
 *  - si un fichier existe dans web/public/sounds/ (hit_body, hit_armor, hit_head, hit_kill, en .ogg),
 *    il est utilisé tel quel : c'est là qu'on dépose ses propres sons ;
 *  - sinon, son synthétisé avec Web Audio : claquement sec et métallique (bruit filtré + « tic »),
 *    tintement brillant sur la tête, impact mat sur l'armure, coup sourd et grave sur un kill.
 */
export type HitSoundKind = 'body' | 'armor' | 'head' | 'kill';

const VOLUME = 0.4;
/** Plusieurs touches dans la même rafale : un son toutes les 45 ms au plus */
const MIN_INTERVAL = 45;
const KINDS: HitSoundKind[] = ['body', 'armor', 'head', 'kill'];

let context: AudioContext | null = null;
let master: GainNode | null = null;
let noise: AudioBuffer | null = null;
let lastPlayed = 0;
/** Sons déposés dans web/public/sounds/ (null : pas de fichier, on synthétise) */
const files: Partial<Record<HitSoundKind, AudioBuffer | null>> = {};

function getContext(): AudioContext | null {
  try {
    if (!context) {
      context = new AudioContext();
      // Compresseur : les sons superposés d'une rafale ne saturent pas
      const compressor = context.createDynamicsCompressor();
      compressor.threshold.value = -12;
      compressor.ratio.value = 6;
      master = context.createGain();
      master.gain.value = VOLUME;
      master.connect(compressor).connect(context.destination);
      loadFiles(context);
    }
    if (context.state === 'suspended') void context.resume();
    return context;
  } catch {
    return null;
  }
}

function loadFiles(ctx: AudioContext) {
  for (const kind of KINDS) {
    files[kind] = null;
    fetch(`./sounds/hit_${kind}.ogg`)
      .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject()))
      .then((data) => ctx.decodeAudioData(data))
      .then((buffer) => {
        files[kind] = buffer;
      })
      .catch(() => undefined);
  }
}

/** Bruit blanc (0,25 s), réutilisé par toutes les touches */
function getNoise(ctx: AudioContext): AudioBuffer {
  if (noise) return noise;
  noise = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.25), ctx.sampleRate);
  const channel = noise.getChannelData(0);
  for (let i = 0; i < channel.length; i++) channel[i] = Math.random() * 2 - 1;
  return noise;
}

/** Enveloppe percussive : attaque quasi instantanée, chute exponentielle. */
function envelope(ctx: AudioContext, at: number, gain: number, duration: number): GainNode {
  const node = ctx.createGain();
  node.gain.setValueAtTime(0.0001, at);
  node.gain.exponentialRampToValueAtTime(gain, at + 0.002);
  node.gain.exponentialRampToValueAtTime(0.0001, at + duration);
  node.connect(master!);
  return node;
}

/** Claquement : bruit filtré autour de `frequency` (le « crack » de l'impact). */
function crack(ctx: AudioContext, at: number, frequency: number, q: number, gain: number, duration: number) {
  const source = ctx.createBufferSource();
  source.buffer = getNoise(ctx);
  const filter = ctx.createBiquadFilter();
  filter.type = 'bandpass';
  filter.frequency.value = frequency;
  filter.Q.value = q;
  source.connect(filter).connect(envelope(ctx, at, gain, duration));
  source.start(at);
  source.stop(at + duration + 0.02);
}

/** Tintement : sinus qui glisse légèrement vers le bas (le « tic » métallique). */
function ping(ctx: AudioContext, at: number, frequency: number, gain: number, duration: number, type: OscillatorType = 'sine') {
  const oscillator = ctx.createOscillator();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, at);
  oscillator.frequency.exponentialRampToValueAtTime(frequency * 0.82, at + duration);
  oscillator.connect(envelope(ctx, at, gain, duration));
  oscillator.start(at);
  oscillator.stop(at + duration + 0.02);
}

/** Coup sourd : basse qui tombe vite (le poids d'un kill). */
function thump(ctx: AudioContext, at: number, gain: number) {
  const oscillator = ctx.createOscillator();
  oscillator.type = 'sine';
  oscillator.frequency.setValueAtTime(140, at);
  oscillator.frequency.exponentialRampToValueAtTime(48, at + 0.18);
  oscillator.connect(envelope(ctx, at, gain, 0.22));
  oscillator.start(at);
  oscillator.stop(at + 0.25);
}

function synthesize(ctx: AudioContext, kind: HitSoundKind, t: number) {
  switch (kind) {
    case 'head':
      // Plus brillant et plus long : claquement aigu + double tintement « verre »
      crack(ctx, t, 5200, 1.4, 0.9, 0.035);
      ping(ctx, t, 2900, 0.55, 0.11);
      ping(ctx, t, 5800, 0.25, 0.08);
      break;
    case 'armor':
      // Plaque touchée : impact plus mat, sans tintement
      crack(ctx, t, 2200, 1.2, 0.9, 0.04);
      ping(ctx, t, 1150, 0.35, 0.05, 'triangle');
      break;
    case 'kill':
      // Coup sourd + claquement + tintement bas qui sonne la fin
      thump(ctx, t, 1);
      crack(ctx, t, 3600, 1.1, 1, 0.05);
      ping(ctx, t + 0.012, 1700, 0.5, 0.16);
      ping(ctx, t + 0.012, 3400, 0.2, 0.1);
      break;
    default:
      // Corps : « tic » sec et métallique, très court
      crack(ctx, t, 3800, 1.3, 0.85, 0.03);
      ping(ctx, t, 1900, 0.4, 0.045);
  }
}

export function playHitSound(kind: HitSoundKind): void {
  const now = performance.now();
  if (kind !== 'kill' && now - lastPlayed < MIN_INTERVAL) return;
  lastPlayed = now;

  const ctx = getContext();
  if (!ctx || !master) return;
  const t = ctx.currentTime + 0.005;

  const file = files[kind];
  if (file) {
    const source = ctx.createBufferSource();
    source.buffer = file;
    source.connect(master);
    source.start(t);
    return;
  }
  synthesize(ctx, kind, t);
}
