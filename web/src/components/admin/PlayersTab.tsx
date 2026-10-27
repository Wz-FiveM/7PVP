import { useCallback, useEffect, useMemo, useState } from 'react';
import { adminApi } from '../../api/adminApi';
import { useGame } from '../../store/GameContext';
import type { AdminAction, AdminPlayer } from '../../types/admin';
import type { ContainerId } from '../../types/game';
import { formatMoney } from '../../utils/format';

const MODE_LABEL: Record<string, string> = { pvp: 'PvP', freeroam: 'Freeroam' };

/** Liste des joueurs connectés + actions sur le joueur sélectionné. */
export function PlayersTab() {
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
      <div className="admin-row">
        <input
          className="admin-input"
          placeholder="Rechercher (nom ou ID)"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <button className="btn btn--small cut-s" onClick={refresh}>
          Actualiser
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
              {player.dead && <span className="admin-player__dead mono">MORT</span>}
              <span className="mono admin-player__mode">{player.mode ? MODE_LABEL[player.mode] ?? player.mode : 'Lobby'}</span>
            </button>
          </li>
        ))}
        {filtered.length === 0 && <li className="muted admin-empty">Aucun joueur.</li>}
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
          ID {player.id} · NIV. {player.level} · {formatMoney(player.money)}
        </span>
      </header>

      <span className="label">État</span>
      <div className="admin-grid">
        <button className="btn btn--small cut-s" onClick={() => onRun('heal')}>Soigner</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('revive')}>Réanimer</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('freeze', { state: true })}>Geler</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('freeze', { state: false })}>Dégeler</button>
        <button className="btn btn--small btn--danger cut-s" onClick={() => onRun('kill')}>Tuer</button>
      </div>

      <span className="label">Position</span>
      <div className="admin-grid">
        <button className="btn btn--small cut-s" onClick={() => onRun('gotoPlayer')}>Aller à lui</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('bringPlayer')}>Ramener</button>
        <button className="btn btn--small cut-s" onClick={() => onRun('sendToLobby')}>Envoyer au lobby</button>
      </div>

      <span className="label">Donner un objet</span>
      <div className="admin-row">
        <select className="admin-input" value={item} onChange={(event) => setItem(event.target.value)}>
          {itemNames.map((name) => (
            <option key={name} value={name}>
              {items[name].label}
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
          <option value="bag">Dans le sac</option>
          <option value="protected">Dans le conteneur protégé</option>
        </select>
        <button className="btn btn--small btn--primary cut-s" onClick={() => onRun('giveItem', { item, count, container })}>
          Donner
        </button>
      </div>

      <span className="label">Donner de l'argent</span>
      <div className="admin-row">
        <input
          className="admin-input mono"
          type="number"
          min={1}
          value={amount}
          onChange={(event) => setAmount(Math.max(1, Number(event.target.value) || 1))}
        />
        <button className="btn btn--small btn--primary cut-s" onClick={() => onRun('giveMoney', { amount })}>
          Donner
        </button>
      </div>

      <span className="label">Expulser</span>
      <div className="admin-row">
        <input
          className="admin-input"
          placeholder="Raison"
          maxLength={120}
          value={reason}
          onChange={(event) => setReason(event.target.value)}
        />
        <button
          className="btn btn--small btn--danger cut-s"
          onClick={() => (confirmKick ? onRun('kick', { reason }) : setConfirmKick(true))}
        >
          {confirmKick ? 'Confirmer' : 'Expulser'}
        </button>
      </div>
    </section>
  );
}
