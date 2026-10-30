import { useCallback, useEffect, useLayoutEffect, useRef, useState, type CSSProperties } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CaseReelEntry, CaseSpin } from '../../types/game';
import { playCaseReveal, playCaseTick } from '../../utils/caseSound';
import { rarityOf } from '../../utils/cases';
import { entriesOf, itemLabel } from '../../utils/inventory';
import { formatMoney } from '../../utils/format';
import { ItemIcon } from '../inventory/ItemIcon';
import './cases.css';

/** Courbe de la roulette : départ rapide, longue décélération */
const EASING = 'cubic-bezier(0.08, 0.6, 0.12, 1)';

/** Quantité affichée sous une case : « $500 », « x48 », rien pour 1 */
function countLabel(entry: CaseReelEntry): string {
  if (entry.item === 'money') return formatMoney(entry.count);
  return entry.count > 1 ? `x${entry.count}` : '';
}

/**
 * Roulette d'ouverture de caisse, par-dessus le menu. Le serveur a déjà tiré et donné la
 * récompense : on anime seulement jusqu'à la case `winner`. Échap passe l'animation, puis ferme.
 */
export function CaseOpening({ spin }: { spin: CaseSpin }) {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player } = state;
  const [done, setDone] = useState(false);
  const viewportRef = useRef<HTMLDivElement>(null);
  const stripRef = useRef<HTMLDivElement>(null);
  const targetRef = useRef(0);
  const doneRef = useRef(false);

  const definition = config.cases?.find((c) => c.id === spin.caseId);
  const winner = spin.reel[spin.winner - 1];
  const winnerRarity = rarityOf(config, winner?.rarity ?? '');
  const winnerItem = winner ? config.items[winner.item] : undefined;
  const owned = player
    ? [...entriesOf(player.inventory.bag), ...entriesOf(player.inventory.protected)]
      .filter(([name]) => name === spin.caseId)
      .reduce((total, [, count]) => total + count, 0)
    : 0;

  // Lu à la fin de l'animation : `finish` reste stable et ne relance pas la roulette
  const revealOrderRef = useRef(winnerRarity.order);
  revealOrderRef.current = winnerRarity.order;

  const finish = useCallback(() => {
    if (doneRef.current) return;
    doneRef.current = true;
    setDone(true);
    playCaseReveal(revealOrderRef.current);
  }, []);

  const skip = useCallback(() => {
    const strip = stripRef.current;
    if (strip) {
      strip.style.transition = 'none';
      strip.style.transform = `translateX(${-targetRef.current}px)`;
    }
    finish();
  }, [finish]);

  // Lancement : la case gagnante s'arrête sous le repère, un peu décalée au hasard
  useLayoutEffect(() => {
    doneRef.current = false;
    setDone(false);
    const viewport = viewportRef.current;
    const strip = stripRef.current;
    const tiles = strip?.children;
    if (!viewport || !strip || !tiles || tiles.length < 2) return;

    const first = tiles[0] as HTMLElement;
    const step = (tiles[1] as HTMLElement).offsetLeft - first.offsetLeft;
    const tileWidth = first.offsetWidth;
    const jitter = (Math.random() - 0.5) * tileWidth * 0.8;
    const target = (spin.winner - 1) * step + tileWidth / 2 + jitter - viewport.clientWidth / 2;
    targetRef.current = target;

    strip.style.transition = 'none';
    strip.style.transform = 'translateX(0px)';
    void strip.offsetWidth; // applique la position de départ avant de lancer la transition
    strip.style.transition = `transform ${spin.duration}s ${EASING}`;
    strip.style.transform = `translateX(${-target}px)`;

    // Un « tic » à chaque case qui passe sous le repère
    let frame = 0;
    let lastIndex = -1;
    const watch = () => {
      if (doneRef.current) return;
      const offset = -new DOMMatrix(getComputedStyle(strip).transform).m41;
      const index = Math.floor((offset + viewport.clientWidth / 2) / step);
      if (index !== lastIndex) {
        if (lastIndex !== -1) playCaseTick();
        lastIndex = index;
      }
      frame = requestAnimationFrame(watch);
    };
    frame = requestAnimationFrame(watch);

    const onEnd = (event: TransitionEvent) => {
      if (event.target === strip) finish();
    };
    strip.addEventListener('transitionend', onEnd);
    // Filet de sécurité si transitionend n'arrive pas (page cachée, etc.)
    const fallback = window.setTimeout(finish, spin.duration * 1000 + 400);
    return () => {
      cancelAnimationFrame(frame);
      strip.removeEventListener('transitionend', onEnd);
      window.clearTimeout(fallback);
    };
  }, [spin.key, spin.winner, spin.duration, finish]);

  // Échap : passe l'animation, puis ferme (avant le menu, qui se fermerait sinon)
  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key !== 'Escape') return;
      event.preventDefault();
      if (doneRef.current) actions.closeCase();
      else skip();
    };
    window.addEventListener('keydown', onKeyDown, true);
    return () => window.removeEventListener('keydown', onKeyDown, true);
  }, [actions, skip]);

  return (
    <div className="case-opening">
      <div className="case-opening__head">
        <span className="mono case-opening__eyebrow">{t('OUVERTURE DE CAISSE')}</span>
        <h2 className="disp case-opening__title">{definition?.label ? t(definition.label) : itemLabel(config, spin.caseId)}</h2>
      </div>

      <div className="case-reel" ref={viewportRef}>
        <div className="case-reel__strip" ref={stripRef}>
          {spin.reel.map((entry, i) => {
            const item = config.items[entry.item];
            const isWinner = done && i === spin.winner - 1;
            return (
              <div
                key={i}
                className={isWinner ? 'case-reel__tile case-reel__tile--winner' : 'case-reel__tile'}
                style={{ '--rarity': rarityOf(config, entry.rarity).color } as CSSProperties}
              >
                <ItemIcon name={entry.item} type={item?.type ?? 'material'} />
                <span className="case-reel__label">{itemLabel(config, entry.item)}</span>
                <span className="mono case-reel__count">{countLabel(entry)}</span>
              </div>
            );
          })}
        </div>
        <div className="case-reel__marker" />
      </div>

      <div className="case-opening__footer">
        {done && winner ? (
          <div className="case-result" style={{ '--rarity': winnerRarity.color } as CSSProperties}>
            <span className="case-result__icon">
              <ItemIcon name={winner.item} type={winnerItem?.type ?? 'material'} />
            </span>
            <span className="case-result__text">
              <span className="disp case-result__rarity">{t(winnerRarity.label)}</span>
              <span className="disp case-result__name">
                {itemLabel(config, winner.item)} <span className="mono case-result__count">{countLabel(winner)}</span>
              </span>
            </span>
            <div className="case-result__actions">
              <button
                className="btn btn--primary btn--small cut-s"
                disabled={owned <= 0}
                onClick={() => actions.openCase(spin.caseId)}
              >
                {t('Ouvrir une autre')}{owned > 0 ? ` (${owned})` : ''}
              </button>
              <button className="btn btn--small cut-s" onClick={actions.closeCase}>{t('Fermer')}</button>
            </div>
          </div>
        ) : (
          <button className="btn btn--small cut-s" onClick={skip}>{t('Passer')}</button>
        )}
      </div>
    </div>
  );
}
