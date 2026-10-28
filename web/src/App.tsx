import { ActivityPanel } from './components/activity/ActivityPanel';
import { Chase } from './components/activity/Chase';
import { Cvc } from './components/activity/Cvc';
import { AdminPanel } from './components/admin/AdminPanel';
import { NoclipHelp } from './components/admin/NoclipHelp';
import { Chat } from './components/chat/Chat';
import { CharacterCreator } from './components/creator/CharacterCreator';
import { DeathScreen } from './components/hud/DeathScreen';
import { EffectsBar } from './components/hud/EffectsBar';
import { HitFeedback } from './components/hud/HitFeedback';
import { HelpNotification } from './components/hud/HelpNotification';
import { InteractionMenu } from './components/interaction/InteractionMenu';
import { Hud } from './components/hud/Hud';
import { Speedometer } from './components/hud/Speedometer';
import { Toasts } from './components/hud/Toasts';
import { Lobby } from './components/lobby/Lobby';
import { Menu } from './components/menu/Menu';
import { PauseMenu } from './components/pause/PauseMenu';
import { Teleport } from './components/teleport/TeleportMenu';
import { FreeroamHud } from './components/freeroam/FreeroamHud';
import { FreeroamMenu } from './components/freeroam/FreeroamMenu';
import { isEnvBrowser } from './api/nui';
import { DevPanel } from './dev/DevPanel';
import { useCreator } from './store/CreatorProvider';
import { useGame } from './store/GameContext';
import './components/hud/hud.css';

export function App() {
  const { state } = useGame();
  const creator = useCreator();
  const creating = creator.state?.open ?? false;
  const inLobby = state.lobby.open;
  // Le HUD, le menu et l'écran de mort appartiennent au mode PvP
  const inPvp = !creating && !inLobby && state.mode === 'pvp';
  const inFreeroam = !creating && !inLobby && state.mode === 'freeroam';

  return (
    <div className={isEnvBrowser() ? 'app app--browser' : 'app'}>
      {creating && <CharacterCreator />}
      {!creating && inLobby && <Lobby />}
      {inPvp && state.ready && !state.menu.open && !state.death.active && <Hud />}
      {!creating && !inLobby && state.mode && <HitFeedback />}
      {/* Monté hors du HUD : les effets survivent à l'ouverture du menu (masqués pendant ce temps) */}
      {inPvp && <EffectsBar hidden={!state.ready || state.menu.open || state.death.active} />}
      {inPvp && state.menu.open && <Menu />}
      {inPvp && state.death.active && <DeathScreen />}
      {inFreeroam && !state.freeroam.menuOpen && <FreeroamHud />}
      {inFreeroam && state.freeroam.menuOpen && <FreeroamMenu />}
      {(inPvp || inFreeroam) && !state.menu.open && !state.freeroam.menuOpen && !state.death.active && <Speedometer />}
      {inFreeroam && <ActivityPanel />}
      {inFreeroam && <Chase />}
      {inFreeroam && <Cvc />}
      {(inPvp || inFreeroam) && !state.menu.open && !state.freeroam.menuOpen && <Chat />}
      {!creating && !inLobby && state.admin.open && <AdminPanel />}
      {!creating && !inLobby && state.noclip.active && !state.admin.open && !state.menu.open && <NoclipHelp />}
      {inPvp && state.interaction.open && !state.menu.open && <InteractionMenu />}
      {inPvp && !state.death.active && <Teleport />}
      {!creating && !inLobby && state.pause.open && <PauseMenu />}
      {!creating && !inLobby && !state.menu.open && !state.pause.open && <HelpNotification />}
      <Toasts />
      {isEnvBrowser() && <DevPanel />}
    </div>
  );
}
