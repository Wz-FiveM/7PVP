import { t } from '../../i18n';
import type { TacCatalog, TacRole, TacSlot } from '../../types/tactical';
import { RoleIcon } from './tacticalIcons';

export const SLOTS: TacSlot[] = ['c', 'q', 'x'];

/** Touche d'une capacité (catalogue envoyé par Lua) */
export function slotKey(catalog: TacCatalog, slot: TacSlot): string {
  if (slot === 'c') return catalog.keys.abilityC;
  if (slot === 'q') return catalog.keys.abilityQ;
  return catalog.keys.ultimate;
}

export function findRole(catalog: TacCatalog, id: string | undefined): TacRole | undefined {
  return catalog.roles.find((role) => role.id === id) ?? catalog.roles[0];
}

export function weaponLabel(catalog: TacCatalog, id: string | false | undefined): string | null {
  if (!id) return null;
  const entry = catalog.weapons.find((weapon) => weapon.id === id);
  return entry ? t(entry.label) : null;
}

/** Image d'une arme (public/items) : quelques fichiers gardent le préfixe weapon_ */
export function WeaponImage({ id, className }: { id: string; className?: string }) {
  const short = `./items/${id.toLowerCase().replace(/^weapon_/, '')}.png`;
  const full = `./items/${id.toLowerCase()}.png`;
  return (
    <img
      className={className}
      src={short}
      draggable={false}
      alt=""
      onError={(event) => {
        const image = event.currentTarget;
        if (!image.src.endsWith(full.slice(1))) image.src = full;
        else image.style.visibility = 'hidden';
      }}
    />
  );
}

/** Hexagone à la couleur du rôle, avec son pictogramme */
export function RoleBadge({ role, size = 'm' }: { role: TacRole | undefined; size?: 's' | 'm' | 'l' | 'xl' }) {
  return (
    <span className={`tac-role-badge tac-role-badge--${size} tac-role--${role?.id ?? 'none'}`} aria-hidden>
      <RoleIcon id={role?.id} className="tac-role-badge__icon" />
    </span>
  );
}

export function money(value: number): string {
  return `${Math.max(0, Math.floor(value)).toLocaleString('fr-FR')} ¤`;
}

/** Division du classement : couleur selon le rang de la division */
export function DivisionChip({ catalog, division, rating }: { catalog: TacCatalog; division: string; rating?: number }) {
  const index = Math.max(0, catalog.divisions.findIndex((entry) => entry.label === division));
  return (
    <span className={`tac-division tac-division--${index}`}>
      {t(division)}
      {rating !== undefined && <span className="mono tac-division__rating">{rating}</span>}
    </span>
  );
}

interface PlayerBannerProps {
  catalog: TacCatalog;
  name?: string;
  role?: string;
  division?: string;
  rating?: number;
  /** le joueur lui-même : bannière mise en avant */
  me?: boolean;
  /** emplacement vide de la file */
  empty?: boolean;
  status?: string;
}

/** Bannière verticale d'un joueur (menu du mode) : couleur et pictogramme du rôle, nom, division. */
export function PlayerBanner({ catalog, name, role, division, rating, me, empty, status }: PlayerBannerProps) {
  if (empty) {
    return (
      <div className="tac-banner-card tac-banner-card--empty">
        <span className="tac-banner-card__slot">{status}</span>
      </div>
    );
  }
  const entry = role ? findRole(catalog, role) : undefined;
  return (
    <div className={`tac-banner-card tac-role--${entry?.id ?? 'none'} ${me ? 'tac-banner-card--me' : ''}`}>
      <div className="tac-banner-card__art">
        <span className="tac-banner-card__ghost disp">{t(entry?.label ?? '')}</span>
        <RoleIcon id={entry?.id} className="tac-banner-card__icon" />
        {status && <span className="tac-banner-card__status mono">{status}</span>}
      </div>
      <div className="tac-banner-card__plate">
        <strong>{name}</strong>
      </div>
      <div className="tac-banner-card__foot">
        <span className="label">{t(entry?.label ?? '')}</span>
        {division && <DivisionChip catalog={catalog} division={division} rating={rating} />}
      </div>
    </div>
  );
}
