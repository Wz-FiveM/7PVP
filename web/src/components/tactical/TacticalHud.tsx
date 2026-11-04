import { useEffect, useState } from 'react';
import { useCountdown } from '../../hooks/useCountdown';
import { t } from '../../i18n';
import type { TacBoardRow, TacCatalog, TacDead, TacHud, TacRound, TacRoundEnd, TacSelf, TacState, TacTeam } from '../../types/tactical';
import type { TacKillEntry, TacNoticeEntry } from './Tactical';
import { AbilityIcon, RoleIcon } from './tacticalIcons';
import { RoleBadge, SLOTS, findRole, money, slotKey, weaponLabel } from './tacticalParts';

interface TacticalHudProps {
  hud: TacHud;
  catalog: TacCatalog;
  round: (TacRound & { at: number }) | null;
  self: TacSelf | null;
  live: (TacState & { at: number }) | null;
  kills: TacKillEntry[];
  notices: TacNoticeEntry[];
  dead: TacDead | null;
  roundEnd: TacRoundEnd | null;
  action: { kind: string; seconds: number; at: number } | null;
  scoreboard: boolean;
  outside: boolean;
  /** menu d'achat ouvert : seul le haut de l'écran reste */
  hidden: boolean;
}

const other = (team: TacTeam): TacTeam => (team === 'alpha' ? 'bravo' : 'alpha');

/** HUD de partie : score et temps, joueurs en vie, capacités, argent, fil des kills, annonces. */
export function TacticalHud(props: TacticalHudProps) {
  const { hud, catalog, round, self, live, kills, notices, dead, roundEnd, action, scoreboard, outside, hidden } = props;
  const mine = hud.team;
  const enemy = other(mine);
  const scores = live?.scores ?? round?.scores ?? { alpha: 0, bravo: 0 };
  const attackers = live?.attackers ?? round?.attackers ?? 'alpha';
  const remaining = useCountdown(live?.remaining ?? round?.buyTime ?? 0, live?.at ?? round?.at);
  const phase = live?.phase ?? 'loading';
  const board = live?.board ?? [];
  const role = findRole(catalog, self?.role ?? hud.role);

  return (
    <div className="tac-hud">
      <TopBar
        mine={mine}
        enemy={enemy}
        scores={scores}
        attacking={attackers === mine}
        remaining={remaining}
        phase={phase}
        bomb={live?.bomb ? live.bomb.site : null}
        round={live?.round ?? round?.round ?? 0}
        board={board}
        roundsToWin={hud.roundsToWin}
        catalog={catalog}
      />

      {phase === 'loading' && (
        <div className="tac-banner">
          <span className="label">{t(hud.map.place)}</span>
          <strong className="disp">{t(hud.map.label)}</strong>
          <span>{t('Rôle : {role}', { role: t(role?.label ?? '') })}</span>
        </div>
      )}

      {phase === 'buy' && !hidden && round && (
        <div className="tac-phase">
          <span className={`tac-phase__side ${round.attacking ? 'tac-phase__side--attack' : 'tac-phase__side--defend'}`}>
            {round.attacking ? t('Attaque : pose la charge sur un site') : t('Défense : protège les sites')}
          </span>
          <span className="tac-phase__hint">
            <span className="keycap">{catalog.keys.buy}</span> {t('Acheter')}
            {round.overtime && <span className="tac-phase__overtime">{t('Manche décisive')}</span>}
          </span>
        </div>
      )}

      <div className="tac-killfeed">
        {kills.map((kill) => (
          <div key={kill.key} className="tac-kill">
            {kill.killer && <span className={kill.killerTeam === mine ? 'tac-friend' : 'tac-enemy'}>{kill.killer}</span>}
            <span className="tac-kill__weapon">{kill.weapon ? t(kill.weapon) : '✕'}{kill.headshot ? ' ◎' : ''}</span>
            <span className={kill.victimTeam === mine ? 'tac-friend' : 'tac-enemy'}>{kill.victim}</span>
          </div>
        ))}
      </div>

      <div className="tac-notices">
        {notices.map((notice) => (
          <div
            key={notice.key}
            className={`tac-notice ${notice.big ? 'tac-notice--big' : ''} ${notice.danger ? 'tac-notice--danger' : ''} ${
              notice.team ? (notice.team === mine ? 'tac-notice--friend' : 'tac-notice--enemy') : ''
            }`}
          >
            {t(notice.text)}
          </div>
        ))}
      </div>

      {action && <ActionBar action={action} />}
      {outside && <div className="tac-outside">{t('Hors de la zone de jeu : reviens vite')}</div>}

      {roundEnd && (
        <div className={`tac-round-end tac-round-end--${roundEnd.result}`}>
          <strong className="disp">{roundEnd.result === 'won' ? t('Manche gagnée') : t('Manche perdue')}</strong>
          <span>{t(roundEnd.reason)}</span>
        </div>
      )}

      {dead && !roundEnd && <CombatReport dead={dead} catalog={catalog} />}

      {!hidden && self && (
        <div className="tac-bottom">
          <div className="tac-abilities">
            <RoleBadge role={role} size="m" />
            {role && SLOTS.map((slot) => {
              const ability = role.abilities[slot];
              const ult = slot === 'x';
              const charges = ult ? 0 : self.charges[slot] ?? 0;
              const ready = ult ? self.ult >= self.ultCost : charges > 0;
              return (
                <div key={slot} className={`tac-ability ${ready ? 'tac-ability--ready' : ''} ${ult ? 'tac-ability--ult' : ''}`}>
                  <AbilityIcon id={ability.id} className="tac-ability__icon" />
                  <span className="tac-ability__name">{t(ability.label)}</span>
                  <span className="keycap tac-ability__key">{slotKey(catalog, slot)}</span>
                  {ult ? (
                    <span className="tac-charges">
                      {Array.from({ length: self.ultCost }, (_, index) => (
                        <span key={index} className={`tac-charges__pip tac-charges__pip--ult ${index < self.ult ? 'tac-charges__pip--on' : ''}`} />
                      ))}
                    </span>
                  ) : (
                    <span className="mono tac-ability__count">{charges}</span>
                  )}
                </div>
              );
            })}
          </div>
          <div className="tac-wallet">
            <span className="disp tac-wallet__money">{money(self.money)}</span>
            <span className="tac-wallet__gear">
              {[weaponLabel(catalog, self.loadout.primary), weaponLabel(catalog, self.loadout.secondary)].filter(Boolean).join(' · ') || t('Couteau')}
              {self.loadout.armor > 0 && ` · ${t('Gilet')} ${self.loadout.armor}`}
            </span>
          </div>
        </div>
      )}

      {scoreboard && <Scoreboard board={board} mine={mine} self={hud.self} catalog={catalog} scores={scores} />}
    </div>
  );
}

