import { useGame } from '../../store/GameContext';
import { SegmentBar } from '../ui/SegmentBar';

/** Coéquipiers du groupe et leur vie, à gauche de l'écran. */
export function SquadPanel() {
  const { state } = useGame();
  const { group, groupVitals, player } = state;
  if (!group || !player) return null;

  const mates = group.members.filter((member) => member.id !== player.source);
  if (mates.length === 0) return null;

  return (
    <div className="squad">
      <span className="label squad__title">Groupe</span>
      {mates.map((mate) => {
        const vital = groupVitals.find((v) => v.id === mate.id);
        const inRange = vital !== undefined && vital.health !== false;
        const down = inRange && vital.health === 0;
        return (
          <div key={mate.id} className={down ? 'squad__mate squad__mate--down' : 'squad__mate'}>
            <span className="squad__name">
              {mate.name}
              {mate.id === group.leader && <span className="mono squad__chief">★</span>}
            </span>
            {inRange ? (
              <>
                <SegmentBar value={vital.health as number} max={100} segments={10} height={3} />
                {vital.armor > 0 && (
                  <SegmentBar value={vital.armor} max={100} segments={10} height={2} color="var(--armure)" />
                )}
              </>
            ) : (
              <span className="mono squad__far">HORS DE PORTÉE</span>
            )}
          </div>
        );
      })}
    </div>
  );
}
