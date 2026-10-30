import { gameApi } from '../../api/gameApi';
import { isEnvBrowser } from '../../api/nui';
import { getLanguages, setLanguage, useLanguage, useT } from '../../i18n';
import './languagePicker.css';

/** Choix de la langue (menu pause, lobby) : la langue est gardée côté Lua, qui renvoie « locale ». */
export function LanguagePicker({ compact }: { compact?: boolean }) {
  const t = useT();
  const current = useLanguage();

  const choose = (id: string) => {
    if (id === current) return;
    void gameApi.setLanguage(id);
    // Hors jeu, pas de Lua pour renvoyer la langue
    if (isEnvBrowser()) void setLanguage(id);
  };

  return (
    <div className={compact ? 'language-picker language-picker--compact' : 'language-picker'} role="radiogroup" aria-label={t('Langue')}>
      {getLanguages().map((language) => (
        <button
          key={language.id}
          role="radio"
          aria-checked={language.id === current}
          title={language.label}
          className={language.id === current ? 'language-picker__option language-picker__option--active' : 'language-picker__option'}
          onClick={() => choose(language.id)}
        >
          <span className="mono language-picker__code">{language.id.toUpperCase()}</span>
          {!compact && <span className="language-picker__label">{language.label}</span>}
        </button>
      ))}
    </div>
  );
}
