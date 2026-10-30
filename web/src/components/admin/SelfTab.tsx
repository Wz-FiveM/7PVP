import { useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { AdminToggle } from '../../types/admin';
import { SpectateBar } from './FreeroamTab';

const TOGGLES: { key: AdminToggle; label: string; hint: string }[] = [
  { key: 'noclip', label: 'Noclip', hint: 'F11 · Z/Q/S/D, Espace / Ctrl, Maj rapide, Alt lent' },
  { key: 'god', label: 'Invincible', hint: 'Aucun dégât, même hors zone safe' },
  { key: 'invisible', label: 'Invisible', hint: 'Les autres joueurs ne te voient plus' },
];

/** Options personnelles de l'admin. */
export function SelfTab() {
  const t = useT();
  const { state, actions } = useGame();
  const { self } = state.admin;
  const [model, setModel] = useState('adder');

  return (
    <div className="admin-self">
      {self.spectating && <SpectateBar name={self.spectating} onStop={() => actions.adminAction({ action: 'spectateStop' })} />}
      {TOGGLES.map((toggle) => (
        <button
          key={toggle.key}
          className={self[toggle.key] ? 'admin-toggle admin-toggle--on cut-s' : 'admin-toggle cut-s'}
          onClick={() => actions.adminAction({ action: toggle.key })}
        >
          <span className="admin-toggle__text">
            <span className="disp admin-toggle__label">{t(toggle.label)}</span>
            <span className="admin-toggle__hint">{t(toggle.hint)}</span>
          </span>
          <span className="mono admin-toggle__state">{self[toggle.key] ? 'ON' : 'OFF'}</span>
        </button>
      ))}

      <span className="label">{t('Déplacement')}</span>
      <button className="btn btn--small cut-s" onClick={() => actions.adminAction({ action: 'tpWaypoint' })}>
        {t('Téléporter au marqueur de la carte')}
      </button>

      <span className="label">{t('Véhicule')}</span>
      <div className="admin-row">
        <input
          className="admin-input mono"
          placeholder={t('Modèle (ex : adder, sultan)')}
          value={model}
          onChange={(event) => setModel(event.target.value)}
        />
        <button className="btn btn--small btn--primary cut-s" onClick={() => actions.adminAction({ action: 'spawnVehicle', model })}>
          {t('Faire apparaître')}
        </button>
      </div>
      <button className="btn btn--small btn--danger cut-s" onClick={() => actions.adminAction({ action: 'deleteVehicle' })}>
        {t('Supprimer mon véhicule')}
      </button>
    </div>
  );
}
