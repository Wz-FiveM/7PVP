import { t, useT } from '../../i18n';
import type { CodAttachment, CodCamo, CodCatalog, CodProfile, CodWeaponMods, CodWeaponProgress } from '../../types/cod';

export type GunsmithPanel = 'attachments' | 'camo';

const camoUnlocked = (camo: CodCamo, progress: CodWeaponProgress | undefined) =>
  (progress?.kills ?? 0) >= (camo.kills ?? 0) && (progress?.headshots ?? 0) >= (camo.headshots ?? 0);

/** Ce qu'il reste à faire pour un camouflage : les deux compteurs s'il demande les deux. */
function camoCondition(camo: CodCamo, progress: CodWeaponProgress | undefined): string {
  const parts: string[] = [];
  if (camo.kills) parts.push(t('{count} / {needed} kills', { count: progress?.kills ?? 0, needed: camo.kills }));
  if (camo.headshots) parts.push(t('{count} / {needed} tirs à la tête', { count: progress?.headshots ?? 0, needed: camo.headshots }));
  return parts.join(' · ');
}

interface CodGunsmithProps {
  weapon: string;
  mods: CodWeaponMods;
  profile: CodProfile;
  catalog: CodCatalog;
  panel: GunsmithPanel;
  onChange: (mods: CodWeaponMods) => void;
}

/** Niveau de l'arme, puis ses accessoires (un par emplacement) ou ses camouflages. */
export function CodGunsmith({ weapon, mods, profile, catalog, panel, onChange }: CodGunsmithProps) {
  useT();
  const { levels, slots, attachments, camos } = catalog.gunsmith;
  const progress = profile.weapons[weapon];
  const level = progress?.level ?? 1;
  const into = progress?.into ?? 0;
  const needed = progress ? progress.needed : levels.base;
  const components = catalog.gunsmith.weapons[weapon] ?? {};

  /** Prendre un accessoire remplace celui de son emplacement ; le reprendre le retire. L'ordre reste celui du catalogue. */
  const toggle = (entry: CodAttachment) => {
    const active = mods.attachments.includes(entry.id);
    const kept = attachments.filter((other) =>
      other.id === entry.id ? !active : other.slot !== entry.slot && mods.attachments.includes(other.id));
    onChange({ ...mods, attachments: kept.map((other) => other.id) });
  };

  return (
    <>
      <div className="cod-gunsmith__level">
        <span className="cod-gunsmith__level-title">{t('Niveau {level}', { level })}</span>
        <span className="cod-xpbar"><span style={{ width: `${needed > 0 ? (into / needed) * 100 : 100}%` }} /></span>
        <span className="cod-list__hint">
          {needed > 0 ? t('{count} / {needed} kills pour le niveau suivant', { count: into, needed }) : t('Niveau maximum')}
        </span>
      </div>

      {panel === 'attachments' && (
        <ul className="cod-options">
          {Object.keys(components).length === 0 && <li className="cod-list__hint">{t('Cette arme n\'a pas d\'accessoire.')}</li>}
          {slots.map((slot) => {
            const options = attachments.filter((entry) => entry.slot === slot.id && components[entry.id]);
            return options.map((entry, position) => {
              const locked = entry.level > level;
              return (
                <li key={entry.id}>
                  {position === 0 && <span className="cod-options__group">{t(slot.label)}</span>}
                  <button
                    className={[
                      'cod-option',
                      mods.attachments.includes(entry.id) && 'cod-option--active',
                      locked && 'cod-option--locked',
                    ].filter(Boolean).join(' ')}
                    disabled={locked}
                    onClick={() => toggle(entry)}
                  >
                    <span className="cod-option__text">
                      <span>{t(entry.label)}</span>
                      <span className="cod-list__hint">{t(entry.description)}</span>
                    </span>
                    {locked && <span className="cod-locked">{t('NIVEAU {level}', { level: entry.level })}</span>}
                  </button>
                </li>
              );
            });
          })}
        </ul>
      )}

      {panel === 'camo' && (
        <ul className="cod-options">
          <li>
            <button
              className={mods.camo === false ? 'cod-option cod-option--active' : 'cod-option'}
              onClick={() => onChange({ ...mods, camo: false })}
            >
              <span className="cod-gunsmith__swatch cod-gunsmith__swatch--none" />
              <span className="cod-option__text"><span>{t('Aucun')}</span></span>
            </button>
          </li>
          {camos.map((camo) => {
            const locked = !camoUnlocked(camo, progress);
            return (
              <li key={camo.id}>
                <button
                  className={[
                    'cod-option',
                    mods.camo === camo.id && 'cod-option--active',
                    locked && 'cod-option--locked',
                  ].filter(Boolean).join(' ')}
                  disabled={locked}
                  onClick={() => onChange({ ...mods, camo: camo.id })}
                >
                  <span className="cod-gunsmith__swatch" style={{ background: camo.color }} />
                  <span className="cod-option__text">
                    <span>{t(camo.label)}</span>
                    {locked && <span className="cod-list__hint">{camoCondition(camo, progress)}</span>}
                  </span>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </>
  );
}
