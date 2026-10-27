import { AdminPanel } from './components/admin/AdminPanel';
import { Chat } from './components/chat/Chat';
import { CharacterCreator } from './components/creator/CharacterCreator';
import { DeathScreen } from './components/hud/DeathScreen';
import { Hud } from './components/hud/Hud';
import { Toasts } from './components/hud/Toasts';
import { Lobby } from './components/lobby/Lobby';
import { Menu } from './components/menu/Menu';
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

  return (
    <div className={isEnvBrowser() ? 'app app--browser' : 'app'}>
      {creating && <CharacterCreator />}
      {!creating && inLobby && <Lobby />}
      {inPvp && state.ready && !state.menu.open && !state.death.active && <Hud />}
      {inPvp && state.menu.open && <Menu />}
      {inPvp && state.death.active && <DeathScreen />}
      {inPvp && !state.menu.open && <Chat />}
      {!creating && !inLobby && state.admin.open && <AdminPanel />}
      <Toasts />
      {isEnvBrowser() && <DevPanel />}
    </div>
  );
}
