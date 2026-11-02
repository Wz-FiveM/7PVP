import { AmmoCounter } from './AmmoCounter';
import { BountyList } from './BountyList';
import { ClassAbility } from './ClassAbility';
import { CombatTag } from './CombatTag';
import { ConflictBanner } from './ConflictBanner';
import { ControlZoneBar } from './ControlZoneBar';
import { DungeonBar, DungeonHud } from './DungeonHud';
import { HordeBanner } from './HordeBanner';
import { HotbarHud } from './HotbarHud';
import { Killfeed } from './Killfeed';
import { SquadPanel } from './SquadPanel';
import { StatusPanel } from './StatusPanel';
import { TutorialHint } from './TutorialHint';
import { Vitals } from './Vitals';
import { ZoneBanner } from './ZoneBanner';
import './hud.css';

/** Interface affichée en jeu, menu fermé. */
export function Hud() {
  return (
    <div className="hud">
      <ZoneBanner />
      <div className="hud__top-center">
        <DungeonBar />
        <HordeBanner />
        <ControlZoneBar />
        <CombatTag />
      </div>
      <SquadPanel />
      <div className="hud__top-right">
        <StatusPanel />
        <Killfeed />
        <BountyList />
        <TutorialHint />
      </div>
      <Vitals />
      <HotbarHud />
      <ConflictBanner />
      <DungeonHud />
      <AmmoCounter />
      <ClassAbility />
    </div>
  );
}
