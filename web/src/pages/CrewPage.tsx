import { useState, type FormEvent } from 'react';
import { crewApi } from '../api/crewApi';
import { CrewBonusPanel } from '../components/crew/CrewBonusPanel';
import { CrewTournamentPanel, CrewWarPanel } from '../components/crew/CrewWarPanels';
import { Panel } from '../components/ui/Panel';
import { formatNumber, useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { ActionResult } from '../types/nui';
import './pages.css';

/** Crew : créer le sien avec son label de 3 lettres, inviter, gérer les membres. */
export function CrewPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { crew, crewInvite, player, territories } = state;
  const config = state.config.crew;
  const territoryMinutes = Math.round((config?.territoryInterval ?? 300) / 60);
  const [tag, setTag] = useState('');
  const [name, setName] = useState('');
  const [target, setTarget] = useState('');
  const [confirmDisband, setConfirmDisband] = useState(false);

  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  const create = (event: FormEvent) => {
    event.preventDefault();
    crewApi.create(tag, name).then(report);
  };

  const invite = (event: FormEvent) => {
    event.preventDefault();
    const id = Number(target);
    if (!Number.isInteger(id) || id <= 0) return actions.notify(t('Entre l\'ID du joueur (visible dans le chat).'), 'error');
    crewApi.invite(id).then(report);
    setTarget('');
  };

  const me = crew?.members.find((member) => member.id === player?.source);
  const isLeader = Boolean(me?.leader);
  const canManage = Boolean(me?.leader || me?.officer);

  return (
    <div className="group-page">
      {crewInvite && (
        <Panel className="group-invite">
          <span className="disp group-invite__text">
            {t('{name} t\'invite dans le crew [{tag}] {crew}', { name: crewInvite.fromName, tag: crewInvite.tag, crew: crewInvite.name })}
          </span>
          <div className="group-invite__actions">
            <button className="btn btn--primary btn--small cut-s" onClick={() => crewApi.respond(true).then(report)}>
              {t('Accepter')}
            </button>
            <button className="btn btn--small cut-s" onClick={() => crewApi.respond(false).then(report)}>
              {t('Refuser')}
            </button>
          </div>
        </Panel>
      )}

      {crew ? (
        <Panel className="group-panel">
          <div className="crew-title">
            <span className="disp crew-title__tag">[{crew.tag}]</span>
            <span className="crew-title__name">{crew.name}</span>
            <span className="mono crew-title__count">
              {crew.members.length}/{config?.maxMembers ?? crew.members.length}
            </span>
          </div>
          <ul className="group-members">
            {crew.members.map((member) => (
              <li
                key={member.key}
                className={`group-member crew-member${member.id === false ? ' crew-member--offline' : ''}${isLeader && !member.leader ? ' crew-member--managed' : ''}`}
              >
                <span className="mono group-member__id">{member.id === false ? t('HORS LIGNE') : `#${member.id}`}</span>
                <span className="group-member__name">
                  {member.name}
                  {member.leader && <span className="chip group-member__chief">{t('Chef')}</span>}
                  {member.officer && <span className="chip group-member__chief">{t('Officier')}</span>}
                </span>
                {isLeader && !member.leader ? (
                  <span className="crew-member__actions">
                    <button className="btn btn--small cut-s" onClick={() => crewApi.officer(member.key).then(report)}>
                      {member.officer ? t('Retirer officier') : t('Nommer officier')}
                    </button>
                    <button className="btn btn--small cut-s" onClick={() => crewApi.transfer(member.key).then(report)}>
                      {t('Nommer chef')}
                    </button>
                    <button className="btn btn--danger btn--small cut-s" onClick={() => crewApi.kick(member.key).then(report)}>
                      {t('Exclure')}
                    </button>
                  </span>
                ) : (
                  <span />
                )}
              </li>
            ))}
          </ul>

          {isLeader && (
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
          <div className="group-invite__actions">
            <button className="btn btn--danger btn--small cut-s" onClick={() => crewApi.leave().then(report)}>
              {t('Quitter le crew')}
            </button>
            {isLeader && (
              <button
                className="btn btn--danger btn--small cut-s"
                onClick={() => {
                  if (!confirmDisband) return setConfirmDisband(true);
                  setConfirmDisband(false);
                  crewApi.disband().then(report);
                }}
                onBlur={() => setConfirmDisband(false)}
              >
                {confirmDisband ? t('Confirmer la dissolution') : t('Dissoudre le crew')}
              </button>
            )}
          </div>
        </Panel>
      ) : (
        <Panel className="group-panel">
          <span className="label">{t('Créer un crew')}</span>
          <form className="crew-form" onSubmit={create}>
            <div className="crew-form__row">
              <input
                className="field crew-form__tag mono"
                value={tag}
                onChange={(event) => setTag(event.target.value.toUpperCase().replace(/[^A-Z]/g, '').slice(0, 3))}
                placeholder="MGZ"
              />
              <input
                className="field"
                value={name}
                maxLength={config?.nameMaxLength}
                onChange={(event) => setName(event.target.value)}
                placeholder={t('Nom du crew')}
              />
            </div>
            <button className="btn btn--primary btn--small cut-s" type="submit" disabled={tag.length !== 3 || !name.trim()}>
              {config?.createPrice ? t('Créer · ${price}', { price: formatNumber(config.createPrice) }) : t('Créer')}
            </button>
          </form>
          <p className="muted">{t('Tu n\'es dans aucun crew. Crée le tien ou demande une invitation à un chef.')}</p>
        </Panel>
      )}

      {crew && <CrewBonusPanel crew={crew} canManage={canManage} />}
      {crew && <CrewWarPanel crew={crew} isLeader={isLeader} />}
      <CrewTournamentPanel crew={crew} isLeader={isLeader} />

      {territories.length > 0 && (
        <Panel className="group-panel">
          <span className="label">{t('Territoires')}</span>
          <ul className="crew-territories">
            {territories.map((territory) => (
              <li key={territory.id} className={territory.mine ? 'crew-territory crew-territory--mine' : 'crew-territory'}>
                <span className="crew-territory__name">{t(territory.label)}</span>
                <span className="crew-territory__owner">{territory.ownerLabel || t('Libre')}</span>
                <span className="mono crew-territory__income">
                  {t('${amount} / {minutes} min', { amount: formatNumber(territory.income), minutes: territoryMinutes })}
                </span>
              </li>
            ))}
          </ul>
        </Panel>
      )}

      <Panel className="group-rules">
        <span className="label">{t('Règles')}</span>
        <ul className="group-rules__list">
          <li>{t('Le label du crew (3 lettres) s\'affiche devant ton nom en PvP : gamertags, chat, killfeed, classement.')}</li>
          <li>{t('Jusqu\'à {count} membres. Un crew reste d\'une session à l\'autre, même hors ligne.', { count: config?.maxMembers ?? 20 })}</li>
          <li>{t('Tu vois le gamertag des membres de ton crew au-dessus de leur tête.')}</li>
          <li>{t('Le tir allié reste actif dans un crew : forme une équipe pour le couper.')}</li>
          <li>{t('Un territoire capturé paie chaque membre connecté en PvP, et reste au crew d\'une session à l\'autre. {count} territoires au plus par crew.', { count: config?.maxTerritories ?? 2 })}</li>
          <li>{t('Coffre du crew chez le banquier : tous les membres y déposent et y retirent, le journal garde qui a fait quoi. Vide-le avant de dissoudre le crew.')}</li>
          <li>{t('Classement des crews (menu Top joueurs) : 1 point par kill fait une fois dans le crew, {score} points par territoire pris.', { score: config?.captureScore ?? 10 })}</li>
          <li>{t('Guerre et tournoi : les gains arrivent dans le coffre du crew, un kill sur la même victime ne compte pas deux fois de suite en peu de temps.')}</li>
          <li>{t('Points de crew : gagnés par les kills, les territoires, les guerres et le tournoi. Le chef et les officiers les dépensent pour agrandir le coffre et acheter des armes pour le coffre. Perdre un territoire ne retire rien de ce qui est acheté.')}</li>
          <li>{t('Chat : /crewinviter ID, /crewaccepter, /crewrefuser, /crewquitter.')}</li>
        </ul>
      </Panel>
    </div>
  );
}
