import { AmmoCounter } from './AmmoCounter';
import { HotbarHud } from './HotbarHud';
import { Killfeed } from './Killfeed';
import { StatusPanel } from './StatusPanel';
import { Vitals } from './Vitals';
import { ZoneBanner } from './ZoneBanner';
import './hud.css';

/** Interface affichée en jeu, menu fermé. */
export function Hud() {
  return (
    <div className="hud">
      <ZoneBanner />
      <div className="hud__top-right">
        <StatusPanel />
        <Killfeed />
      </div>
      <Vitals />
      <HotbarHud />
      <AmmoCounter />
    </div>
  );
}
