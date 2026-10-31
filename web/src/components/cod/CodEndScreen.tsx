import { useState } from 'react';
import { t, useT } from '../../i18n';
import type { CodEndData } from '../../types/cod';
import { CodScoreTable } from './CodHud';
import { RankBadge, useSecondsLeft } from './CodParts';

const TITLES = { won: 'Victoire', lost: 'Défaite', draw: 'Égalité' };

/** Fin de partie : résultat, tableau des scores, XP gagnée. Le serveur renvoie ensuite au menu. */
export function CodEndScreen({ end }: { end: CodEndData }) {
  useT();
  const [at] = useState(Date.now);
  const seconds = useSecondsLeft(end.seconds, at);
  const summary = end.summary;
  const them = end.team === 'alpha' ? 'bravo' : 'alpha';
  const unlocks = summary
    ? [
        ...summary.unlocks.map((label) => t(label)),
        ...summary.weaponUnlocks.map((unlock) => `${t(unlock.label)} (${t(unlock.weapon)})`),
      ]
    : [];

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

      {summary && (
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
      )}
    </div>
  );
}
