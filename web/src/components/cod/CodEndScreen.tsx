import { useEffect, useState } from 'react';
import { t, useT } from '../../i18n';
import type { CodEndData } from '../../types/cod';
import { CodScoreTable } from './CodHud';
import { RankBadge, useSecondsLeft } from './CodParts';
import { CodPlayerCard } from './CodPlayerCard';

const TITLES = { won: 'Victoire', lost: 'Défaite', draw: 'Égalité' };
// Le premier au milieu, le deuxième à droite, le troisième à gauche : comme les personnages du podium
const PODIUM_ORDER = [2, 0, 1];

/** Fin de partie : podium, puis résultat, tableau des scores et XP gagnée. Le serveur renvoie ensuite au menu. */
export function CodEndScreen({ end }: { end: CodEndData }) {
  useT();
  const [at] = useState(Date.now);
  const podiumSeconds = end.podium ? end.podiumSeconds ?? 0 : 0;
  const [onPodium, setOnPodium] = useState(podiumSeconds > 0);
  const seconds = useSecondsLeft(end.seconds + podiumSeconds, at);
  const summary = end.summary;
  const them = end.team === 'alpha' ? 'bravo' : 'alpha';
  const unlocks = summary
    ? [
        ...summary.unlocks.map((label) => t(label)),
        ...summary.weaponUnlocks.map((unlock) => `${t(unlock.label)} (${t(unlock.weapon)})`),
      ]
    : [];

  useEffect(() => {
    if (podiumSeconds <= 0) return;
    const timer = window.setTimeout(() => setOnPodium(false), podiumSeconds * 1000);
    return () => window.clearTimeout(timer);
  }, [podiumSeconds]);

  if (onPodium && end.podium) {
    return (
      <div className={`cod-podium cod-end--${end.result}`}>
        <h1 className="cod-title">{t(TITLES[end.result])}</h1>
        <div className="cod-podium__cards">
          {PODIUM_ORDER.map((position) => {
            const entry = end.podium?.[position];
            return entry ? (
              <div key={entry.id} className={position === 0 ? 'cod-podium__card cod-podium__card--first' : 'cod-podium__card'}>
                <CodPlayerCard card={entry.card} label={`#${position + 1}`} />
              </div>
            ) : null;
          })}
        </div>
      </div>
    );
  }

  return (
    <div className={`cod-end cod-end--${end.result}`}>
      <header className="cod-end__head">
        <h1 className="cod-title">{t(TITLES[end.result])}</h1>
        <span className="cod-subtitle">{end.reason}</span>
        {end.scores && end.team && (
          <span className="cod-end__score">
            <span className="cod-end__us">{end.scores[end.team]}</span>
            <span className="cod-end__sep">/</span>
            <span>{end.scores[them]}</span>
          </span>
        )}
      </header>

      <CodScoreTable board={end.board} team={end.team} />

      {summary ? (
        <footer className="cod-end__xp">
          <RankBadge rank={summary.rankAfter} prestige={summary.prestige} size={56} />
          <div className="cod-end__xp-text">
            <span className="cod-end__earned">+{summary.earned} XP</span>
            <span className="cod-label">{t('Dont {bonus} XP de fin de partie', { bonus: summary.bonus })}</span>
            {summary.rankAfter > summary.rankBefore && (
              <span className="cod-end__rankup">{t('Rang {rank} atteint !', { rank: summary.rankAfter })}</span>
            )}
            {summary.canPrestige && (
              <span className="cod-end__rankup">{t('Prestige disponible dans le menu !')}</span>
            )}
            {unlocks.length > 0 && (
              <span className="cod-end__unlocks">{t('Débloqué : {list}', { list: unlocks.join(', ') })}</span>
            )}
          </div>
          <span className="cod-end__next">{t('Retour au menu dans {seconds} s', { seconds })}</span>
        </footer>
      ) : (
        <footer className="cod-end__xp">
          <span className="cod-label">{t('Partie privée : ni XP ni progression')}</span>
          <span className="cod-end__next">{t('Retour au menu dans {seconds} s', { seconds })}</span>
        </footer>
      )}
    </div>
  );
}
