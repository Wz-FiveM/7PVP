import { useEffect, useMemo, useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCatalog, CodCatalogEntry, CodClass, CodPerk, CodProfile, CodWeaponMods } from '../../types/cod';
import { CodGunsmith, type GunsmithPanel } from './CodGunsmith';
import { BracketButton, isUnlocked, WeaponImage } from './CodParts';

type Slot = 'primary' | 'secondary' | 'equipment' | 'tactical' | 'perk1' | 'perk2' | 'perk3';

const PANELS: { id: 'weapon' | GunsmithPanel; label: string }[] = [
  { id: 'weapon', label: 'Arme' },
  { id: 'attachments', label: 'Accessoires' },
  { id: 'camo', label: 'Camouflage' },
];

const SLOTS: { id: Slot; label: string }[] = [
  { id: 'primary', label: 'Arme principale' },
  { id: 'secondary', label: 'Arme secondaire' },
  { id: 'equipment', label: 'Équipement' },
  { id: 'tactical', label: 'Équipement tactique' },
  { id: 'perk1', label: 'Atout 1' },
  { id: 'perk2', label: 'Atout 2' },
  { id: 'perk3', label: 'Atout 3' },
];

const perkTier = (slot: Slot) => (slot.startsWith('perk') ? Number(slot.slice(4)) : 0);

interface Option {
  id: string | false;
  label: string;
  group: string;
  rank: number;
  description?: string;
  weapon: boolean;
}

function optionsFor(slot: Slot, catalog: CodCatalog): Option[] {
  const fromWeapon = (entry: CodCatalogEntry): Option => ({ id: entry.id, label: entry.label, group: entry.category, rank: entry.rank, description: entry.description, weapon: true });
  const fromPerk = (entry: CodPerk): Option => ({ id: entry.id, label: entry.label, group: '', rank: entry.rank, description: entry.description, weapon: false });
  if (slot === 'primary') return catalog.primary.map(fromWeapon);
  if (slot === 'secondary') return catalog.secondary.map(fromWeapon);
  if (slot === 'equipment') {
    return [{ id: false, label: 'Aucun', group: '', rank: 1, weapon: false }, ...catalog.equipment.map(fromWeapon)];
  }
  if (slot === 'tactical') {
    return [{ id: false, label: 'Aucun', group: '', rank: 1, weapon: false }, ...catalog.tactical.map(fromWeapon)];
  }
  return catalog.perks.filter((perk) => perk.tier === perkTier(slot)).map(fromPerk);
}

function slotValue(slot: Slot, draft: CodClass): string | false {
  if (slot === 'primary') return draft.primary;
  if (slot === 'secondary') return draft.secondary;
  if (slot === 'equipment') return draft.equipment;
  if (slot === 'tactical') return draft.tactical;
  return draft.perks[perkTier(slot) - 1];
}

const NO_MODS: CodWeaponMods = { attachments: [], camo: false };

/** Changer d'arme retire les accessoires et le camouflage de la précédente. */
function withSlot(slot: Slot, draft: CodClass, value: string | false): CodClass {
  if (slot === 'primary') return value === draft.primary ? draft : { ...draft, primary: value as string, primaryMods: NO_MODS };
  if (slot === 'secondary') return value === draft.secondary ? draft : { ...draft, secondary: value as string, secondaryMods: NO_MODS };
  if (slot === 'equipment') return { ...draft, equipment: value };
  if (slot === 'tactical') return { ...draft, tactical: value };
  const perks = [...draft.perks];
  perks[perkTier(slot) - 1] = value as string;
  return { ...draft, perks };
}

function labelOf(slot: Slot, draft: CodClass, catalog: CodCatalog): string {
  const value = slotValue(slot, draft);
  return optionsFor(slot, catalog).find((option) => option.id === value)?.label ?? 'Aucun';
}

/** Sur la ligne de l'arme : pastille du camouflage et nombre d'accessoires. */
function ModsMark({ mods, catalog }: { mods: CodWeaponMods; catalog: CodCatalog }) {
  const camo = catalog.gunsmith.camos.find((entry) => entry.id === mods.camo);
  return (
    <>
      {camo && <span className="cod-gunsmith__swatch cod-gunsmith__swatch--small" style={{ background: camo.color }} />}
      {mods.attachments.length > 0 && <span className="cod-loadout__mods">+{mods.attachments.length}</span>}
    </>
  );
}

interface CodClassEditorProps {
  profile: CodProfile;
  catalog: CodCatalog;
  onProfile: (profile: CodProfile) => void;
}

