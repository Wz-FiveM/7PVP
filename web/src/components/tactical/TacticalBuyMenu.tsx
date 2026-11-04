import { useMemo, useState } from 'react';
import { tacticalApi } from '../../api/tacticalApi';
import { useCountdown } from '../../hooks/useCountdown';
import { t } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { TacArmor, TacCatalog, TacSelf, TacSlot, TacState, TacWeapon } from '../../types/tactical';
import { AbilityIcon } from './tacticalIcons';
import { RoleBadge, SLOTS, WeaponImage, findRole, money, slotKey, weaponLabel } from './tacticalParts';

interface TacticalBuyMenuProps {
  catalog: TacCatalog;
  self: TacSelf;
  live: (TacState & { at: number }) | null;
  name: string;
}

/** Colonnes de l'arsenal : les catégories s'empilent sans être coupées */
const COLUMNS = 4;

type Section = { kind: 'weapons'; name: string; weapons: TacWeapon[] } | { kind: 'armor'; name: string; armor: TacArmor[] };

/** Menu d'achat (touche B pendant la phase d'achat). Un achat de la manche se revend en cliquant à nouveau. */
export function TacticalBuyMenu({ catalog, self, live, name }: TacticalBuyMenuProps) {
  const { actions } = useGame();
  const [pending, setPending] = useState<string | null>(null);
  const [focus, setFocus] = useState<string | null>(null);
  const remaining = useCountdown(live?.phase === 'buy' ? live.remaining : 0, live?.at);
  const role = findRole(catalog, self.role);

  const columns = useMemo(() => {
    const sections: Section[] = [];
    for (const weapon of catalog.weapons) {
      let section = sections.find((entry) => entry.kind === 'weapons' && entry.name === weapon.category);
      if (!section) {
        section = { kind: 'weapons', name: weapon.category, weapons: [] };
        sections.push(section);
      }
      if (section.kind === 'weapons') section.weapons.push(weapon);
    }
    sections.push({ kind: 'armor', name: 'Gilets', armor: catalog.armor });
    const size = (section: Section) => (section.kind === 'weapons' ? section.weapons.length : section.armor.length);
    const capacity = Math.ceil(sections.reduce((total, section) => total + size(section), 0) / COLUMNS);
    const result: Section[][] = [[]];
    let filled = 0;
    for (const section of sections) {
      if (filled > 0 && filled + size(section) > capacity && result.length < COLUMNS) {
        result.push([]);
        filled = 0;
      }
      result[result.length - 1].push(section);
      filled += size(section);
    }
    return result;
  }, [catalog.weapons, catalog.armor]);

  const run = async (key: string, request: () => Promise<{ ok: boolean; message?: string } | undefined>) => {
    if (pending) return;
    setPending(key);
    const result = await request();
    setPending(null);
    if (result && !result.ok && result.message) actions.notify(result.message, 'error');
  };

  const buyWeapon = (weapon: TacWeapon) => {
    const owned = self.loadout[weapon.slot] === weapon.id;
    if (owned && self.bought.includes(weapon.slot)) return run(weapon.id, () => tacticalApi.sell(weapon.slot));
    if (owned) return;
    return run(weapon.id, () => tacticalApi.buy(weapon.id));
  };

  const focused = catalog.weapons.find((weapon) => weapon.id === focus)
    ?? catalog.weapons.find((weapon) => weapon.id === self.loadout.primary)
    ?? catalog.weapons.find((weapon) => weapon.id === self.loadout.secondary);

  return (
    <div className="tac-buy">
      <div className="tac-buy__panel">
        <header className="tac-buy__head">
          <div>
            <span className="label">{t('Phase d\'achat')}</span>
            <h2 className="disp tac-buy__title">{t('Arsenal')}</h2>
          </div>
          <div className="tac-buy__timer">
            <span className="label">{t('Fin de l\'achat')}</span>
            <span className="disp mono">{remaining}s</span>
          </div>
        </header>

        <div className="tac-buy__body">
          <aside className="tac-buy__team">
            <span className="label tac-buy__category">{t('Équipe')}</span>
            <div className="tac-buy__mate tac-buy__mate--me">
              <RoleBadge role={role} size="m" />
              <div className="tac-buy__mate-text">
                <span className="tac-buy__mate-name">{name}</span>
                <span className="disp tac-buy__mate-money">{money(self.money)}</span>
              </div>
            </div>
            {(self.mates ?? []).map((mate) => (
              <div key={mate.id} className={`tac-buy__mate ${mate.alive ? '' : 'tac-buy__mate--dead'}`}>
                <RoleBadge role={findRole(catalog, mate.role)} size="s" />
                <div className="tac-buy__mate-text">
                  <span className="tac-buy__mate-name">{mate.name}</span>
                  <span className="mono tac-buy__mate-cash">{money(mate.money)}</span>
                </div>
                {mate.primary ? (
                  <WeaponImage id={mate.primary} className="tac-buy__mate-weapon" />
                ) : (
                  <span className="tac-buy__mate-none">{t('Pistolet')}</span>
                )}
              </div>
            ))}
          </aside>

          <div className="tac-buy__arsenal">
            <div className="tac-buy__columns" style={{ gridTemplateColumns: `repeat(${columns.length}, minmax(0, 1fr))` }}>
              {columns.map((column, index) => (
                <div key={index} className="tac-buy__column">
                  {column.map((section) => (
                    <section key={section.name} className="tac-buy__section">
                      <h3 className="label tac-buy__category">{t(section.name)}</h3>
                      {section.kind === 'weapons'
                        ? section.weapons.map((weapon) => {
                          const owned = self.loadout[weapon.slot] === weapon.id;
                          const sellable = owned && self.bought.includes(weapon.slot);
                          const affordable = self.money >= weapon.price;
                          return (
                            <button
                              key={weapon.id}
                              className={`tac-item ${owned ? 'tac-item--owned' : ''} ${!owned && !affordable ? 'tac-item--locked' : ''}`}
                              disabled={pending !== null || (!owned && !affordable) || (owned && !sellable)}
                              onClick={() => void buyWeapon(weapon)}
                              onMouseEnter={() => setFocus(weapon.id)}
                            >
                              <span className="mono tac-item__price">
                                {sellable ? t('Revendre') : owned ? t('Équipée') : weapon.price === 0 ? t('Gratuit') : money(weapon.price)}
                              </span>
                              <WeaponImage id={weapon.id} className="tac-item__image" />
                              <span className="tac-item__name">{t(weapon.label)}</span>
                            </button>
                          );
                        })
                        : section.armor.map((armor) => {
                          const owned = self.loadout.armor >= armor.value;
                          const sellable = owned && self.bought.includes('armor') && self.loadout.armor === armor.value;
                          const affordable = self.money >= armor.price;
                          return (
                            <button
                              key={armor.id}
                              className={`tac-item tac-item--armor ${owned ? 'tac-item--owned' : ''} ${!owned && !affordable ? 'tac-item--locked' : ''}`}
                              disabled={pending !== null || (!owned && !affordable) || (owned && !sellable)}
                              onClick={() => void run(armor.id, () => (sellable ? tacticalApi.sell('armor') : tacticalApi.buy(`armor:${armor.id}`)))}
                            >
                              <span className="mono tac-item__price">{sellable ? t('Revendre') : owned ? t('Équipé') : money(armor.price)}</span>
                              <span className="tac-item__armor disp">+{armor.value}</span>
                              <span className="tac-item__name">{t(armor.label)}</span>
                            </button>
                          );
                        })}
                    </section>
                  ))}
                </div>
              ))}
            </div>

            <section className="tac-buy__abilities">
              <h3 className="label tac-buy__category">{t('Capacités')}</h3>
              <div className="tac-buy__ability-row">
                {role && SLOTS.map((slot) => (
                  <AbilityTile key={slot} catalog={catalog} self={self} slot={slot} roleId={role.id} pending={pending !== null} onRun={run} />
                ))}
              </div>
            </section>
          </div>

          <aside className="tac-buy__detail">
            {focused && (
              <>
                <span className="label">{t(focused.category)}</span>
                <h3 className="disp tac-buy__detail-name">{t(focused.label)}</h3>
                <WeaponImage id={focused.id} className="tac-buy__detail-image" />
                <dl className="tac-buy__facts">
                  <dt>{t('Emplacement')}</dt>
                  <dd>{focused.slot === 'primary' ? t('Arme principale') : t('Arme de poing')}</dd>
                  <dt>{t('Munitions')}</dt>
                  <dd className="mono">{focused.ammo}</dd>
                  <dt>{t('Prix')}</dt>
                  <dd className="mono">{focused.price === 0 ? t('Gratuit') : money(focused.price)}</dd>
                </dl>
              </>
            )}
            <div className="tac-buy__loadout">
              <span className="label">{t('Équipement')}</span>
              <span>{weaponLabel(catalog, self.loadout.primary) ?? t('Sans arme principale')}</span>
              <span>{weaponLabel(catalog, self.loadout.secondary) ?? t('Couteau')}</span>
              <span>{self.loadout.armor > 0 ? `${t('Gilet')} +${self.loadout.armor}` : t('Sans gilet')}</span>
            </div>
          </aside>
        </div>

        <footer className="tac-buy__foot muted">
          {t('Clique sur un achat de cette manche pour le revendre. {key} ou Échap pour fermer.', { key: catalog.keys.buy })}
        </footer>
      </div>
    </div>
  );
}

