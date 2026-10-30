/**
 * Son de minigun des unités du mode Call of Duty (tourelle, hélicoptères, Harrier, hélico mitrailleur, 25 mm de l'AC-130) :
 * web/public/sounds/minigun.mp3. Les balles de ces unités n'ont pas de tireur et le jeu ne leur donne pas toujours de son.
 * Chaque unité qui tire fait tourner sa boucle : chaque tir la prolonge, elle s'arrête quand les tirs cessent.
 */
const FILE = './sounds/minigun.mp3';
const VOLUME = 0.6;
// La partie où le tir est régulier, choisie pour que le raccord ne s'entende pas (s)
const LOOP_START = 0.0603;
const LOOP_END = 2.8948;
/** Sans nouveau tir pendant ce temps, l'unité a cessé de tirer (ms) */
const RELEASE = 320;
const VOLUME_SMOOTHING = 0.03; // s
const FADE_OUT = 0.04; // s
const MUFFLED = 900; // Hz : coupure du son au loin
const CLEAR = 16000; // Hz : coupure du son tout près

interface Gun {
  source: AudioBufferSourceNode;
  filter: BiquadFilterNode;
  gain: GainNode;
  timer: number;
}

let context: AudioContext | null = null;
let master: GainNode | null = null;
let buffer: AudioBuffer | null = null;
const guns = new Map<number, Gun>();

function getContext(): AudioContext | null {
  try {
    if (!context) {
      context = new AudioContext();
      // Compresseur : plusieurs unités en même temps ne saturent pas
      const compressor = context.createDynamicsCompressor();
      compressor.threshold.value = -14;
      compressor.ratio.value = 6;
      master = context.createGain();
      master.gain.value = VOLUME;
      master.connect(compressor).connect(context.destination);
      fetch(FILE)
        .then((response) => (response.ok ? response.arrayBuffer() : Promise.reject()))
        .then((data) => context!.decodeAudioData(data))
        .then((decoded) => {
          buffer = decoded;
        })
        .catch(() => undefined);
    }
    if (context.state === 'suspended') void context.resume();
    return context;
  } catch {
    return null;
  }
}

function startGun(ctx: AudioContext, sound: AudioBuffer): Gun {
  const source = ctx.createBufferSource();
  source.buffer = sound;
  source.loop = true;
  source.loopStart = LOOP_START;
  source.loopEnd = LOOP_END;
  const filter = ctx.createBiquadFilter();
  filter.type = 'lowpass';
  const gain = ctx.createGain();
  gain.gain.value = 0;
  source.connect(filter).connect(gain).connect(master!);
  source.start(ctx.currentTime, LOOP_START);
  return { source, filter, gain, timer: 0 };
}

function stopGun(id: number) {
  const gun = guns.get(id);
  if (!gun || !context) return;
  guns.delete(id);
  window.clearTimeout(gun.timer);
  gun.gain.gain.setTargetAtTime(0, context.currentTime, FADE_OUT / 3);
  gun.source.stop(context.currentTime + FADE_OUT);
}

/**
 * @param id unité qui tire
 * @param volume de 0 (au loin) à 1 (tout près)
 */
export function playGunfire(id: number, volume: number): void {
  const ctx = getContext();
  if (!ctx || !buffer) return;
  let gun = guns.get(id);
  if (!gun) {
    gun = startGun(ctx, buffer);
    guns.set(id, gun);
  }
  const level = Math.max(0, Math.min(volume, 1));
  gun.gain.gain.setTargetAtTime(level, ctx.currentTime, VOLUME_SMOOTHING);
  gun.filter.frequency.setTargetAtTime(MUFFLED + (CLEAR - MUFFLED) * level, ctx.currentTime, VOLUME_SMOOTHING);
  window.clearTimeout(gun.timer);
  gun.timer = window.setTimeout(() => stopGun(id), RELEASE);
}

/** Fin de la partie : plus aucune unité ne tire. */
export function stopGunfire(): void {
  for (const id of [...guns.keys()]) stopGun(id);
}
