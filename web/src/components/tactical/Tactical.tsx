import { useCallback, useEffect, useRef, useState } from 'react';
import { tacticalApi } from '../../api/tacticalApi';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { useT } from '../../i18n';
import type { NuiMessage } from '../../types/nui';
import type { TacCatalog, TacDead, TacEnd, TacHud, TacKill, TacLineup, TacNotice, TacProfile, TacQueue, TacRound, TacRoundEnd, TacSelf, TacState } from '../../types/tactical';
import { UiGuard } from '../ui/UiGuard';
import { TacticalBuyMenu } from './TacticalBuyMenu';
import { TacticalEndScreen } from './TacticalEndScreen';
import { TacticalHud } from './TacticalHud';
import { TacticalLineup } from './TacticalLineup';
import { TacticalMenu } from './TacticalMenu';
import '@fontsource/saira-extra-condensed/latin-500.css';
import '@fontsource/saira-extra-condensed/latin-600.css';
import '@fontsource/saira-extra-condensed/latin-700.css';
import '@fontsource/saira-extra-condensed/latin-800.css';
import './tactical.css';

const KILLFEED_SECONDS = 6;
const NOTICE_SECONDS = 3.5;
const ROUND_END_SECONDS = 5;

export interface TacKillEntry extends TacKill {
  key: number;
}

export interface TacNoticeEntry extends TacNotice {
  key: number;
}

/** Mode Sabotage : menu du mode, menu d'achat, HUD de partie, résultats. */
export function Tactical({ visible }: { visible: boolean }) {
  useT();
  const [menuOpen, setMenuOpen] = useState(false);
  const [profile, setProfile] = useState<TacProfile | null>(null);
  const [catalog, setCatalog] = useState<TacCatalog | null>(null);
  const [maps, setMaps] = useState(0);
  const [queue, setQueue] = useState<TacQueue | null>(null);
  const [hud, setHud] = useState<TacHud | null>(null);
  const [round, setRound] = useState<(TacRound & { at: number }) | null>(null);
  const [self, setSelf] = useState<TacSelf | null>(null);
  const [live, setLive] = useState<(TacState & { at: number }) | null>(null);
  const [kills, setKills] = useState<TacKillEntry[]>([]);
  const [notices, setNotices] = useState<TacNoticeEntry[]>([]);
  const [dead, setDead] = useState<TacDead | null>(null);
  const [lineup, setLineup] = useState<TacLineup | null>(null);
  /** server id du joueur, gardé pour l'écran des résultats (le HUD est déjà fermé) */
  const [selfId, setSelfId] = useState(0);
  const [roundEnd, setRoundEnd] = useState<TacRoundEnd | null>(null);
  const [action, setAction] = useState<{ kind: string; seconds: number; at: number } | null>(null);
  const [buyOpen, setBuyOpen] = useState(false);
  const [scoreboard, setScoreboard] = useState(false);
  const [outside, setOutside] = useState(false);
  const [end, setEnd] = useState<TacEnd | null>(null);
  const nextKey = useRef(0);

  const pushNotice = useCallback((notice: TacNotice) => {
    const key = ++nextKey.current;
    setNotices((list) => [...list.slice(-2), { ...notice, key }]);
    window.setTimeout(() => setNotices((list) => list.filter((entry) => entry.key !== key)), NOTICE_SECONDS * 1000);
  }, []);

  const handleMessage = useCallback((message: NuiMessage) => {
    switch (message.action) {
      case 'tacMenu':
        setMenuOpen(message.data.open);
        if (message.data.open) setEnd(null);
        if (message.data.profile) setProfile(message.data.profile);
        if (message.data.catalog) setCatalog(message.data.catalog);
        if (message.data.maps !== undefined) setMaps(message.data.maps);
        return;
      case 'tacQueue':
        return setQueue(message.data || null);
      case 'tacHud': {
        const { open, ...data } = message.data;
        if (!open) {
          setHud(null);
          setLineup(null);
          setBuyOpen(false);
          setScoreboard(false);
          setAction(null);
          return;
        }
        setEnd(null);
        setLive(null);
        setRound(null);
        setSelf(null);
        setKills([]);
        setDead(null);
        setRoundEnd(null);
        if (data.catalog) setCatalog(data.catalog);
        if (data.self) setSelfId(data.self);
        return setHud(data as TacHud);
      }
      case 'tacRound':
        setRound({ ...message.data, at: Date.now() });
        setDead(null);
        setRoundEnd(null);
        setAction(null);
        return;
      case 'tacSelf':
        return setSelf(message.data);
      case 'tacState':
        return setLive({ ...message.data, at: Date.now() });
      case 'tacKill': {
        const key = ++nextKey.current;
        setKills((list) => [...list.slice(-4), { ...message.data, key }]);
        window.setTimeout(() => setKills((list) => list.filter((entry) => entry.key !== key)), KILLFEED_SECONDS * 1000);
        return;
      }
      case 'tacDead':
        return setDead(message.data);
      case 'tacLineup':
        return setLineup(message.data);
      case 'tacRoundEnd':
        setRoundEnd(message.data);
        setAction(null);
        window.setTimeout(() => setRoundEnd((current) => (current === message.data ? null : current)), ROUND_END_SECONDS * 1000);
        return;
      case 'tacEnd':
        return setEnd(message.data || null);
      case 'tacAction':
        return setAction(message.data.kind ? { kind: message.data.kind, seconds: message.data.seconds ?? 1, at: Date.now() } : null);
      case 'tacNotice':
        return pushNotice(message.data);
      case 'tacBuy':
        return setBuyOpen(message.data.open);
      case 'tacScoreboard':
        return setScoreboard(message.data.open);
      case 'tacOutside':
        return setOutside(message.data.outside);
    }
  }, [pushNotice]);
  useNuiMessage(handleMessage);

  // Échap ou la touche d'achat referment le menu d'achat
  useEffect(() => {
    if (!buyOpen || !catalog) return;
    const buyKey = catalog.keys.buy.toLowerCase();
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape' || event.key.toLowerCase() === buyKey) void tacticalApi.closeBuy();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [buyOpen, catalog]);

  return (
    <div className="tac" hidden={!visible}>
      {hud && catalog && (
        <UiGuard name="tac-hud">
          <TacticalHud
            hud={hud}
            catalog={catalog}
            round={round}
            self={self}
            live={live}
            kills={kills}
            notices={notices}
            dead={dead}
            roundEnd={roundEnd}
            action={action}
            scoreboard={scoreboard}
            outside={outside}
            hidden={buyOpen}
          />
        </UiGuard>
      )}
      {buyOpen && hud && catalog && self && (
        <UiGuard name="tac-buy" onCrash={() => void tacticalApi.closeBuy()}>
          <TacticalBuyMenu
            catalog={catalog}
            self={self}
            live={live}
            name={live?.board.find((row) => row.id === hud.self)?.name ?? profile?.name ?? ''}
          />
        </UiGuard>
      )}
      {hud && catalog && lineup && (!live || live.phase === 'loading') && (
        <TacticalLineup lineup={lineup} catalog={catalog} team={hud.team} self={hud.self} />
      )}
      {end && catalog && <TacticalEndScreen end={end} catalog={catalog} self={selfId} />}
      {menuOpen && profile && catalog && (
        <TacticalMenu profile={profile} catalog={catalog} maps={maps} queue={queue} onProfile={setProfile} />
      )}
    </div>
  );
}
