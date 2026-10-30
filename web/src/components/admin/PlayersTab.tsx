import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { AdminAction, AdminPlayer } from '../../types/admin';
import type { ContainerId } from '../../types/game';
import { formatMoney } from '../../utils/format';
import { SpectateBar } from './FreeroamTab';

const MODE_LABEL: Record<string, string> = { pvp: 'PvP', freeroam: 'Freeroam' };

/** Liste des joueurs connectés + actions sur le joueur sélectionné. */
export function PlayersTab() {
  const t = useT();
  const { state, actions } = useGame();
  const [players, setPlayers] = useState<AdminPlayer[]>([]);
  const [search, setSearch] = useState('');
  const [selectedId, setSelectedId] = useState<number | null>(null);

  const refresh = useCallback(async () => {
    const list = await adminApi.players();
    setPlayers(Array.isArray(list) ? list : []);
  }, []);

  useEffect(() => {
    refresh();
  }, [refresh]);

  const filtered = useMemo(() => {
    const query = search.trim().toLowerCase();
    return players.filter((p) => !query || p.name.toLowerCase().includes(query) || String(p.id) === query);
  }, [players, search]);

  const selected = players.find((p) => p.id === selectedId) ?? null;

  /** Action sur le joueur sélectionné, puis rafraîchit la liste */
  const run = async (action: AdminAction, extra: Record<string, unknown> = {}) => {
    if (!selected) return false;
    const ok = await actions.adminAction({ action, target: selected.id, ...extra });
    refresh();
    return ok;
  };

  return (
    <div className="admin-players">
      {state.admin.self.spectating && (
        <SpectateBar name={state.admin.self.spectating} onStop={() => actions.adminAction({ action: 'spectateStop' })} />
      )}
      <div className="admin-row">
        <input
          className="admin-input"
          placeholder={t('Rechercher (nom ou ID)')}
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <button className="btn btn--small cut-s" onClick={refresh}>
          {t('Actualiser')}
        </button>
      </div>

      <ul className="admin-list">
        {filtered.map((player) => (
          <li key={player.id}>
            <button
              className={player.id === selectedId ? 'admin-player admin-player--active' : 'admin-player'}
              onClick={() => setSelectedId(player.id)}
            >
              <span className="mono admin-player__id">{player.id}</span>
              <span className="admin-player__name">{player.name}</span>
              {player.dead && <span className="admin-player__dead mono">{t('MORT')}</span>}
              <span className="mono admin-player__mode">{player.mode ? MODE_LABEL[player.mode] ?? player.mode : t('Lobby')}</span>
            </button>
          </li>
        ))}
        {filtered.length === 0 && <li className="muted admin-empty">{t('Aucun joueur.')}</li>}
      </ul>

      {selected && <PlayerActions player={selected} items={state.config.items} onRun={run} />}
    </div>
  );
}

interface PlayerActionsProps {
  player: AdminPlayer;
  items: ReturnType<typeof useGame>['state']['config']['items'];
  onRun: (action: AdminAction, extra?: Record<string, unknown>) => Promise<boolean>;
}

function PlayerActions({ player, items, onRun }: PlayerActionsProps) {
  const t = useT();
  const itemNames = useMemo(() => Object.keys(items).sort((a, b) => items[a].label.localeCompare(items[b].label, 'fr')), [items]);
  const [item, setItem] = useState(itemNames[0] ?? '');
  const [count, setCount] = useState(1);
  const [container, setContainer] = useState<ContainerId>('bag');
  const [amount, setAmount] = useState(1000);
  const [reason, setReason] = useState('');
  const [confirmKick, setConfirmKick] = useState(false);

  useEffect(() => setConfirmKick(false), [player.id]);

  return (
    <section className="admin-target">
      <header className="admin-target__header">
        <span className="disp admin-target__name">{player.name}</span>
        <span className="mono muted">
          ID {player.id} · {t('NIV. {level}', { level: player.level })} · {formatMoney(player.money)}
        </span>
      </header>

      <span className="label">{t('État')}</span>
      <div className="admin-grid">
        <button className="btn btn--small cut-s" onClick={() => onRun('heal')}>{t('Soigner')}</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('revive')}>{t('Réanimer')}</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('freeze', { state: true })}>{t('Geler')}</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('freeze', { state: false })}>{t('Dégeler')}</button>
        <button className="btn btn--small btn--danger cut-s" onClick={() => onRun('kill')}>{t('Tuer')}</button>
      </div>

      <span className="label">{t('Position')}</span>
      <div className="admin-grid">
        <button className="btn btn--small cut-s" onClick={() => onRun('gotoPlayer')}>{t('Aller à lui')}</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('bringPlayer')}>{t('Ramener')}</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('sendToLobby')}>{t('Envoyer au lobby')}</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('spectate')}>{t('Regarder')}</button>
      </div>

      <span className="label">{t('Donner un objet')}</span>
      <div className="admin-row">
        <select className="admin-input" value={item} onChange={(event) => setItem(event.target.value)}>
          {itemNames.map((name) => (
            <option key={name} value={name}>
              {t(items[name].label)}
            </option>
          ))}
        </select>
        <input
          className="admin-input admin-input--small mono"
          type="number"
          min={1}
          value={count}
          onChange={(event) => setCount(Math.max(1, Number(event.target.value) || 1))}
        />
      </div>
      <div className="admin-row">
        <select className="admin-input" value={container} onChange={(event) => setContainer(event.target.value as ContainerId)}>
          <option value="bag">{t('Dans le sac')}</option>
          <option value="protected">{t('Dans le conteneur protégé')}</option>
        </select>
        <button className="btn btn--small btn--primary cut-s" onClick={() => onRun('giveItem', { item, count, container })}>
          {t('Donner')}
        </button>
      </div>

      <span className="label">{t("Donner de l'argent")}</span>
      <div className="admin-row">
        <input
          className="admin-input mono"
          type="number"
          min={1}
          value={amount}
          onChange={(event) => setAmount(Math.max(1, Number(event.target.value) || 1))}
        />
        <button className="btn btn--small btn--primary cut-s" onClick={() => onRun('giveMoney', { amount })}>
          {t('Donner')}
        </button>
      </div>

      <span className="label">{t('Expulser')}</span>
      <div className="admin-row">
        <input
          className="admin-input"
          placeholder={t('Raison')}
          maxLength={120}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
        />
        <button
          className="btn btn--small btn--danger cut-s"
          onClick={() => (confirmKick ? onRun('kick', { reason }) : setConfirmKick(true))}
        >
          {confirmKick ? t('Confirmer') : t('Expulser')}
        </button>
      </div>
    </section>
  );
}