interface AbilityTileProps {
  catalog: TacCatalog;
  self: TacSelf;
  slot: TacSlot;
  roleId: string;
  pending: boolean;
  onRun: (key: string, request: () => Promise<{ ok: boolean; message?: string } | undefined>) => Promise<void>;
}

function AbilityTile({ catalog, self, slot, roleId, pending, onRun }: AbilityTileProps) {
  const role = findRole(catalog, roleId);
  if (!role) return null;
  const ability = role.abilities[slot];
  const ult = slot === 'x';
  const key = `ability:${slot}`;
  const charges = ult ? self.ult : self.charges[slot as 'c' | 'q'] ?? 0;
  const max = ult ? self.ultCost : ability.max ?? 1;
  const full = charges >= max;

  return (
    <div className={`tac-ability-tile ${ult ? 'tac-ability-tile--ult' : ''} ${charges > 0 ? 'tac-ability-tile--charged' : ''}`}>
      <span className="keycap">{slotKey(catalog, slot)}</span>
      <AbilityIcon id={ability.id} className="tac-ability-tile__icon" />
      <div className="tac-ability-tile__text">
        <strong>{t(ability.label)}</strong>
        <span className="tac-charges">
          {Array.from({ length: max }, (_, index) => (
            <span key={index} className={`tac-charges__pip ${ult ? 'tac-charges__pip--ult' : ''} ${index < charges ? 'tac-charges__pip--on' : ''}`} />
          ))}
        </span>
      </div>
      <span className="tac-ability-tile__actions">
        {ult ? (
          <span className="mono tac-ability-tile__note">{t('Ultime')}</span>
        ) : !ability.price ? (
          <span className="mono tac-ability-tile__note">{t('Offerte')}</span>
        ) : (
          <>
            {self.bought.includes(key) && (
              <button className="btn btn--small" disabled={pending} onClick={() => void onRun(key, () => tacticalApi.sell(key))}>−</button>
            )}
            <button className="btn btn--small btn--primary" disabled={pending || full || self.money < ability.price} onClick={() => void onRun(key, () => tacticalApi.buy(key))}>
              {full ? t('Plein') : money(ability.price)}
            </button>
          </>
        )}
      </span>
    </div>
  );
}
