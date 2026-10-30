import { useCallback, useState } from 'react';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { t, useT } from '../../i18n';
import type { CodLoadingData } from '../../types/cod';
import type { NuiMessage } from '../../types/nui';

/** Écran de chargement d'une partie : la carte (vue en jeu derrière l'interface), le mode, une astuce, le pourcentage. */
export function CodLoadingScreen({ data }: { data: CodLoadingData }) {
  useT();
  const [progress, setProgress] = useState(0);

  const handleMessage = useCallback((message: NuiMessage) => {
    if (message.action === 'codLoadingProgress') setProgress(message.data.progress);
  }, []);
  useNuiMessage(handleMessage);

  return (
    <div className="cod-loading">
      <header className="cod-loading__head">
        <h1 className="cod-loading__map">{t(data.map.label)}</h1>
        <span className="cod-loading__place">{t(data.map.place)}</span>
        <span className="cod-loading__mode">{t(data.playlist)}</span>
      </header>
      <footer className="cod-loading__foot">
        <p className="cod-loading__tip">{t(data.tip)}</p>
        <span className="cod-loading__track"><span style={{ width: `${progress}%` }} /></span>
        <span className="cod-loading__status">{t('Chargement de la partie... ({progress} %)', { progress })}</span>
      </footer>
    </div>
  );
}
