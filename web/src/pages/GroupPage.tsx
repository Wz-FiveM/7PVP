import { useState, type FormEvent } from 'react';
import { groupApi } from '../api/groupApi';
import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { useGame } from '../store/GameContext';
import type { ActionResult } from '../types/nui';
import './pages.css';

/** Équipe : inviter par ID, répondre à une invitation, gérer les membres. */
export function GroupPage() {
  const { state, actions } = useGame();
  const { group, groupInvite, groupVitals, player } = state;
  const [target, setTarget] = useState('');

  const report = (result: ActionResult) => {
    if (result.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  const invite = (event: FormEvent) => {
    event.preventDefault();
    const id = Number(target);
    if (!Number.isInteger(id) || id <= 0) return actions.notify('Entre l\'ID du joueur (visible dans le chat).', 'error');
    groupApi.invite(id).then(report);
    setTarget('');
  };

  const isLeader = Boolean(group && player && group.leader === player.source);

  return (
    <div className="group-page">
      {groupInvite && (
        <Panel className="group-invite">
          <span className="disp group-invite__text">{groupInvite.fromName} t'invite dans son équipe</span>
          <div className="group-invite__actions">
            <button className="btn btn--primary btn--small cut-s" onClick={() => groupApi.respond(true).then(report)}>
              Accepter
            </button>
            <button className="btn btn--small cut-s" onClick={() => groupApi.respond(false).then(report)}>
              Refuser
            </button>
          </div>
        </Panel>
      )}

      <Panel className="group-panel">
        <span className="label">Mon équipe</span>
        {group ? (
          <ul className="group-members">
            {group.members.map((member) => {
              const vital = groupVitals.find((v) => v.id === member.id);
              return (
                <li key={member.id} className="group-member">
                  <span className="mono group-member__id">#{member.id}</span>
                  <span className="group-member__name">
                    {member.name}
                    {member.id === group.leader && <span className="chip group-member__chief">Chef</span>}
                  </span>
                  <span className="group-member__vitals">
                    {vital && vital.health !== false ? (
                      <SegmentBar value={vital.health} max={100} segments={10} height={4} />
                    ) : (
                      <span className="mono muted">HORS DE PORTÉE</span>
                    )}
                  </span>
                  {isLeader && member.id !== player?.source && (
                    <button
                      className="btn btn--danger btn--small cut-s"
                      onClick={() => groupApi.kick(member.id).then(report)}
                    >
                      Exclure
                    </button>
                  )}
                </li>
              );
            })}
          </ul>
        ) : (
          <p className="muted">Tu joues seul. Invite un joueur pour créer une équipe.</p>
        )}

        {(!group || isLeader) && (
          <form className="group-form" onSubmit={invite}>
            <input
              className="field group-form__input"
              value={target}
              onChange={(event) => setTarget(event.target.value.replace(/\D/g, ''))}
              placeholder="ID du joueur"
              inputMode="numeric"
            />
            <button className="btn btn--primary btn--small cut-s" type="submit">
              Inviter
            </button>
          </form>
        )}
        {group && (
          <button className="btn btn--danger btn--small cut-s group-leave" onClick={() => groupApi.leave().then(report)}>
            Quitter l'équipe
          </button>
        )}
      </Panel>

      <Panel className="group-rules">
        <span className="label">Règles</span>
        <ul className="group-rules__list">
          <li>Jusqu'à {state.config.groupMaxSize ?? 4} joueurs, en PvP seulement.</li>
          <li>Pas de tir allié entre coéquipiers.</li>
          <li>Tes coéquipiers apparaissent en bleu sur la carte, à toute distance, avec leur vie à gauche de l'écran.</li>
          <li>Chat : /inviter ID, /accepter, /refuser, /quittergroupe.</li>
        </ul>
      </Panel>
    </div>
  );
}
