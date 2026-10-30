import '@fontsource/chakra-petch/latin-600.css';
import '@fontsource/chakra-petch/latin-700.css';
import { useCallback, useEffect, useState } from 'react';
import { codApi } from '../../api/codApi';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCatalog, CodEndData, CodHudData, CodHudState, CodLoadingData, CodLoadoutData, CodProfile, CodQueueData, CodStateData } from '../../types/cod';
import type { NuiMessage } from '../../types/nui';
import { UiGuard } from '../ui/UiGuard';
import { CodClassPicker } from './CodClassPicker';
import { CodEndScreen } from './CodEndScreen';
import { CodHud } from './CodHud';
import { CodLoadingScreen } from './CodLoadingScreen';
import { CodLoadoutSelect } from './CodLoadoutSelect';
import { CodMenu } from './CodMenu';
import { CodPauseMenu } from './CodPauseMenu';
import './cod.css';

/** Mode Call of Duty : menu du mode, écran de chargement, HUD de partie, menu pause, sélecteur de classe, résultats. */
export function Cod({ visible }: { visible: boolean }) {
  useT();
  const { state, actions } = useGame();
  const [menuOpen, setMenuOpen] = useState(false);
  const [profile, setProfile] = useState<CodProfile | null>(null);
  const [catalog, setCatalog] = useState<CodCatalog | null>(null);
  const [queue, setQueue] = useState<CodQueueData | null>(null);
  const [pickerOpen, setPickerOpen] = useState(false);
  const [end, setEnd] = useState<CodEndData | null>(null);
  const [hud, setHud] = useState<CodHudState | null>(null);
  const [live, setLive] = useState<CodStateData | null>(null);
  const [loading, setLoading] = useState<CodLoadingData | null>(null);
  const [loadout, setLoadout] = useState<CodLoadoutData | null>(null);
  const paused = visible && state.pause.open && state.pause.info?.mode === 'cod';

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
      case 'codProfile':
        return setProfile(message.data);
      case 'codPicker':
        setPickerOpen(message.data.open);
        if (message.data.profile) setProfile(message.data.profile);
        return;
      case 'codEnd':
        return setEnd(message.data);
      case 'codLoading':
        return setLoading(message.data.open ? message.data : null);
      case 'codLoadout':
        if (message.data.profile) setProfile(message.data.profile);
        return setLoadout(message.data.open ? { seconds: message.data.seconds ?? 0, at: Date.now(), portrait: message.data.portrait } : null);
      case 'codHud': {
        const { open, ...data } = message.data;
        if (open) setEnd(null);
        setLive(null);
        return setHud(open && data.playlist ? { ...(data as CodHudData), at: Date.now() } : null);
      }
      case 'codState':
        return setLive(message.data);
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
      {/* Masqué sans être démonté : le fil des kills et les compteurs continuent pendant la pause */}
      <div className="cod-hud" hidden={paused || loading !== null || loadout !== null}>
        <CodHud hud={hud} live={live} catalog={catalog} rank={profile?.rank ?? 1} prestige={profile?.prestige ?? 0} name={profile?.name ?? ''} />
      </div>
      {loading && !paused && <CodLoadingScreen data={loading} />}
      {loadout && profile && catalog && (
        <UiGuard name="cod-loadout" onCrash={() => void codApi.deploy()}>
          <CodLoadoutSelect data={loadout} profile={profile} catalog={catalog} hud={hud} onProfile={setProfile} />
        </UiGuard>
      )}
      {end && <CodEndScreen end={end} />}
      {pickerOpen && profile && catalog && <CodClassPicker profile={profile} catalog={catalog} onProfile={setProfile} />}
      {menuOpen && profile && catalog && <CodMenu profile={profile} catalog={catalog} queue={queue} onProfile={setProfile} />}
      {paused && (
        <UiGuard name="cod-pause" onCrash={actions.closePause}>
          <CodPauseMenu hud={hud} live={live} profile={profile} catalog={catalog} onProfile={setProfile} />
        </UiGuard>
      )}
    </div>
  );
}
