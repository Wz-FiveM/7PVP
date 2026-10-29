/**
 * Sons de l'ouverture de caisse, synthétisés avec Web Audio (aucun fichier) :
 *  - « tic » sec à chaque case qui passe sous le repère ;
 *  - accord de révélation, plus riche et plus aigu selon la rareté (1 = commun, 5 = légendaire).
 */
const VOLUME = 0.3;
/** La roulette lancée fait défiler plusieurs cases par image : un tic toutes les 35 ms au plus */
const MIN_TICK_INTERVAL = 35;

let context: AudioContext | null = null;
let master: GainNode | null = null;
let lastTick = 0;

function getContext(): AudioContext | null {
  try {
    if (!context) {
      context = new AudioContext();
      master = context.createGain();
      master.gain.value = VOLUME;
      master.connect(context.destination);
    }
    if (context.state === 'suspended') void context.resume();
    return context;
  } catch {
    return null;
  }
}

function tone(ctx: AudioContext, at: number, frequency: number, gain: number, duration: number, type: OscillatorType) {
  const oscillator = ctx.createOscillator();
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, at);
  const envelope = ctx.createGain();
  envelope.gain.setValueAtTime(0.0001, at);
  envelope.gain.exponentialRampToValueAtTime(gain, at + 0.004);
  envelope.gain.exponentialRampToValueAtTime(0.0001, at + duration);
  oscillator.connect(envelope).connect(master!);
  oscillator.start(at);
  oscillator.stop(at + duration + 0.02);
}

export function playCaseTick(): void {
  const now = performance.now();
  if (now - lastTick < MIN_TICK_INTERVAL) return;
  lastTick = now;
  const ctx = getContext();
  if (!ctx) return;
  tone(ctx, ctx.currentTime + 0.002, 2400, 0.35, 0.025, 'triangle');
}

/** Notes de l'accord (Hz) : on en joue plus, et plus haut, quand la rareté monte */
const REVEAL_NOTES = [523.25, 659.25, 783.99, 1046.5, 1318.5];

export function playCaseReveal(rarityOrder: number): void {
  const ctx = getContext();
  if (!ctx) return;
  const t = ctx.currentTime + 0.01;
  const notes = REVEAL_NOTES.slice(0, Math.max(2, Math.min(rarityOrder + 1, REVEAL_NOTES.length)));
  notes.forEach((frequency, i) => {
    tone(ctx, t + i * 0.07, frequency, 0.4, 0.5 + rarityOrder * 0.12, 'sine');
    tone(ctx, t + i * 0.07, frequency * 2, 0.08, 0.3, 'triangle');
  });
}
