import { CharacterCreator } from './components/creator/CharacterCreator';
import { DeathScreen } from './components/hud/DeathScreen';
import { Hud } from './components/hud/Hud';
import { Toasts } from './components/hud/Toasts';
import { Menu } from './components/menu/Menu';
import { isEnvBrowser } from './api/nui';
import { useCreator } from './store/CreatorProvider';
import { useGame } from './store/GameContext';
import './components/hud/hud.css';

export function App() {
  const { state } = useGame();
  const creator = useCreator();
  const creating = creator.state?.open ?? false;

  return (
    <div className={isEnvBrowser() ? 'app app--browser' : 'app'}>
      {creating && <CharacterCreator />}
      {!creating && state.ready && !state.menu.open && !state.death.active && <Hud />}
      {!creating && state.menu.open && <Menu />}
      {!creating && state.death.active && <DeathScreen />}
      <Toasts />
    </div>
  );
}
