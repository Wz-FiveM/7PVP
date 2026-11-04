import { useState } from 'react';
import { tacticalApi } from '../../api/tacticalApi';
import { useCountdown } from '../../hooks/useCountdown';
import { t } from '../../i18n';
import type { TacBoardRow, TacCatalog, TacEnd, TacTeam } from '../../types/tactical';
import { RoleIcon } from './tacticalIcons';
import { DivisionChip, RoleBadge, findRole } from './tacticalParts';

/** Résultats : le mot en très grand, le score de part et d'autre, une carte par coéquipier, la cote. */
export function TacticalEndScreen({ end, catalog, self }: { end: TacEnd; catalog: TacCatalog; self: number }) {
  const seconds = useCountdown(end.seconds, end);
  const [full, setFull] = useState(false);
  const [leaving, setLeaving] = useState(false);
  const enemy: TacTeam = end.team === 'alpha' ? 'bravo' : 'alpha';
  const summary = end.summary;
  const title = end.result === 'won' ? t('Victoire') : end.result === 'lost' ? t('Défaite') : t('Égalité');
  const team = end.board.filter((row) => row.team === end.team);

  const leave = async () => {
    if (leaving) return;
    setLeaving(true);
    const result = await tacticalApi.continueToMenu();
    if (!result?.ok) setLeaving(false);
  };

  return (
    <div className={`tac-end tac-end--${end.result}`}>
      <h1 className="tac-end__word disp">{title}</h1>
      <span className="disp tac-end__score tac-end__score--mine">{end.scores[end.team]}</span>
      <span className="disp tac-end__score tac-end__score--enemy">{end.scores[enemy]}</span>

      <header className="tac-end__head">
        <span className="label">{t(end.reason)}</span>
      </header>

      {full ? (
        <FullTable end={end} catalog={catalog} />
      ) : (
        <div className="tac-end__cards">
          {team.map((row) => (
            <PlayerCard key={row.id} row={row} catalog={catalog} mvp={row.id === end.mvp} me={row.id === self} />
          ))}
        </div>
      )}

      <footer className="tac-end__foot">
        {summary && (
          <div className="tac-end__rating">
            <DivisionChip catalog={catalog} division={summary.division} rating={summary.after} />
            <span className={`disp tac-end__change ${summary.change >= 0 ? 'tac-friend' : 'tac-enemy'}`}>
              {summary.change >= 0 ? '+' : ''}{summary.change}
            </span>
            {summary.promoted && <span className="tac-end__promoted">{t('Nouvelle division !')}</span>}
          </div>
        )}
        <div className="tac-end__buttons">
          <button className="tac-play__side-button" onClick={() => setFull(!full)}>
            {full ? t('Mon équipe') : t('Tableau complet')}
          </button>
          <button className="tac-play__start tac-end__continue" disabled={leaving} onClick={() => void leave()}>
            {t('Continuer')}
          </button>
        </div>
        <span className="muted tac-end__timer">{t('Retour au menu dans {seconds} s', { seconds })}</span>
      </footer>
    </div>
  );
}

function PlayerCard({ row, catalog, mvp, me }: { row: TacBoardRow; catalog: TacCatalog; mvp: boolean; me: boolean }) {
  const role = findRole(catalog, row.role);
  return (
    <article className={`tac-end-card tac-role--${role?.id ?? 'none'} ${mvp ? 'tac-end-card--mvp' : ''} ${me ? 'tac-end-card--me' : ''}`}>
      {mvp && <span className="tac-end-card__mvp disp">MVP</span>}
      <div className="tac-end-card__art">
        <RoleIcon id={role?.id} className="tac-end-card__icon" />
      </div>
      <div className="tac-end-card__body">
        <span className="label">{t(role?.label ?? '')}</span>
        <strong className="tac-end-card__name">{row.name}</strong>
        <span className="disp tac-end-card__kda">{row.kills} / {row.deaths} / {row.assists}</span>
        <span className="label">K / D / A</span>
        <span className="disp tac-end-card__score">{row.score}</span>
        <span className="label">{t('Score de combat')}</span>
      </div>
    </article>
  );
}

function FullTable({ end, catalog }: { end: TacEnd; catalog: TacCatalog }) {
  return (
    <table className="tac-table tac-end__table">
      <thead>
        <tr>
          <th />
          <th>{t('Joueur')}</th>
          <th>{t('Score')}</th>
          <th>K</th>
          <th>D</th>
          <th>A</th>
          <th>{t('Dégâts/manche')}</th>
          <th>{t('1ers kills')}</th>
          <th>{t('Poses')}</th>
          <th>{t('Désamorçages')}</th>
        </tr>
      </thead>
      <tbody>
        {end.board.map((row) => (
          <tr key={row.id} className={row.team === end.team ? 'tac-table__friend' : 'tac-table__enemy'}>
            <td><RoleBadge role={findRole(catalog, row.role)} size="s" /></td>
            <td>{row.name}{row.id === end.mvp && <span className="tac-end__mvp-tag">MVP</span>}</td>
            <td className="mono">{row.score}</td>
            <td className="mono">{row.kills}</td>
            <td className="mono">{row.deaths}</td>
            <td className="mono">{row.assists}</td>
            <td className="mono">{row.damage}</td>
            <td className="mono">{row.firstKills}</td>
            <td className="mono">{row.plants}</td>
            <td className="mono">{row.defuses}</td>
          </tr>
        ))}
      </tbody>
    </table>
  );
}
