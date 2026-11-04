import { t } from '../../i18n';
import type { TacCatalog, TacLineup, TacLineupPlayer, TacTeam } from '../../types/tactical';
import { RoleIcon } from './tacticalIcons';
import { DivisionChip, findRole } from './tacticalParts';

/** Présentation des deux équipes pendant le chargement : la carte au centre, chaque équipe d'un côté. */
export function TacticalLineup({ lineup, catalog, team, self }: { lineup: TacLineup; catalog: TacCatalog; team: TacTeam; self: number }) {
  const enemy: TacTeam = team === 'alpha' ? 'bravo' : 'alpha';
  const sideOf = (side: TacTeam) => (side === lineup.attackers ? t('Attaque') : t('Défense'));
  return (
    <div className="tac-lineup">
      <div className="tac-lineup__map">
        <span className="label">{t(lineup.map.place)}</span>
        <h1 className="disp">{t(lineup.map.label)}</h1>
        <span className="label tac-lineup__mode">{t('Sabotage')} · {t('Classée')}</span>
      </div>

      <LineupColumn
        title={`${t('Ton équipe')} · ${sideOf(team)}`}
        side="friend"
        players={lineup.players.filter((player) => player.team === team)}
        catalog={catalog}
        self={self}
      />
      <div className="tac-lineup__versus disp"><span>VS</span></div>
      <LineupColumn
        title={`${t('Adversaires')} · ${sideOf(enemy)}`}
        side="enemy"
        players={lineup.players.filter((player) => player.team === enemy)}
        catalog={catalog}
        self={self}
      />
    </div>
  );
}

function LineupColumn({ title, side, players, catalog, self }: {
  title: string;
  side: 'friend' | 'enemy';
  players: TacLineupPlayer[];
  catalog: TacCatalog;
  self: number;
}) {
  return (
    <section className={`tac-lineup__team tac-lineup__team--${side}`}>
      <h2 className="label tac-lineup__title">{title}</h2>
      {players.map((player, index) => {
        const role = findRole(catalog, player.role);
        return (
          <div
            key={player.id}
            className={`tac-lineup__row tac-role--${role?.id ?? 'none'} ${player.id === self ? 'tac-lineup__row--me' : ''}`}
            style={{ animationDelay: `${index * 0.08}s` }}
          >
            <div className="tac-lineup__portrait">
              <RoleIcon id={role?.id} className="tac-lineup__icon" />
              <span className="tac-lineup__name">{player.name}</span>
            </div>
            <div className="tac-lineup__strip">
              <span className="disp tac-lineup__role">{t(role?.label ?? '')}</span>
              <DivisionChip catalog={catalog} division={player.division} rating={player.rating} />
            </div>
          </div>
        );
      })}
    </section>
  );
}
