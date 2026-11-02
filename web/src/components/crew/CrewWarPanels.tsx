import { useCallback, useEffect, useState, type FormEvent } from 'react';
import { crewApi } from '../../api/crewApi';
import { formatNumber, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CrewData, CrewTournamentState } from '../../types/game';
import type { ActionResult } from '../../types/nui';
import { Panel } from '../ui/Panel';

const REFRESH_MS = 10000;

function minutesLeft(seconds: number | undefined): number {
  return Math.ceil((seconds ?? 0) / 60);
}

function formatDelay(t: ReturnType<typeof useT>, seconds: number): string {
  const days = Math.floor(seconds / 86400);
  const hours = Math.floor((seconds % 86400) / 3600);
  if (days > 0) return t('{days} j {hours} h', { days, hours });
  return t('{hours} h {minutes} min', { hours, minutes: Math.floor((seconds % 3600) / 60) });
}

/** Guerre de crews : défi lancé par le chef, mise prise dans le coffre, score en direct. */
export function CrewWarPanel({ crew, isLeader }: { crew: CrewData; isLeader: boolean }) {
  const t = useT();
  const { state, actions } = useGame();
  const settings = state.config.crew?.war;
  const [tag, setTag] = useState('');
  const [stake, setStake] = useState('');
  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  const declare = (event: FormEvent) => {
    event.preventDefault();
    crewApi.warDeclare(tag, Number(stake)).then(report);
    setTag('');
    setStake('');
  };

  const { war, warChallenge } = crew;
  return (
    <Panel className="group-panel">
      <span className="label">{t('Guerre de crews')}</span>
      {war ? (
        <div className="crew-war">
          <span className="disp crew-war__score">
            [{crew.tag}] {war.kills} - {war.enemyKills} [{war.enemyTag}]
          </span>
          <span className="muted">
            {t('Pot de ${amount} · reste {minutes} min', { amount: formatNumber(war.stake * 2), minutes: minutesLeft(war.endsIn) })}
          </span>
        </div>
      ) : (
        <>
          {warChallenge && (
            <div className="group-invite">
              <span className="disp group-invite__text">
                {t('[{tag}] vous défie : ${amount} de mise de chaque côté.', { tag: warChallenge.tag, amount: formatNumber(warChallenge.stake) })}
              </span>
              {isLeader && (
                <div className="group-invite__actions">
                  <button className="btn btn--primary btn--small cut-s" onClick={() => crewApi.warRespond(true).then(report)}>
                    {t('Accepter')}
                  </button>
                  <button className="btn btn--small cut-s" onClick={() => crewApi.warRespond(false).then(report)}>
                    {t('Refuser')}
                  </button>
                </div>
              )}
            </div>
          )}
          {isLeader && !warChallenge && (
            <form className="group-form" onSubmit={declare}>
              <input
                className="field crew-form__tag mono"
                value={tag}
                onChange={(event) => setTag(event.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 3))}
                placeholder="RXN"
              />
              <input
                className="field group-form__input"
                value={stake}
                onChange={(event) => setStake(event.target.value.replace(/\D/g, ''))}
                placeholder={t('Mise (${min} à ${max})', { min: formatNumber(settings?.minStake ?? 0), max: formatNumber(settings?.maxStake ?? 0) })}
                inputMode="numeric"
              />
              <button className="btn btn--primary btn--small cut-s" type="submit" disabled={tag.length !== 3 || !stake}>
                {t('Défier')}
              </button>
            </form>
          )}
          <p className="muted">
            {t('Chaque crew met la même somme, prise dans l\'argent de son coffre. Pendant {minutes} min, le crew qui fait le plus de kills sur l\'autre prend tout.', { minutes: minutesLeft(settings?.duration) })}
          </p>
        </>
      )}
    </Panel>
  );
}

/** Tournoi de la semaine : inscription par le chef, tableau des crews inscrits. */
export function CrewTournamentPanel({ crew, isLeader }: { crew: CrewData | null; isLeader: boolean }) {
  const t = useT();
  const { actions } = useGame();
  const [data, setData] = useState<CrewTournamentState | null>(null);

  const refresh = useCallback(async () => {
    const result = await crewApi.tournament();
    if (result) setData(result);
  }, []);

  useEffect(() => {
    refresh();
    const timer = window.setInterval(refresh, REFRESH_MS);
    return () => window.clearInterval(timer);
  }, [refresh]);

  if (!data) return null;
  const registered = data.crews.some((row) => row.mine);
  const join = async () => {
    const result = await crewApi.tournamentJoin();
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    await refresh();
  };

  return (
    <Panel className="group-panel">
      <span className="label">{t('Tournoi de crews')}</span>
      <span className="muted">
        {data.running
          ? t('En cours · reste {minutes} min · ${amount} pour le crew en tête', { minutes: minutesLeft(data.endsIn), amount: formatNumber(data.prize) })
          : t('Début dans {delay} · ${amount} pour le crew en tête · {min} crews au moins', { delay: formatDelay(t, data.startsIn), amount: formatNumber(data.prize), min: data.minCrews })}
      </span>
      {data.crews.length > 0 && (
        <ul className="crew-territories">
          {data.crews.map((row) => (
            <li key={row.tag} className={row.mine ? 'crew-territory crew-territory--mine' : 'crew-territory'}>
              <span className="crew-territory__name">[{row.tag}] {row.name}</span>
              <span />
              <span className="mono crew-territory__income">{row.kills}</span>
            </li>
          ))}
        </ul>
      )}
      {crew && isLeader && !data.running && !registered && (
        <button className="btn btn--primary btn--small cut-s" onClick={join}>
          {t('Inscrire mon crew')}
        </button>
      )}
      <p className="muted">{t('Seuls les kills entre crews inscrits comptent, partout en PvP. Le prix arrive dans le coffre du crew.')}</p>
    </Panel>
  );
}
