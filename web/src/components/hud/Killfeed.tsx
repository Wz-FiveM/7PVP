import { useGame } from '../../store/GameContext';
import { Icon } from '../icons/Icon';

export function Killfeed() {
  const { state } = useGame();

  return (
    <div className="killfeed">
      {state.killfeed.map((item) => (
        <div key={item.id} className="killfeed__item cut-s">
          {item.killer ? (
            <>
              <span className="killfeed__killer">{item.killer}</span>
              <Icon name="crosshair" size={14} strokeWidth={2} />
              <span>{item.victim}</span>
              {item.reason === 'disconnect' && <span className="mono killfeed__reason">DÉCO</span>}
            </>
          ) : (
            <>
              <Icon name="crosshair" size={14} strokeWidth={2} />
              <span>{item.victim}</span>
              <span className={item.reason === 'disconnect' ? 'mono killfeed__reason' : 'mono muted'}>
                {item.reason === 'disconnect' ? 'DÉCO EN COMBAT' : 'MORT'}
              </span>
            </>
          )}
        </div>
      ))}
    </div>
  );
}
