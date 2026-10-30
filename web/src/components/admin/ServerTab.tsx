import { useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';

/** Actions sur tout le serveur. */
export function ServerTab() {
  const t = useT();
  const { actions } = useGame();
  const [mode, setMode] = useState('all');
  const [text, setText] = useState('');
  const [confirmClear, setConfirmClear] = useState(false);

  const announce = async () => {
    if (await actions.adminAction({ action: 'announce', mode, text })) setText('');
  };

  return (
    <div className="admin-server">
      <span className="label">{t('Annonce dans le chat')}</span>
      <select className="admin-input" value={mode} onChange={(event) => setMode(event.target.value)}>
        <option value="all">{t('Tous les modes')}</option>
        <option value="pvp">PvP</option>
        <option value="freeroam">Freeroam</option>
      </select>
      <textarea
        className="admin-input admin-textarea"
        placeholder={t('Message (affiché en [ADMIN])')}
        maxLength={200}
        value={text}
        onChange={(event) => setText(event.target.value)}
      />
      <button className="btn btn--small btn--primary cut-s" onClick={announce} disabled={!text.trim()}>
        {t("Envoyer l'annonce")}
      </button>

      <span className="label">{t('Monde PvP')}</span>
      <button className="btn btn--small cut-s" onClick={() => actions.adminAction({ action: 'airdrop' })}>
        {t('Lancer un largage sur moi')}
      </button>
      <button className="btn btn--small cut-s" onClick={() => actions.adminAction({ action: 'horde' })}>
        {t('Lancer une horde (zone PvE la plus proche)')}
      </button>
      <button
        className="btn btn--small btn--danger cut-s"
        onClick={() => {
          if (!confirmClear) return setConfirmClear(true);
          setConfirmClear(false);
          actions.adminAction({ action: 'clearLoot' });
        }}
      >
        {confirmClear ? t('Confirmer : supprimer tous les sacs') : t('Supprimer tous les sacs de butin')}
      </button>
    </div>
  );
}