/** Classes : liste et emplacements à gauche, personnage au centre, choix de l'emplacement à droite. */
export function CodClassEditor({ profile, catalog, onProfile }: CodClassEditorProps) {
  useT();
  const { actions } = useGame();
  const [index, setIndex] = useState(profile.selected);
  const [slot, setSlot] = useState<Slot>('primary');
  const [panel, setPanel] = useState<'weapon' | GunsmithPanel>('weapon');
  const saved = profile.classes[index - 1];
  const savedKey = JSON.stringify(saved);
  const [draft, setDraft] = useState<CodClass>(saved);
  const dirty = JSON.stringify(draft) !== savedKey;

  // Pas sur `saved` : un profil reçu en partie (accessoire débloqué) ne doit pas effacer les choix en cours
  useEffect(() => setDraft(saved), [savedKey]);

  const options = useMemo(() => optionsFor(slot, catalog), [slot, catalog]);

  const weaponSlot = slot === 'secondary' ? 'secondary' : slot === 'primary' ? 'primary' : null;
  const shownWeapon = draft[weaponSlot ?? 'primary'];
  const shownMods = weaponSlot === 'secondary' ? draft.secondaryMods : draft.primaryMods;
  const shownKey = JSON.stringify([shownWeapon, shownMods]);
  const setMods = (mods: CodWeaponMods) =>
    setDraft({ ...draft, [weaponSlot === 'secondary' ? 'secondaryMods' : 'primaryMods']: mods });

  // Le personnage du menu tient l'arme telle qu'elle est en train d'être réglée
  useEffect(() => void codApi.previewWeapon(shownWeapon, shownMods), [shownKey]);
  useEffect(() => () => void codApi.previewWeapon(), []);

  const report = (result: { ok: boolean; message?: string; profile?: CodProfile } | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.profile) onProfile(result.profile);
  };
  const save = async () => report(await codApi.saveClass(index, draft));
  const equip = async () => report(await codApi.selectClass(index));

  let lastGroup = '';
  return (
    <>
      <section className="cod-column">
        <span className="cod-label">{t('Classes')}</span>
        <ul className="cod-list">
          {profile.classes.map((entry, position) => (
            <li key={position}>
              <button
                className={position + 1 === index ? 'cod-list__row cod-list__row--active' : 'cod-list__row'}
                onClick={() => setIndex(position + 1)}
              >
                <span>{entry.name}</span>
                {position + 1 === profile.selected && <span className="cod-list__meta">{t('ÉQUIPÉE')}</span>}
              </button>
            </li>
          ))}
        </ul>

        <input
          className="cod-input"
          value={draft.name}
          maxLength={catalog.classNameLength}
          aria-label={t('Nom de la classe')}
          onChange={(event) => setDraft({ ...draft, name: event.target.value })}
        />

        <ul className="cod-loadout">
          {SLOTS.map((entry) => (
            <li key={entry.id}>
              <button
                className={entry.id === slot ? 'cod-loadout__row cod-loadout__row--active' : 'cod-loadout__row'}
                onClick={() => setSlot(entry.id)}
              >
                <span className="cod-loadout__slot">{t(entry.label)}</span>
                <span className="cod-loadout__value">
                  {t(labelOf(entry.id, draft, catalog))}
                  {entry.id === 'primary' && <ModsMark mods={draft.primaryMods} catalog={catalog} />}
                  {entry.id === 'secondary' && <ModsMark mods={draft.secondaryMods} catalog={catalog} />}
                </span>
              </button>
            </li>
          ))}
        </ul>

        <div className="cod-column__foot cod-column__foot--row">
          <BracketButton onClick={save} disabled={!dirty || !draft.name.trim()}>{t('Enregistrer')}</BracketButton>
          <BracketButton onClick={equip} disabled={index === profile.selected || dirty}>{t('Équiper')}</BracketButton>
        </div>
      </section>

      <section className="cod-column cod-column--right cod-column--scroll">
        <span className="cod-label">{t(SLOTS.find((entry) => entry.id === slot)?.label ?? '')}</span>
        {weaponSlot && (
          <div className="cod-gunsmith__tabs">
            {PANELS.map((entry) => (
              <button
                key={entry.id}
                className={entry.id === panel ? 'cod-gunsmith__tab cod-gunsmith__tab--active' : 'cod-gunsmith__tab'}
                onClick={() => setPanel(entry.id)}
              >
                {t(entry.label)}
              </button>
            ))}
          </div>
        )}
        {weaponSlot && panel !== 'weapon' ? (
          <CodGunsmith weapon={shownWeapon} mods={shownMods} profile={profile} catalog={catalog} panel={panel} onChange={setMods} />
        ) : (
          <ul className="cod-options">
            {options.map((option) => {
              const locked = !isUnlocked(option.id, option.rank, profile);
              const showGroup = option.group && option.group !== lastGroup;
              if (option.group) lastGroup = option.group;
              return (
                <li key={String(option.id)}>
                  {showGroup && <span className="cod-options__group">{t(option.group)}</span>}
                  <button
                    className={[
                      'cod-option',
                      option.id === slotValue(slot, draft) && 'cod-option--active',
                      locked && 'cod-option--locked',
                    ].filter(Boolean).join(' ')}
                    disabled={locked}
                    onClick={() => setDraft(withSlot(slot, draft, option.id))}
                  >
                    {option.weapon && typeof option.id === 'string' && <WeaponImage id={option.id} />}
                    <span className="cod-option__text">
                      <span>{t(option.label)}</span>
                      {option.description && <span className="cod-list__hint">{t(option.description)}</span>}
                    </span>
                    {locked && <span className="cod-locked">{t('RANG {rank}', { rank: option.rank })}</span>}
                    {!locked && option.weapon && weaponSlot && typeof option.id === 'string' && (
                      <span className="cod-option__level">{t('NIV. {level}', { level: profile.weapons[option.id]?.level ?? 1 })}</span>
                    )}
                  </button>
                </li>
              );
            })}
          </ul>
        )}
      </section>
    </>
  );
}
