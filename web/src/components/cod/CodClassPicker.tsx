import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import type { CodCatalog, CodProfile } from '../../types/cod';
import { WeaponImage } from './CodParts';

interface CodClassPickerProps {
  profile: CodProfile;
  catalog: CodCatalog;
  onProfile: (profile: CodProfile) => void;
}

/** Changement de classe en partie : s'applique à la prochaine apparition. */
export function CodClassPicker({ profile, catalog, onProfile }: CodClassPickerProps) {
  useT();
  const pick = async (index: number) => {
    const result = await codApi.selectClass(index);
    if (result?.profile) onProfile(result.profile);
    codApi.closePicker();
  };
  const weaponLabel = (id: string) => catalog.primary.find((entry) => entry.id === id)?.label ?? id;

  return (
    <div className="cod-picker">
      <h2 className="cod-picker__title">{t('Changer de classe')}</h2>
      <span className="cod-subtitle">{t('S\'applique à ta prochaine apparition')}</span>
      <ul className="cod-picker__list">
        {profile.classes.map((entry, position) => (
          <li key={position}>
            <button
              className={position + 1 === profile.selected ? 'cod-option cod-option--active' : 'cod-option'}
              onClick={() => pick(position + 1)}
            >
              <WeaponImage id={entry.primary} />
              <span className="cod-option__text">
                <span>{entry.name}</span>
                <span className="cod-list__hint">{t(weaponLabel(entry.primary))}</span>
              </span>
            </button>
          </li>
        ))}
      </ul>
      <button className="cod-leave" onClick={() => codApi.closePicker()}>{t('Fermer')}</button>
    </div>
  );
}