function TopBar(props: {
  mine: TacTeam;
  enemy: TacTeam;
  scores: Record<TacTeam, number>;
  attacking: boolean;
  remaining: number;
  phase: string;
  bomb: string | null;
  round: number;
  board: TacBoardRow[];
  roundsToWin: number;
  catalog: TacCatalog;
}) {
  const { mine, enemy, scores, attacking, remaining, phase, bomb, round, board, catalog } = props;
  const minutes = Math.floor(remaining / 60);
  const seconds = String(remaining % 60).padStart(2, '0');
  return (
    <div className="tac-top">
      <TeamRoster board={board} team={mine} side="friend" catalog={catalog} />
      <div className="tac-top__score tac-friend">
        <span className="disp">{scores[mine]}</span>
        <span className="label">{attacking ? t('Attaque') : t('Défense')}</span>
      </div>
      <div className={`tac-top__clock ${bomb ? 'tac-top__clock--bomb' : ''}`}>
        {bomb ? (
          <>
            <span className="label">{t('Charge · site {site}', { site: bomb })}</span>
            <span className="disp mono">{remaining}</span>
          </>
        ) : (
          <>
            <span className="label">{phase === 'buy' ? t('Achat') : t('Manche {round}', { round })}</span>
            <span className="disp mono">{minutes}:{seconds}</span>
          </>
        )}
      </div>
      <div className="tac-top__score tac-enemy">
        <span className="disp">{scores[enemy]}</span>
        <span className="label">{attacking ? t('Défense') : t('Attaque')}</span>
      </div>
      <TeamRoster board={board} team={enemy} side="enemy" catalog={catalog} />
    </div>
  );
}

/** Pictogramme du rôle de chaque joueur d'une équipe, éteint quand il est mort */
function TeamRoster({ board, team, side, catalog }: { board: TacBoardRow[]; team: TacTeam; side: 'friend' | 'enemy'; catalog: TacCatalog }) {
  const members = board.filter((row) => row.team === team).sort((a, b) => a.id - b.id);
  return (
    <div className={`tac-roster tac-roster--${side}`}>
      {members.map((row) => {
        const role = findRole(catalog, row.role);
        return (
          <span key={row.id} className={`tac-roster__face tac-role--${role?.id ?? 'none'} ${row.alive ? '' : 'tac-roster__face--dead'}`}>
            <RoleIcon id={role?.id} className="tac-roster__icon" />
          </span>
        );
      })}
    </div>
  );
}

