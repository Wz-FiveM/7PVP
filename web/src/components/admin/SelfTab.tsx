import { useState } from 'react';
import { useGame } from '../../store/GameContext';
import type { AdminSelf } from '../../types/admin';

const TOGGLES: { key: keyof AdminSelf; label: string; hint: string }[] = [
  { key: 'noclip', label: 'Noclip', hint: 'F11 · Z/Q/S/D, Espace / Ctrl, Maj rapide, Alt lent' },
  { key: 'god', label: 'Invincible', hint: 'Aucun dégât, même hors zone safe' },
  { key: 'invisible', label: 'Invisible', hint: 'Les autres joueurs ne te voient plus' },
];

/** Options personnelles de l'admin. */
export function SelfTab() {
  const { state, actions } = useGame();
  const { self } = state.admin;
  const [model, setModel] = useState('adder');

  return (
    <div className="admin-self">
      {TOGGLES.map((toggle) => (
        <button
          key={toggle.key}
          className={self[toggle.key] ? 'admin-toggle admin-toggle--on cut-s' : 'admin-toggle cut-s'}
          onClick={() => actions.adminAction({ action: toggle.key })}
        >
          <span className="admin-toggle__text">
            <span className="disp admin-toggle__label">{toggle.label}</span>
            <span className="admin-toggle__hint">{toggle.hint}</span>
          </span>
          <span className="mono admin-toggle__state">{self[toggle.key] ? 'ON' : 'OFF'}</span>
        </button>
      ))}

      <span className="label">Déplacement</span>
      <button className="btn btn--small cut-s" onClick={() => actions.adminAction({ action: 'tpWaypoint' })}>
        Téléporter au marqueur de la carte
      </button>

      <span className="label">Véhicule</span>
      <div className="admin-row">
        <input
          className="admin-input mono"
          placeholder="Modèle (ex : adder, sultan)"
          value={model}
          onChange={(event) => setModel(event.target.value)}
        />
        <button className="btn btn--small btn--primary cut-s" onClick={() => actions.adminAction({ action: 'spawnVehicle', model })}>
          Faire apparaître
        </button>
      </div>
      <button className="btn btn--small btn--danger cut-s" onClick={() => actions.adminAction({ action: 'deleteVehicle' })}>
        Supprimer mon véhicule
      </button>
    </div>
  );
}
