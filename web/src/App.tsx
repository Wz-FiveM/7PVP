import { DeathScreen } from './components/hud/DeathScreen';
import { Hud } from './components/hud/Hud';
import { Toasts } from './components/hud/Toasts';
import { Menu } from './components/menu/Menu';
import { isEnvBrowser } from './api/nui';
import { useGame } from './store/GameContext';
import './components/hud/hud.css';

export function App() {
  const { state } = useGame();

  return (
    <div className={isEnvBrowser() ? 'app app--browser' : 'app'}>
      {state.ready && !state.menu.open && !state.death.active && <Hud />}
      {state.menu.open && <Menu />}
      {state.death.active && <DeathScreen />}
      <Toasts />
    </div>
  );
}
