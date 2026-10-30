import { useState, type FormEvent } from 'react';
import { groupApi } from '../api/groupApi';
import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { ActionResult } from '../types/nui';
import './pages.css';

/** Équipe : inviter par ID, répondre à une invitation, gérer les membres. */
export function GroupPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { group, groupInvite, groupVitals, player } = state;
  const [target, setTarget] = useState('');

  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  const invite = (event: FormEvent) => {
    event.preventDefault();
    const id = Number(target);
    if (!Number.isInteger(id) || id <= 0) return actions.notify(t('Entre l\'ID du joueur (visible dans le chat).'), 'error');
    groupApi.invite(id).then(report);
    setTarget('');
  };

  const isLeader = Boolean(group && player && group.leader === player.source);

  return (
    <div className="group-page">
      {groupInvite && (
        <Panel className="group-invite">
          <span className="disp group-invite__text">{t('{name} t\'invite dans son équipe', { name: groupInvite.fromName })}</span>
          <div className="group-invite__actions">
            <button className="btn btn--primary btn--small cut-s" onClick={() => groupApi.respond(true).then(report)}>
              {t('Accepter')}
            </button>
            <button className="btn btn--small cut-s" onClick={() => groupApi.respond(false).then(report)}>
              {t('Refuser')}
            </button>
          </div>
        </Panel>
      )}

      <Panel className="group-panel">
        <span className="label">{t('Mon équipe')}</span>
        {group ? (
          <ul className="group-members">
            {group.members.map((member) => {
              const vital = groupVitals.find((v) => v.id === member.id);
              return (
                <li key={member.id} className="group-member">
                  <span className="mono group-member__id">#{member.id}</span>
                  <span className="group-member__name">
                    {member.name}
                    {member.id === group.leader && <span className="chip group-member__chief">{t('Chef')}</span>}
                  </span>
                  <span className="group-member__vitals">
                    {vital && vital.health !== false ? (
                      <SegmentBar value={vital.health} max={100} segments={10} height={4} />
                    ) : (
                      <span className="mono muted">{t('HORS DE PORTÉE')}</span>
                    )}
                  </span>
                  {isLeader && member.id !== player?.source && (
                    <button
                      className="btn btn--danger btn--small cut-s"
                      onClick={() => groupApi.kick(member.id).then(report)}
                    >
                      {t('Exclure')}
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        ) : (
          <p className="muted">{t('Tu joues seul. Invite un joueur pour créer une équipe.')}</p>
        )}

        {(!group || isLeader) && (
          <form className="group-form" onSubmit={invite}>
            <input
              className="field group-form__input"
              value={target}
              onChange={(event) => setTarget(event.target.value.replace(/\D/g, ''))}
              placeholder={t('ID du joueur')}
              inputMode="numeric"
            />
            <button className="btn btn--primary btn--small cut-s" type="submit">
              {t('Inviter')}
            </button>
          </form>
        )}
        {group && (
          <button className="btn btn--danger btn--small cut-s group-leave" onClick={() => groupApi.leave().then(report)}>
            {t('Quitter l\'équipe')}
          </button>
        )}
      </Panel>

      <Panel className="group-rules">
        <span className="label">{t('Règles')}</span>
        <ul className="group-rules__list">
          <li>{t('Jusqu\'à {count} joueurs, en PvP seulement.', { count: state.config.groupMaxSize ?? 4 })}</li>
          <li>{t('Pas de tir allié entre coéquipiers.')}</li>
          <li>{t('Tes coéquipiers apparaissent en bleu sur la carte, à toute distance, avec leur vie à gauche de l\'écran.')}</li>
          <li>{t('Chat : /inviter ID, /accepter, /refuser, /quittergroupe.')}</li>
        </ul>
      </Panel>
    </div>
  );
}
