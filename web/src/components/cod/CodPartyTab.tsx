import { useEffect, useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCatalog, CodPartyData, CodPartyLobby } from '../../types/cod';
import { BracketButton } from './CodParts';

const REFRESH = 5000; // ms entre deux relevés des joueurs à inviter

interface CodPartyTabProps {
  party: CodPartyData | null;
  catalog: CodCatalog;
}

/** Escouade : membres et partie privée à gauche, joueurs à inviter à droite. */
export function CodPartyTab({ party, catalog }: CodPartyTabProps) {
  useT();
  const self = party?.self;
  const { actions } = useGame();
  const [lobby, setLobby] = useState<CodPartyLobby>({ players: [], maps: [] });
  const [playlist, setPlaylist] = useState(catalog.playlists[0]?.id);
  const [map, setMap] = useState<string | null>(null);
  const leader = !party || party.leader === self;
  const chosenMap = map ?? lobby.maps[0]?.id;

  useEffect(() => {
    const refresh = () => void codApi.partyLobby().then((result) => { if (result) setLobby(result); });
    refresh();
    const timer = window.setInterval(refresh, REFRESH);
    return () => window.clearInterval(timer);
  }, []);

  const report = (result?: { ok: boolean; message?: string }) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  return (
    <>
      <section className="cod-column">
        <span className="cod-label">{t('Mon escouade')}</span>
        {!party && <p className="cod-text">{t('Invite des joueurs : vous chercherez une partie ensemble, dans le même camp.')}</p>}
        {party && (
          <ul className="cod-list">
            {party.members.map((member) => (
              <li key={member.id} className="cod-party__row">
                <span>{member.name}</span>
                {member.id === party.leader && <span className="cod-list__meta">{t('CHEF')}</span>}
                {leader && member.id !== self && (
                  <button className="cod-party__kick" onClick={async () => report(await codApi.partyKick(member.id))}>{t('Exclure')}</button>
                )}
              </li>
            ))}
          </ul>
        )}
        {party && <button className="cod-leave" onClick={() => void codApi.partyLeave()}>{t('Quitter l\'escouade')}</button>}

        {leader && (
          <div className="cod-party__private">
            <span className="cod-label">{t('Partie privée')}</span>
            <p className="cod-list__hint">{t('Réservée à ton escouade, ou à toi seul pour découvrir une carte. Sans XP ni progression.')}</p>
            <select className="cod-input" aria-label={t('Mode de jeu')} value={playlist} onChange={(event) => setPlaylist(event.target.value)}>
              {catalog.playlists.map((entry) => <option key={entry.id} value={entry.id}>{t(entry.label)}</option>)}
            </select>
            <select className="cod-input" aria-label={t('Carte')} value={chosenMap ?? ''} onChange={(event) => setMap(event.target.value)}>
              {lobby.maps.map((entry) => <option key={entry.id} value={entry.id}>{t(entry.label)}</option>)}
            </select>
            <BracketButton disabled={!chosenMap} onClick={async () => { if (chosenMap && playlist) report(await codApi.startPrivate(playlist, chosenMap)); }}>
              {t('Lancer la partie privée')}
            </BracketButton>
          </div>
        )}
      </section>

      <section className="cod-column cod-column--right cod-column--scroll">
        <span className="cod-label">{t('Joueurs du mode')}</span>
        {lobby.players.length === 0 && <p className="cod-text">{t('Aucun autre joueur disponible pour le moment.')}</p>}
        <ul className="cod-options">
          {lobby.players.map((player) => (
            <li key={player.id}>
              <button
                className="cod-option"
                disabled={!leader || player.busy}
                onClick={async () => report(await codApi.partyInvite(player.id))}
              >
                <span className="cod-option__text"><span>{player.name}</span></span>
                <span className="cod-option__level">{player.busy ? t('EN PARTIE') : t('INVITER')}</span>
              </button>
            </li>
          ))}
        </ul>
      </section>
    </>
  );
}

/** Invitation reçue, par-dessus n'importe quel onglet du menu. */
export function CodPartyInvite({ fromName, onClose }: { fromName: string; onClose: () => void }) {
  useT();
  const { actions } = useGame();
  const answer = async (accept: boolean) => {
    onClose();
    const result = await codApi.partyRespond(accept);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };
  return (
    <div className="cod-party__invite">
      <span>{t('{name} t\'invite dans son escouade', { name: fromName })}</span>
      <div className="cod-column__foot--row">
        <BracketButton onClick={() => void answer(true)}>{t('Accepter')}</BracketButton>
        <BracketButton danger onClick={() => void answer(false)}>{t('Refuser')}</BracketButton>
      </div>
    </div>
  );
}
