import { AmmoCounter } from './AmmoCounter';
import { BountyList } from './BountyList';
import { CombatTag } from './CombatTag';
import { ControlZoneBar } from './ControlZoneBar';
import { HordeBanner } from './HordeBanner';
import { HotbarHud } from './HotbarHud';
import { Killfeed } from './Killfeed';
import { SquadPanel } from './SquadPanel';
import { StatusPanel } from './StatusPanel';
import { Vitals } from './Vitals';
import { ZoneBanner } from './ZoneBanner';
import './hud.css';

/** Interface affichée en jeu, menu fermé. */
export function Hud() {
  return (
    <div className="hud">
      <ZoneBanner />
      <div className="hud__top-center">
        <HordeBanner />
        <ControlZoneBar />
        <CombatTag />
      </div>
      <SquadPanel />
      <div className="hud__top-right">
        <StatusPanel />
        <Killfeed />
        <BountyList />
      </div>
      <Vitals />
      <HotbarHud />
      <AmmoCounter />
    </div>
  );
}