/** À la mort : qui a tué, avec quoi, et les dégâts donnés et reçus face à chaque ennemi de la manche */
function CombatReport({ dead, catalog }: { dead: TacDead; catalog: TacCatalog }) {
  const report = dead.report ?? [];
  return (
    <div className="tac-report">
      <header className="tac-report__killer">
        <span className="label">{dead.killer ? t('Éliminé par') : t('Éliminé')}</span>
        <div className="tac-report__who">
          {dead.killer && <RoleBadge role={findRole(catalog, dead.killerRole)} size="m" />}
          <strong className="disp">{dead.killer ?? t('Tu es tombé')}</strong>
          {dead.weapon && <span className="tac-report__weapon">{t(dead.weapon)}</span>}
        </div>
      </header>
      {report.length > 0 && (
        <section className="tac-report__table">
          <h3 className="label">{t('Rapport de combat')}</h3>
          <div className="tac-report__columns label">
            <span>{t('Infligés')}</span>
            <span />
            <span>{t('Reçus')}</span>
          </div>
          {report.map((row) => (
            <div key={row.id} className={`tac-report__row ${row.killer ? 'tac-report__row--killer' : ''}`}>
              <span className="tac-report__value">
                <strong className="mono">{row.dealt}</strong>
                <span className="mono muted">{t('{hits} touches', { hits: row.dealtHits })}</span>
              </span>
              <span className="tac-report__enemy">
                <RoleBadge role={findRole(catalog, row.role)} size="s" />
                {row.name}
              </span>
              <span className="tac-report__value tac-report__value--taken">
                <strong className="mono">{row.taken}</strong>
                <span className="mono muted">{t('{hits} touches', { hits: row.takenHits })}</span>
              </span>
            </div>
          ))}
        </section>
      )}
      <p className="tac-report__foot muted">{t('Tu reviens à la prochaine manche.')}</p>
    </div>
  );
}

function ActionBar({ action }: { action: { kind: string; seconds: number; at: number } }) {
  const [progress, setProgress] = useState(0);
  useEffect(() => {
    let frame = 0;
    const tick = () => {
      setProgress(Math.min(1, (Date.now() - action.at) / (action.seconds * 1000)));
      frame = window.requestAnimationFrame(tick);
    };
    tick();
    return () => window.cancelAnimationFrame(frame);
  }, [action]);
  return (
    <div className="tac-action">
      <span className="label">{action.kind === 'plant' ? t('Pose de la charge') : t('Désamorçage')}</span>
      <div className="tac-action__bar"><div style={{ width: `${progress * 100}%` }} /></div>
    </div>
  );
}

function Scoreboard({ board, mine, self, catalog, scores }: {
  board: TacBoardRow[];
  mine: TacTeam;
  self: number;
  catalog: TacCatalog;
  scores: Record<TacTeam, number>;
}) {
  const teams: TacTeam[] = [mine, other(mine)];
  return (
    <div className="tac-scoreboard">
      {teams.map((team) => (
        <section key={team} className={`tac-scoreboard__team ${team === mine ? 'tac-scoreboard__team--friend' : 'tac-scoreboard__team--enemy'}`}>
          <header>
            <span className="disp">{team === mine ? t('Ton équipe') : t('Adversaires')}</span>
            <span className="disp">{scores[team]}</span>
          </header>
          <table className="tac-table">
            <thead>
              <tr>
                <th />
                <th>{t('Joueur')}</th>
                <th>{t('Score')}</th>
                <th>K</th>
                <th>D</th>
                <th>A</th>
                <th>{t('Dégâts/manche')}</th>
                <th>{t('1ers kills')}</th>
              </tr>
            </thead>
            <tbody>
              {board.filter((row) => row.team === team).map((row) => (
                <tr key={row.id} className={`${row.id === self ? 'tac-table__me' : ''} ${row.alive ? '' : 'tac-table__dead'}`}>
                  <td><RoleBadge role={findRole(catalog, row.role)} size="s" /></td>
                  <td>{row.name}</td>
                  <td className="mono">{row.score}</td>
                  <td className="mono">{row.kills}</td>
                  <td className="mono">{row.deaths}</td>
                  <td className="mono">{row.assists}</td>
                  <td className="mono">{row.damage}</td>
                  <td className="mono">{row.firstKills}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </section>
      ))}
    </div>
  );
}
