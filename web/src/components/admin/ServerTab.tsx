import { useState } from 'react';
import { useGame } from '../../store/GameContext';

/** Actions sur tout le serveur. */
export function ServerTab() {
  const { actions } = useGame();
  const [mode, setMode] = useState('all');
  const [text, setText] = useState('');
  const [confirmClear, setConfirmClear] = useState(false);

  const announce = async () => {
    if (await actions.adminAction({ action: 'announce', mode, text })) setText('');
  };

  return (
    <div className="admin-server">
      <span className="label">Annonce dans le chat</span>
      <select className="admin-input" value={mode} onChange={(event) => setMode(event.target.value)}>
        <option value="all">Tous les modes</option>
        <option value="pvp">PvP</option>
        <option value="freeroam">Freeroam</option>
      </select>
      <textarea
        className="admin-input admin-textarea"
        placeholder="Message (affiché en [ADMIN])"
        maxLength={200}
        value={text}
        onChange={(event) => setText(event.target.value)}
      />
      <button className="btn btn--small btn--primary cut-s" onClick={announce} disabled={!text.trim()}>
        Envoyer l'annonce
      </button>

      <span className="label">Monde PvP</span>
      <button
        className="btn btn--small btn--danger cut-s"
        onClick={() => {
          if (!confirmClear) return setConfirmClear(true);
          setConfirmClear(false);
          actions.adminAction({ action: 'clearLoot' });
        }}
      >
        {confirmClear ? 'Confirmer : supprimer tous les sacs' : 'Supprimer tous les sacs de butin'}
      </button>
    </div>
  );
}
