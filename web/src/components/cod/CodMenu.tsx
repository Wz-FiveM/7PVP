import { useEffect, useState } from 'react';
import { codApi } from '../../api/codApi';
import { gameApi } from '../../api/gameApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCatalog, CodLeaderboardRow, CodPartyData, CodProfile, CodQueueData } from '../../types/cod';
import { CodChallengesTab } from './CodChallengesTab';
import { CodPartyInvite, CodPartyTab } from './CodPartyTab';
import { CodClassEditor } from './CodClassEditor';
import { CodOperatorsTab } from './CodOperatorsTab';
import { BracketButton, CodOperator, isUnlocked, RankBadge, RankCell, useSecondsLeft } from './CodParts';
import { CodPlayerCard } from './CodPlayerCard';
import { CodPlayerCardTab } from './CodPlayerCardTab';
import { CodPrestigeTab } from './CodPrestigeTab';

type Tab = 'play' | 'party' | 'classes' | 'streaks' | 'challenges' | 'operators' | 'card' | 'prestige' | 'profile' | 'board';

const TABS: { id: Tab; label: string; title: string; subtitle: string }[] = [
  { id: 'play', label: 'Salon', title: 'Multijoueur', subtitle: 'Salon d\'attente' },
  { id: 'party', label: 'Escouade', title: 'Escouade', subtitle: 'Joue avec tes amis' },
  { id: 'classes', label: 'Classes', title: 'Classes', subtitle: 'Compose ton équipement' },
  { id: 'streaks', label: 'Séries', title: 'Séries', subtitle: 'Choisis tes séries d\'éliminations' },
  { id: 'challenges', label: 'Défis', title: 'Défis', subtitle: 'Termine-les pour gagner de l\'XP' },
  { id: 'operators', label: 'Personnages', title: 'Personnages', subtitle: 'Choisis qui tu incarnes' },
  { id: 'card', label: 'Carte de joueur', title: 'Carte de joueur', subtitle: 'Vue par ceux que tu élimines' },
  { id: 'prestige', label: 'Prestige', title: 'Prestige', subtitle: 'Repars du rang 1 avec un nouvel insigne' },
  { id: 'profile', label: 'Profil', title: 'Profil', subtitle: 'Ta progression' },
  { id: 'board', label: 'Classement', title: 'Classement', subtitle: 'Les meilleurs joueurs' },
];

const MAX_SHOWN_SLOTS = 12;

interface CodMenuProps {
  profile: CodProfile;
  catalog: CodCatalog;
  queue: CodQueueData | null;
  party: CodPartyData | null;
  /** nom du joueur qui vient d'inviter, null sans invitation */
  invite: string | null;
  onInviteClosed: () => void;
  onProfile: (profile: CodProfile) => void;
}

/** Menu du mode : titre et onglets en haut, personnage au centre (le décor du jeu reste visible). */
export function CodMenu({ profile, catalog, queue, party, invite, onInviteClosed, onProfile }: CodMenuProps) {
  useT();
  const [tab, setTab] = useState<Tab>('play');
  const current = TABS.find((entry) => entry.id === tab) ?? TABS[0];

  return (
    <div className="cod-menu">
      <header className="cod-menu__head">
        <div className="cod-menu__titles">
          <h1 className="cod-title">{t(current.title)}</h1>
          <span className="cod-subtitle">{t(current.subtitle)}</span>
        </div>
        <CodOperator profile={profile} />
      </header>

      <nav className="cod-tabs">
        {TABS.map((entry) => (
          <button
            key={entry.id}
            className={[
              'cod-tab',
              entry.id === tab && 'cod-tab--active',
              entry.id === 'prestige' && (profile.canPrestige || profile.tokens > 0) && 'cod-tab--alert',
            ].filter(Boolean).join(' ')}
            onClick={() => setTab(entry.id)}
          >
            {t(entry.label)}
          </button>
        ))}
      </nav>

      <div className="cod-menu__body">
        {tab === 'play' && <PlayTab catalog={catalog} queue={queue} />}
        {tab === 'party' && <CodPartyTab party={party} catalog={catalog} />}
        {tab === 'classes' && <CodClassEditor profile={profile} catalog={catalog} onProfile={onProfile} />}
        {tab === 'streaks' && <StreaksTab profile={profile} catalog={catalog} onProfile={onProfile} />}
        {tab === 'challenges' && <CodChallengesTab profile={profile} />}
        {tab === 'operators' && <CodOperatorsTab profile={profile} catalog={catalog} onProfile={onProfile} />}
        {tab === 'card' && <CodPlayerCardTab profile={profile} catalog={catalog} onProfile={onProfile} />}
        {tab === 'prestige' && <CodPrestigeTab profile={profile} catalog={catalog} searching={Boolean(queue)} onProfile={onProfile} />}
        {tab === 'profile' && <ProfileTab profile={profile} />}
        {tab === 'board' && <BoardTab />}
      </div>
      {invite && <CodPartyInvite fromName={invite} onClose={onInviteClosed} />}
    </div>
  );
}

