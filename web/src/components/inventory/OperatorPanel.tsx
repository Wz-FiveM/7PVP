import { useGame } from '../../store/GameContext';
import { formatKd } from '../../utils/format';
import { Icon } from '../icons/Icon';
import { Panel } from '../ui/Panel';
import { SegmentBar } from '../ui/SegmentBar';

/** Colonne de gauche : identité, santé, armure et statistiques du joueur. */
export function OperatorPanel() {
  const { state } = useGame();
  const { player, vitals } = state;
  if (!player) return null;

  return (
    <Panel className="operator">
      <span className="label">Opérateur</span>
      <div className="operator__identity">
        <span className="disp operator__name">{player.name}</span>
        <span className="mono muted operator__xp">
          NIV. {player.level} · {player.xp.toLocaleString('fr-FR')} XP
        </span>
      </div>
      <div className="operator__preview">
        <Icon name="crosshair" size={44} strokeWidth={1.2} />
        <span className="mono">[APERÇU PERSONNAGE]</span>
      </div>
      <div className="operator__vitals">
        <div className="vital">
          <div className="vital__row">
            <span className="disp vital__label">Santé</span>
            <span className="mono">
              {vitals.health} / {vitals.maxHealth}
            </span>
          </div>
          <SegmentBar value={vitals.health} max={vitals.maxHealth} segments={10} />
        </div>
        <div className="vital">
          <div className="vital__row">
            <span className="disp vital__label">Armure</span>
            <span className="mono">{vitals.armor} / 100</span>
          </div>
          <SegmentBar value={vitals.armor} max={100} segments={10} color="var(--brume)" />
        </div>
      </div>
      <div className="operator__stats">
        <div>
          <span className="mono operator__stat">{player.kills}</span>
          <span className="label">Kills</span>
        </div>
        <div>
          <span className="mono operator__stat">{player.deaths}</span>
          <span className="label">Morts</span>
        </div>
        <div>
          <span className="mono operator__stat">{formatKd(player.kills, player.deaths)}</span>
          <span className="label">K/D</span>
        </div>
      </div>
    </Panel>
  );
}
