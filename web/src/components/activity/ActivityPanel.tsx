import { useCallback, useEffect, useState } from 'react';
import { activityApi } from '../../api/activityApi';
import { isEnvBrowser } from '../../api/nui';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { ActivityInfo } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { Icon, type IconName } from '../icons/Icon';
import './activity.css';

/** Fenêtre d'un mode de jeu du Freeroam, ouverte en parlant à son organisateur. */
export function ActivityPanel() {
  const [activity, setActivity] = useState<ActivityInfo | null>(null);
  const [busy, setBusy] = useState(false);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action === 'activity') setActivity(message.data.open ? message.data.activity ?? null : null);
  }, []);
  useNuiMessage(handleMessage);

  const close = useCallback(() => {
    if (isEnvBrowser()) setActivity(null);
    activityApi.close();
  }, []);

  useEffect(() => {
    if (!activity) return undefined;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') close();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [activity, close]);

  if (!activity) return null;

  const start = async () => {
    setBusy(true);
    const result = await activityApi.start(activity.id);
    setBusy(false);
    if (result?.ok && isEnvBrowser()) setActivity(null);
  };

  return (
    <div className="activity" onMouseDown={(event) => event.target === event.currentTarget && close()}>
      <section className="activity__panel">
        <div className="stripes activity__line" />
        <header className="activity__header">
          <Icon name={(activity.icon as IconName) ?? 'flag'} size={30} strokeWidth={1.8} className="activity__icon" />
          <div className="activity__heading">
            {activity.tagline && <span className="mono activity__tag">{activity.tagline}</span>}
            <h1 className="disp activity__title">{activity.label}</h1>
          </div>
          <button className="btn btn--small activity__close" onClick={close} aria-label="Fermer">
            ✕
          </button>
        </header>
        {activity.description && <p className="activity__description">{activity.description}</p>}
        <footer className="activity__footer">
          <span className="label activity__hint">
            <span className="mono keycap--solid">ÉCHAP</span> Fermer
          </span>
          <button className="btn btn--primary activity__start" disabled={!activity.enabled || busy} onClick={start}>
            {!activity.enabled ? 'Bientôt disponible' : busy ? 'Lancement…' : 'Lancer'}
          </button>
        </footer>
      </section>
    </div>
  );
}