// ---------------------------------------------------------------------------
// Salon
// ---------------------------------------------------------------------------

function PlayTab({ catalog, queue }: { catalog: CodCatalog; queue: CodQueueData | null }) {
  useT();
  const { actions } = useGame();
  const [selectedId, setSelectedId] = useState(catalog.playlists[0]?.id);
  const [busy, setBusy] = useState(false);
  const activeId = queue?.playlist ?? selectedId;
  const playlist = catalog.playlists.find((entry) => entry.id === activeId) ?? catalog.playlists[0];
  const searching = Boolean(queue);
  const shownPlaylists = searching ? catalog.playlists.filter((entry) => entry.id === activeId) : catalog.playlists;

  const toggle = async () => {
    if (!playlist || busy) return;
    setBusy(true);
    const result = await codApi.queue(playlist.id);
    if (result?.message) actions.notify(result.message, result.ok ? 'info' : 'error');
    setBusy(false);
  };

  return (
    <>
      <section className="cod-column">
        <button className="cod-leave" onClick={() => gameApi.leaveToLobby()}>{t('Retour au lobby')}</button>
        <span className="cod-label">{t('Mode de jeu')}</span>
        <ul className="cod-list">
          {/* Pendant la recherche, le vote de carte a besoin de la place : seul le mode choisi reste */}
          {shownPlaylists.map((entry, index) => (
            <li key={entry.id}>
              {entry.warzone && !shownPlaylists[index - 1]?.warzone && <span className="cod-options__group">{t('Warzone')}</span>}
              <button
                className={entry.id === activeId ? 'cod-list__row cod-list__row--active' : 'cod-list__row'}
                disabled={searching}
                onClick={() => setSelectedId(entry.id)}
              >
                <span>{t(entry.label)}</span>
                <span className="cod-list__meta">{entry.short}</span>
              </button>
            </li>
          ))}
        </ul>
        {playlist && !searching && <p className="cod-text">{t(playlist.description)}</p>}

        <div className="cod-column__foot">
          <QueueStatus queue={queue} playlistLabel={playlist?.label ?? ''} />
          <BracketButton onClick={toggle} disabled={busy} danger={searching}>
            {searching ? t('Annuler la recherche') : t('Rechercher une partie')}
          </BracketButton>
        </div>
      </section>

      <section className="cod-column cod-column--right">
        <span className="cod-label">
          {t('Joueurs ({count}/{max})', { count: queue?.count ?? 0, max: queue?.max ?? playlist?.maxPlayers ?? 0 })}
        </span>
        <PlayerSlots queue={queue} max={queue?.max ?? playlist?.maxPlayers ?? 0} />
      </section>
    </>
  );
}

/** Carte en bas à gauche : attente de joueurs, puis vote de carte. */
function QueueStatus({ queue, playlistLabel }: { queue: CodQueueData | null; playlistLabel: string }) {
  useT();
  const [mark, setMark] = useState({ startIn: 0, at: 0 });
  useEffect(() => {
    if (queue?.startIn) setMark({ startIn: queue.startIn, at: Date.now() });
  }, [queue?.startIn]);
  const seconds = useSecondsLeft(mark.startIn, mark.at);

  if (!queue) return null;
  if (queue.maps) {
    return (
      <div className="cod-vote">
        <span className="cod-label">{t('Vote de carte · {seconds} s', { seconds })}</span>
        {queue.maps.map((map) => (
          <button
            key={map.id}
            className={queue.vote === map.id ? 'cod-map cod-map--voted' : 'cod-map'}
            onClick={() => codApi.vote(map.id)}
          >
            <span className={`cod-map__art cod-map__art--${map.id}`} />
            <span className="cod-map__votes">{t('{count} VOTES', { count: map.votes })}</span>
            <span className="cod-map__text">
              <span className="cod-map__name">{t(map.label)}</span>
              <span className="cod-map__place">{t(map.place)}</span>
            </span>
          </button>
        ))}
      </div>
    );
  }
  return (
    <div className="cod-status">
      <span className="cod-status__title">{t('En attente de joueurs pour le vote')}</span>
      <span className="cod-status__text">{t(playlistLabel)} · {queue.count}/{queue.needed ?? 2}</span>
    </div>
  );
}

function PlayerSlots({ queue, max }: { queue: CodQueueData | null; max: number }) {
  useT();
  const names = queue?.names ?? [];
  const cards = queue?.cards ?? [];
  return (
    <ul className="cod-slots">
      {/* Warzone : trop de places pour la colonne, on montre les premières */}
      {Array.from({ length: Math.min(max, MAX_SHOWN_SLOTS) }, (_, index) => (
        cards[index]
          ? <li key={index}><CodPlayerCard card={cards[index]} compact /></li>
          : (
            <li key={index} className={names[index] ? 'cod-slot cod-slot--filled' : 'cod-slot'}>
              <span className="cod-slot__index">{index + 1}</span>
              <span>{names[index] ?? t('Recherche de joueurs…')}</span>
            </li>
          )
      ))}
    </ul>
  );
}

