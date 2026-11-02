import { useCallback, useEffect, useState } from 'react';
import { dungeonApi } from '../../api/dungeonApi';
import { isEnvBrowser } from '../../api/nui';
import { useT } from '../../i18n';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import type { DungeonMenuInfo } from '../../types/game';
import type { NuiMessage } from '../../types/nui';
import { Icon } from '../icons/Icon';
import '../activity/activity.css';

/** Menu de James : la liste des donjons et les clés qu'il faut pour entrer. */
export function DungeonMenu() {
  const t = useT();
  const [menu, setMenu] = useState<DungeonMenuInfo | null>(null);
  const [busy, setBusy] = useState(false);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action === 'dungeonMenu') setMenu(message.data.open ? message.data.menu ?? null : null);
  }, []);
  useNuiMessage(handleMessage);

  const close = useCallback(() => {
    if (isEnvBrowser()) setMenu(null);
    dungeonApi.close();
  }, []);

  useEffect(() => {
    if (!menu) return undefined;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') close();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [menu, close]);

  if (!menu) return null;

  const enough = menu.free || menu.keys >= menu.required;
  const open = async () => {
    setBusy(true);
    await dungeonApi.open();
    setBusy(false);
  };

  return (
    <div className="activity" onMouseDown={(event) => event.target === event.currentTarget && close()}>
      <section className="activity__panel">
        <div className="stripes activity__line" />
        <header className="activity__header">
          <Icon name="flag" size={30} strokeWidth={1.8} className="activity__icon" />
          <div className="activity__heading">
            <span className="mono activity__tag">{t('Donjons')}</span>
            <h1 className="disp activity__title">{menu.label}</h1>
          </div>
          <button className="btn btn--small activity__close" onClick={close} aria-label={t('Fermer')}>
            ✕
          </button>
        </header>
        <p className="activity__description">
          {t('Tu as besoin de {count} clés de donjon pour rentrer dans ce donjon, tes coéquipiers aussi. Tu en as {keys} sur toi.', {
            count: menu.required,
            keys: menu.keys,
          })}
        </p>
        <p className="activity__description">
          {t('{max} joueurs au plus : /donjon invite <id> pour tes coéquipiers, /donjon pret pour eux, /donjon lancer pour toi.', {
            max: menu.maxPlayers,
          })}
        </p>
        <footer className="activity__footer">
          <span className="label activity__hint">
            <span className="mono keycap--solid">{t('ÉCHAP')}</span> {t('Fermer')}
          </span>
          <button className="btn btn--primary activity__start" disabled={!enough || busy} onClick={open}>
            {enough ? t('Ouvrir le donjon') : t('Clés insuffisantes')}
          </button>
        </footer>
      </section>
    </div>
  );
}
