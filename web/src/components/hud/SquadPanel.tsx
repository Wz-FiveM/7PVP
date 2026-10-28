import { useLayoutEffect, useRef } from 'react';
import { useGame } from '../../store/GameContext';
import type { GroupVital } from '../../types/game';
import { Icon } from '../icons/Icon';
import { Avatar } from '../ui/Avatar';

/** Une barre fine pleine (vie ou armure), de 0 à 100. */
function Bar({ value, kind }: { value: number; kind: 'health' | 'armor' }) {
  return (
    <span className={`team-card__bar team-card__bar--${kind}`}>
      <span style={{ width: `${Math.max(0, Math.min(100, value))}%` }} />
    </span>
  );
}

/** Équipe (gauche de l'écran) : une carte par membre, avec sa vie et son armure. */
export function SquadPanel() {
  const { state } = useGame();
  const { group, groupVitals, player } = state;
  const ref = useRef<HTMLDivElement>(null);
  const shown = Boolean(group && player && group.members.length >= 2);

  // Publie le bas du panneau pour que le chat se place dessous au lieu de le recouvrir
  useLayoutEffect(() => {
    const el = ref.current;
    if (!shown || !el) return;
    const root = document.documentElement;
    const publish = () => root.style.setProperty('--squad-bottom', `${el.getBoundingClientRect().bottom}px`);
    publish();
    const observer = new ResizeObserver(publish);
    observer.observe(el);
    window.addEventListener('resize', publish);
    return () => {
      observer.disconnect();
      window.removeEventListener('resize', publish);
      root.style.removeProperty('--squad-bottom');
    };
  }, [shown]);

  if (!group || !player || !shown) return null;

  const vitalOf = (id: number): GroupVital | undefined => groupVitals.find((v) => v.id === id);
  // Le joueur local d'abord, puis les coéquipiers dans l'ordre d'arrivée
  const members = [...group.members].sort((a, b) => Number(b.id === player.source) - Number(a.id === player.source));

  return (
    <div ref={ref} className="team">
      {members.map((member) => {
        const vital = vitalOf(member.id);
        const health = vital && vital.health !== false ? vital.health : 0;
        const down = Boolean(vital?.dead) || (vital !== undefined && health === 0);
        const isLeader = member.id === group.leader;
        const isMe = member.id === player.source;
        return (
          <div key={member.id} className={down ? 'team-card team-card--down cut-s' : 'team-card cut-s'}>
            <span className="team-card__avatar cut-s">
              <Avatar
                src={member.avatar}
                fallback={isLeader ? <Icon name="trophy" size={18} strokeWidth={2.2} /> : <span className="disp">?</span>}
              />
              {isLeader && member.avatar && (
                <span className="team-card__leader">
                  <Icon name="trophy" size={10} strokeWidth={2.6} />
                </span>
              )}
            </span>
            <span className="team-card__body">
              <span className={isMe ? 'team-card__name team-card__name--me' : 'team-card__name'}>
                {member.name}
                {down && <span className="mono team-card__state">À TERRE</span>}
              </span>
              <Bar value={health} kind="health" />
              <Bar value={vital?.armor ?? 0} kind="armor" />
            </span>
          </div>
        );
      })}
    </div>
  );
}