// ---------------------------------------------------------------------------
// Séries
// ---------------------------------------------------------------------------

export function StreaksTab({ profile, catalog, onProfile }: { profile: CodProfile; catalog: CodCatalog; onProfile: (profile: CodProfile) => void }) {
  useT();
  const { actions } = useGame();
  const [chosen, setChosen] = useState(profile.streaks);
  const dirty = JSON.stringify(chosen) !== JSON.stringify(profile.streaks);

  const toggle = (id: string) =>
    setChosen((list) => {
      if (list.includes(id)) return list.filter((entry) => entry !== id);
      return list.length < catalog.maxStreaks ? [...list, id] : list;
    });
  const save = async () => {
    const result = await codApi.saveStreaks(chosen);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.profile) onProfile(result.profile);
  };

  return (
    <section className="cod-column cod-column--wide">
      <span className="cod-label">{t('Séries choisies : {count}/{max}', { count: chosen.length, max: catalog.maxStreaks })}</span>
      <ul className="cod-list cod-list--scroll">
        {catalog.streaks.map((streak) => {
          const locked = !isUnlocked(streak.id, streak.rank, profile);
          const active = chosen.includes(streak.id);
          return (
            <li key={streak.id}>
              <button
                className={[
                  'cod-list__row cod-list__row--tall',
                  active && 'cod-list__row--active',
                  locked && 'cod-list__row--locked',
                ].filter(Boolean).join(' ')}
                disabled={locked}
                onClick={() => toggle(streak.id)}
              >
                <span className="cod-list__kills">{streak.kills}</span>
                <span className="cod-list__stack">
                  <span>{t(streak.label)}</span>
                  <span className="cod-list__hint">{t(streak.description)}</span>
                </span>
                {locked && <span className="cod-locked">{t('RANG {rank}', { rank: streak.rank })}</span>}
              </button>
            </li>
          );
        })}
      </ul>
      <p className="cod-text">{t('Utilise une série gagnée avec la touche {key}.', { key: catalog.keys.streak })}</p>
      <div className="cod-column__foot">
        <BracketButton onClick={save} disabled={!dirty || chosen.length === 0}>{t('Enregistrer')}</BracketButton>
      </div>
    </section>
  );
}

// ---------------------------------------------------------------------------
// Profil et classement
// ---------------------------------------------------------------------------

function ProfileTab({ profile }: { profile: CodProfile }) {
  useT();
  const ratio = profile.deaths > 0 ? (profile.kills / profile.deaths).toFixed(2) : profile.kills.toFixed(2);
  const stats: [string, string | number][] = [
    ['Éliminations', profile.kills],
    ['Morts', profile.deaths],
    ['Ratio', ratio],
    ['Assistances', profile.assists],
    ['Victoires', profile.wins],
    ['Défaites', profile.losses],
    ['Meilleure série', profile.bestStreak],
    ['XP totale', profile.xp],
    ['Prestige', profile.prestige],
  ];
  return (
    <section className="cod-column cod-column--wide">
      <div className="cod-profile__rank">
        <RankBadge rank={profile.rank} prestige={profile.prestige} size={72} />
        <div>
          <span className="cod-label">{t('Rang {rank} sur {max}', { rank: profile.rank, max: profile.maxRank })}</span>
          <span className="cod-profile__name">{profile.name}</span>
        </div>
      </div>
      <CodPlayerCard card={{ ...profile.card, name: profile.name, rank: profile.rank, prestige: profile.prestige }} />
      <dl className="cod-stats">
        {stats.map(([label, value]) => (
          <div key={label} className="cod-stats__row">
            <dt>{t(label)}</dt>
            <dd>{value}</dd>
          </div>
        ))}
      </dl>
    </section>
  );
}

function BoardTab() {
  useT();
  const [rows, setRows] = useState<CodLeaderboardRow[] | null>(null);
  useEffect(() => {
    codApi.leaderboard().then((result) => setRows(result?.rows ?? []));
  }, []);

  return (
    <section className="cod-column cod-column--wide">
      {rows === null && <p className="cod-text">{t('Chargement…')}</p>}
      {rows?.length === 0 && <p className="cod-text">{t('Personne au classement pour le moment.')}</p>}
      {rows && rows.length > 0 && (
        <table className="cod-table">
          <thead>
            <tr>
              <th>#</th>
              <th className="cod-table__name">{t('Joueur')}</th>
              <th>{t('Rang')}</th>
              <th>{t('Kills')}</th>
              <th>{t('Morts')}</th>
              <th>{t('Victoires')}</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => (
              <tr key={`${row.name}-${index}`}>
                <td>{index + 1}</td>
                <td className="cod-table__name">{row.name}</td>
                <td><RankCell rank={row.rank} prestige={row.prestige} /></td>
                <td>{row.kills}</td>
                <td>{row.deaths}</td>
                <td>{row.wins}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </section>
  );
}
