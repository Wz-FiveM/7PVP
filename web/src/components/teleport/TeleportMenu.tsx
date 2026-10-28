import { useCallback, useEffect, useState } from 'react';
import { isEnvBrowser } from '../../api/nui';
import { teleportApi } from '../../api/teleportApi';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { TeleportMenuData, TeleportZone } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { Icon } from '../icons/Icon';
import './teleport.css';

/** Menu de téléportation (F1) et barre d'attente avant le départ, en mode PvP. */
export function Teleport() {
  const [menu, setMenu] = useState<TeleportMenuData | null>(null);
  const [channel, setChannel] = useState<{ seconds: number; at: number } | null>(null);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action === 'teleport') {
      const { open, ...data } = message.data;
      setMenu(open && data.zones ? (data as TeleportMenuData) : null);
    }
    if (message.action === 'teleportChannel') {
      const { seconds } = message.data;
      setChannel(seconds ? { seconds, at: Date.now() } : null);
    }
  }, []);
  useNuiMessage(handleMessage);

  const close = useCallback(() => {
    if (isEnvBrowser()) setMenu(null);
    teleportApi.close();
  }, []);

  return (
    <>
      {menu && <TeleportPanel data={menu} onClose={close} onChannel={(seconds) => setChannel({ seconds, at: Date.now() })} />}
      {channel && <TeleportChannel seconds={channel.seconds} startedAt={channel.at} />}
    </>
  );
}

interface TeleportPanelProps {
  data: TeleportMenuData;
  onClose: () => void;
  /** hors jeu : simule l'attente renvoyée par le serveur */
  onChannel: (seconds: number) => void;
}

function TeleportPanel({ data, onClose, onChannel }: TeleportPanelProps) {
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' || event.key === data.key) onClose();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [data.key, onClose]);

  const go = async (zone: TeleportZone) => {
    setBusy(true);
    const result = await teleportApi.go(zone.id);
    setBusy(false);
    if (!result?.ok) return setError(result?.message ?? 'Téléportation impossible.');
    if (isEnvBrowser()) {
      onClose();
      if (data.channel > 0) onChannel(data.channel);
    }
  };

  const blocked = data.pending;

  return (
    <div className="teleport" onMouseDown={(event) => event.target === event.currentTarget && onClose()}>
      <section className="teleport__panel zone-safe">
        <div className="stripes teleport__stripes" />
        <header className="teleport__header">
          <Icon name="flag" size={26} strokeWidth={2} className="teleport__header-icon" />
          <div className="teleport__heading">
            <h1 className="disp teleport__title">
              Zones <span className="teleport__accent">safe</span>
            </h1>
            <span className="muted teleport__subtitle">
              {data.channel > 0
                ? `Hors zone safe : ${data.channel} s immobile et hors combat avant le départ`
                : 'Départ immédiat depuis la zone safe'}
            </span>
          </div>
          <button className="btn btn--small cut-s teleport__close" onClick={onClose} aria-label="Fermer">
            ✕
          </button>
        </header>

        {(blocked || error) && (
          <p className="mono teleport__notice">
            {data.pending ? 'Une téléportation est déjà en cours.' : error}
          </p>
        )}

        <ul className="teleport__list">
          {data.zones.map((zone) => (
            <li key={zone.id} className={zone.current ? 'teleport__zone teleport__zone--current cut' : 'teleport__zone cut'}>
              <span className="teleport__marker" />
              <div className="teleport__info">
                <span className="disp teleport__name">{zone.label.replace(/^Zone safe - /, '')}</span>
                {zone.description && <span className="muted teleport__description">{zone.description}</span>}
              </div>
              <span className="mono teleport__distance">{formatDistance(zone.distance)}</span>
              {zone.current ? (
                <span className="label teleport__here">Tu es ici</span>
              ) : (
                <button className="btn btn--primary btn--small cut-s" disabled={blocked || busy} onClick={() => go(zone)}>
                  Y aller
                </button>
              )}
            </li>
          ))}
        </ul>

        <footer className="label teleport__footer">
          <span className="mono teleport__key cut-s">{data.key}</span> ou <span className="mono teleport__key cut-s">Échap</span>{' '}
          pour fermer
        </footer>
      </section>
    </div>
  );
}

function formatDistance(meters: number): string {
  return meters >= 1000 ? `${(meters / 1000).toFixed(1).replace('.', ',')} km` : `${meters} m`;
}

const TICK = 100;

/** Barre d'attente avant le départ : le serveur annule si le joueur bouge ou entre en combat. */
function TeleportChannel({ seconds, startedAt }: { seconds: number; startedAt: number }) {
  const [now, setNow] = useState(Date.now);

  useEffect(() => {
    const timer = window.setInterval(() => setNow(Date.now()), TICK);
    return () => window.clearInterval(timer);
  }, [startedAt]);

  const elapsed = Math.min(seconds, (now - startedAt) / 1000);
  const remaining = Math.max(0, Math.ceil(seconds - elapsed));

  return (
    <div className="teleport-channel zone-safe">
      <div className="teleport-channel__head">
        <span className="disp teleport-channel__title">Téléportation</span>
        <span className="mono teleport-channel__time">{remaining} s</span>
      </div>
      <div className="teleport-channel__track">
        <div className="teleport-channel__fill" style={{ width: `${(elapsed / seconds) * 100}%` }} />
      </div>
      <span className="label teleport-channel__hint">Ne bouge pas et reste hors combat</span>
    </div>
  );
}
