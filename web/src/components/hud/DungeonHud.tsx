import { useEffect, useState } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';

/** Barre de la porte ou du boss, en haut au milieu. */
export function DungeonBar() {
  const { state } = useGame();
  const bar = state.dungeon?.bar;
  if (!bar) return null;
  const percent = bar.max > 0 ? Math.max(0, Math.min(100, (bar.value / bar.max) * 100)) : 0;

  return (
    <div className="dungeon-bar">
      <div className="dungeon-bar__head">
        <span className="disp dungeon-bar__label">{bar.label}</span>
        <span className="mono dungeon-bar__value">
          {Math.ceil(bar.value)} / {bar.max}
        </span>
      </div>
      <div className="dungeon-bar__track">
        <div className="dungeon-bar__fill" style={{ width: `${percent}%` }} />
      </div>
    </div>
  );
}

/** Donjon en cours : objectif, consigne, vies et temps restant. */
export function DungeonHud() {
  const t = useT();
  const { state } = useGame();
  const [, setTick] = useState(0);
  const dungeon = state.dungeon;

  useEffect(() => {
    if (!dungeon) return undefined;
    const timer = window.setInterval(() => setTick((tick) => tick + 1), 500);
    return () => window.clearInterval(timer);
  }, [dungeon]);

  if (!dungeon) return null;
  const seconds = Math.max(0, Math.ceil((dungeon.endsAt - Date.now()) / 1000));
  const time = `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
  const waiting = dungeon.status === 'waiting';

  return (
    <>
      <div className="dungeon-objective">
        <div className="mono dungeon-objective__tag">{t('DONJON')}</div>
        <div className="disp dungeon-objective__title">
          {waiting ? t('En attente : {players}/{max} joueurs', { players: dungeon.players, max: dungeon.maxPlayers }) : dungeon.objective}
        </div>
        {waiting ? (
          <div className="dungeon-objective__hint">
            {dungeon.leader ? t('/donjon invite <id> pour tes coéquipiers, /donjon lancer pour entrer.') : t('Le chef du groupe va lancer le donjon.')}
          </div>
        ) : (
          dungeon.hint && <div className="dungeon-objective__hint">{dungeon.hint}</div>
        )}
      </div>
      {dungeon.subtitle && <div className="dungeon-subtitle">{dungeon.subtitle}</div>}
      <div className="dungeon-status">
        {!waiting && (
          <span className="dungeon-status__lives">
            {Array.from({ length: dungeon.maxLives }, (_, index) => (
              <span
                key={index}
                className={index < dungeon.lives ? 'dungeon-status__life' : 'dungeon-status__life dungeon-status__life--lost'}
              />
            ))}
          </span>
        )}
        <span className="label">{t('Temps restant')}</span>
        <span className="mono dungeon-status__time">{time}</span>
      </div>
    </>
  );
}
