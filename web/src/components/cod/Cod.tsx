import '@fontsource/chakra-petch/latin-600.css';
import '@fontsource/chakra-petch/latin-700.css';
import { useCallback, useEffect, useState } from 'react';
import { codApi } from '../../api/codApi';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { useT } from '../../i18n';
import type { CodCatalog, CodEndData, CodProfile, CodQueueData } from '../../types/cod';
import type { NuiMessage } from '../../types/nui';
import { CodClassPicker } from './CodClassPicker';
import { CodEndScreen } from './CodEndScreen';
import { CodHud } from './CodHud';
import { CodMenu } from './CodMenu';
import './cod.css';

/** Mode Call of Duty : menu du mode, HUD de partie, sélecteur de classe, résultats. */
export function Cod({ visible }: { visible: boolean }) {
  useT();
  const [menuOpen, setMenuOpen] = useState(false);
  const [profile, setProfile] = useState<CodProfile | null>(null);
  const [catalog, setCatalog] = useState<CodCatalog | null>(null);
  const [queue, setQueue] = useState<CodQueueData | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [end, setEnd] = useState<CodEndData | null>(null);

  const handleMessage = useCallback((message: NuiMessage) => {
    switch (message.action) {
      case 'codMenu':
        setMenuOpen(message.data.open);
        if (message.data.open) setEnd(null);
        if (message.data.profile) setProfile(message.data.profile);
        if (message.data.catalog) setCatalog(message.data.catalog);
        return;
      case 'codQueue':
        return setQueue(message.data.count > 0 ? message.data : null);
      case 'codPicker':
        setPickerOpen(message.data.open);
        if (message.data.profile) setProfile(message.data.profile);
        return;
      case 'codEnd':
        return setEnd(message.data);
      case 'codHud':
        if (message.data.open) setEnd(null);
        return;
    }
  }, []);
  useNuiMessage(handleMessage);

  useEffect(() => {
    if (!pickerOpen) return;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') codApi.closePicker();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [pickerOpen]);

  return (
    <div className="cod" hidden={!visible}>
      <CodHud catalog={catalog} rank={profile?.rank ?? 1} name={profile?.name ?? ''} />
      {end && <CodEndScreen end={end} />}
      {pickerOpen && profile && catalog && <CodClassPicker profile={profile} catalog={catalog} onProfile={setProfile} />}
      {menuOpen && profile && catalog && <CodMenu profile={profile} catalog={catalog} queue={queue} onProfile={setProfile} />}
    </div>
  );
}
