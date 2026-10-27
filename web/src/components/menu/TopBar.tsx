import { PAGES, type PageId } from '../../pages';
import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';
import { Logo } from '../ui/Logo';
import { ZoneChip } from '../ui/ZoneChip';

interface TopBarProps {
  active: PageId;
  onSelect: (page: PageId) => void;
}

export function TopBar({ active, onSelect }: TopBarProps) {
  const { state, actions } = useGame();
  const { player, zone, config } = state;
  const progress = player ? ((player.xp % config.xpPerLevel) / config.xpPerLevel) * 100 : 0;

  return (
    <header className="topbar">
      <Logo />
      <nav className="topbar__tabs">
        {PAGES.map((page) => (
          <button
            key={page.id}
            className={page.id === active ? 'topbar__tab topbar__tab--active disp' : 'topbar__tab disp'}
            onClick={() => onSelect(page.id)}
          >
            {page.label}
          </button>
        ))}
      </nav>
      <div className="topbar__status">
        <ZoneChip zone={zone} detailed />
        {player && (
          <>
            <span className="mono topbar__money">{formatMoney(player.money)}</span>
            <span className="topbar__level">
              <span className="disp">Niv. {player.level}</span>
              <span className="topbar__xp">
                <span style={{ width: `${progress}%` }} />
              </span>
            </span>
          </>
        )}
        <button className="btn btn--small mono" onClick={actions.closeMenu} aria-label="Fermer le menu">
          [ÉCHAP]
        </button>
      </div>
    </header>
  );
}
