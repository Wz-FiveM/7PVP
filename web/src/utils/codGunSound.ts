/**
 * Tirs des unités automatiques du mode Call of Duty (tourelle, hélicoptères, Harrier), synthétisés avec Web Audio :
 * les balles de ces unités n'ont pas de tireur et le jeu ne leur donne pas toujours de son.
 * Un tir du serveur est une courte salve : le son d'une arme à canons rotatifs.
 */
const VOLUME = 0.5;
const SHOTS = 3;
const SHOT_SPACING = 0.05; // s
const SHOT_LENGTH = 0.09; // s
const MUFFLED = 700; // Hz : coupure du son au loin
const CLEAR = 6000; // Hz : coupure du son tout près

let context: AudioContext | null = null;
let master: GainNode | null = null;
let noise: AudioBuffer | null = null;

function getContext(): AudioContext | null {
  try {
    if (!context) {
      context = new AudioContext();
      // Compresseur : les salves superposées ne saturent pas
      const compressor = context.createDynamicsCompressor();
      compressor.threshold.value = -14;
      compressor.ratio.value = 6;
      master = context.createGain();
      master.gain.value = VOLUME;
      master.connect(compressor).connect(context.destination);
    }
    if (context.state === 'suspended') void context.resume();
    return context;
  } catch {
    return null;
  }
}

function getNoise(ctx: AudioContext): AudioBuffer {
  if (noise) return noise;
  noise = ctx.createBuffer(1, Math.floor(ctx.sampleRate * 0.2), ctx.sampleRate);
  const channel = noise.getChannelData(0);
  for (let i = 0; i < channel.length; i++) channel[i] = Math.random() * 2 - 1;
  return noise;
}

function shot(ctx: AudioContext, at: number, volume: number) {
  const envelope = ctx.createGain();
  envelope.gain.setValueAtTime(0.0001, at);
  envelope.gain.exponentialRampToValueAtTime(volume, at + 0.002);
  envelope.gain.exponentialRampToValueAtTime(0.0001, at + SHOT_LENGTH);
  envelope.connect(master!);

  const source = ctx.createBufferSource();
  source.buffer = getNoise(ctx);
  const filter = ctx.createBiquadFilter();
  filter.type = 'lowpass';
  filter.frequency.value = MUFFLED + (CLEAR - MUFFLED) * volume;
  source.connect(filter).connect(envelope);
  source.start(at);
  source.stop(at + SHOT_LENGTH + 0.02);

  // Le coup sourd sous le claquement
  const low = ctx.createOscillator();
  low.type = 'triangle';
  low.frequency.setValueAtTime(170, at);
  low.frequency.exponentialRampToValueAtTime(60, at + SHOT_LENGTH);
  low.connect(envelope);
  low.start(at);
  low.stop(at + SHOT_LENGTH + 0.02);
}

/** @param volume de 0 (au loin) à 1 (tout près) */
export function playGunfire(volume: number): void {
  const ctx = getContext();
  if (!ctx || volume <= 0) return;
  for (let index = 0; index < SHOTS; index++) shot(ctx, ctx.currentTime + index * SHOT_SPACING, Math.min(volume, 1));
}
