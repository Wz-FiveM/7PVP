import { ActivityPanel } from './components/activity/ActivityPanel';
import { Chase } from './components/activity/Chase';
import { Cvc } from './components/activity/Cvc';
import { Gunfight } from './components/activity/Gunfight';
import { Gungame } from './components/activity/Gungame';
import { Cod } from './components/cod/Cod';
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
import { activityApi } from './api/activityApi';
import { isEnvBrowser } from './api/nui';
import { teleportApi } from './api/teleportApi';
import { UiGuard } from './components/ui/UiGuard';
import { DevPanel } from './dev/DevPanel';
import { useCreator } from './store/CreatorProvider';
import { useGame } from './store/GameContext';
import './components/hud/hud.css';

export function App() {
  const { state, actions } = useGame();
  const creator = useCreator();
  const creating = creator.state?.open ?? false;
  const inLobby = state.lobby.open;
  // Le HUD, le menu et l'écran de mort appartiennent au mode PvP
  const inPvp = !creating && !inLobby && state.mode === 'pvp';
  const inFreeroam = !creating && !inLobby && state.mode === 'freeroam';
  const inCod = !creating && !inLobby && state.mode === 'cod';

  return (
    <div className={isEnvBrowser() ? 'app app--browser' : 'app'}>
      {/* Chaque partie est isolée (UiGuard) : si l'une plante, le reste de l'interface continue */}
      {creating && <UiGuard name="creator"><CharacterCreator /></UiGuard>}
      {!creating && inLobby && <UiGuard name="lobby"><Lobby /></UiGuard>}
      {inPvp && state.ready && !state.menu.open && !state.death.active && <UiGuard name="hud"><Hud /></UiGuard>}
      {!creating && !inLobby && state.mode && <UiGuard name="hits"><HitFeedback /></UiGuard>}
      {/* Monté hors du HUD : les effets survivent à l'ouverture du menu (masqués pendant ce temps) */}
      {inPvp && (
        <UiGuard name="effects">
          <EffectsBar hidden={!state.ready || state.menu.open || state.death.active} />
        </UiGuard>
      )}
      {inPvp && state.menu.open && <UiGuard name="menu" onCrash={actions.closeMenu}><Menu /></UiGuard>}
      {inPvp && state.death.active && <UiGuard name="death"><DeathScreen /></UiGuard>}
      {inFreeroam && !state.freeroam.menuOpen && <UiGuard name="freeroam-hud"><FreeroamHud /></UiGuard>}
      {inFreeroam && state.freeroam.menuOpen && (
        <UiGuard name="freeroam-menu" onCrash={actions.closeFreeroam}>
          <FreeroamMenu />
        </UiGuard>
      )}
      {(inPvp || inFreeroam) && !state.menu.open && !state.freeroam.menuOpen && !state.death.active && (
        <UiGuard name="speedometer"><Speedometer /></UiGuard>
      )}
      {inFreeroam && <UiGuard name="activity" onCrash={activityApi.close}><ActivityPanel /></UiGuard>}
      {inFreeroam && <UiGuard name="chase"><Chase /></UiGuard>}
      {inFreeroam && <UiGuard name="cvc"><Cvc /></UiGuard>}
      {inFreeroam && <UiGuard name="gunfight"><Gunfight /></UiGuard>}
      {inFreeroam && <UiGuard name="gungame"><Gungame /></UiGuard>}
      {/* Toujours monté : le serveur peut ouvrir le menu juste après le changement de mode */}
      <UiGuard name="cod"><Cod visible={inCod} /></UiGuard>
      {(inPvp || inFreeroam || inCod) && !state.menu.open && !state.freeroam.menuOpen && (
        <UiGuard name="chat" onCrash={actions.closeChat}><Chat /></UiGuard>
      )}
      {!creating && !inLobby && state.admin.open && <UiGuard name="admin" onCrash={actions.closeAdmin}><AdminPanel /></UiGuard>}
      {!creating && !inLobby && state.noclip.active && !state.admin.open && !state.menu.open && (
        <UiGuard name="noclip"><NoclipHelp /></UiGuard>
      )}
      {inPvp && state.interaction.open && !state.menu.open && (
        <UiGuard name="interaction" onCrash={actions.closeInteraction}><InteractionMenu /></UiGuard>
      )}
      {inPvp && !state.death.active && <UiGuard name="teleport" onCrash={teleportApi.close}><Teleport /></UiGuard>}
      {/* En Call of Duty, le mode a son propre menu pause (voir Cod) */}
      {!creating && !inLobby && state.pause.open && state.pause.info?.mode !== 'cod' && (
        <UiGuard name="pause" onCrash={actions.closePause}><PauseMenu /></UiGuard>
      )}
      {!creating && !inLobby && !state.menu.open && !state.pause.open && <UiGuard name="help"><HelpNotification /></UiGuard>}
      <UiGuard name="toasts"><Toasts /></UiGuard>
      {isEnvBrowser() && <DevPanel />}
    </div>
  );
}
