import { useCallback, useEffect, useState } from 'react';
import { isEnvBrowser } from '../../api/nui';
import { weaponCustomApi } from '../../api/weaponCustomApi';
import { useNuiMessage } from '../../hooks/useNuiMessage';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { NuiMessage } from '../../types/nui';
import type { WeaponCustomChoice, WeaponCustomWeapon } from '../../types/weaponCustom';
import { entriesOf, fittedAttachments, itemLabel } from '../../utils/inventory';
import { Stepper } from '../creator/controls/Stepper';
import { ItemIcon } from '../inventory/ItemIcon';
import { Logo } from '../ui/Logo';
import { CustomStage } from './CustomStage';
import '../creator/creator.css';
import './vehicleCustom.css';

/** Menu du customiseur d'armes, en mode PvP. Monté en permanence : Lua peut le fermer à tout moment. */
export function WeaponCustom({ onOpenChange }: { onOpenChange: (open: boolean) => void }) {
  const [weapons, setWeapons] = useState<WeaponCustomWeapon[] | null>(null);

  const handleMessage = useCallback(
    (message: NuiMessage) => {
      if (message.action !== 'weaponCustom') return;
      setWeapons(message.data.open ? message.data.weapons : null);
      onOpenChange(message.data.open);
    },
    [onOpenChange],
  );
  useNuiMessage(handleMessage);

  const close = () => {
    if (!isEnvBrowser()) return;
    setWeapons(null);
    onOpenChange(false);
  };

  return weapons ? <WeaponCustomPanel weapons={weapons} onClose={close} /> : null;
}

function WeaponCustomPanel({ weapons, onClose }: { weapons: WeaponCustomWeapon[]; onClose: () => void }) {
  const t = useT();
  const { state, actions } = useGame();
  const [selected, setSelected] = useState(weapons[0].name);
  /** Choix en cours, par arme : rien n'est gardé avant « Enregistrer » */
  const [drafts, setDrafts] = useState<Record<string, WeaponCustomChoice>>({});
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const choiceOf = (weapon: WeaponCustomWeapon): WeaponCustomChoice =>
    drafts[weapon.name] ?? { tint: weapon.tint, finish: weapon.finish };

  const weapon = weapons.find((entry) => entry.name === selected) ?? weapons[0];
  const choice = choiceOf(weapon);

  const inventory = state.player?.inventory;
  const fitted = inventory ? fittedAttachments(inventory, weapon.name) : [];
  const owned = new Set(inventory ? [...entriesOf(inventory.bag), ...entriesOf(inventory.protected)].map(([name]) => name) : []);
  const fittedKey = fitted.join();

  // Le modèle d'essai suit l'arme choisie, sa custom et ses accessoires, dès qu'un des trois change
  useEffect(() => {
    weaponCustomApi.preview(weapon.name, { tint: choice.tint, finish: choice.finish }, fittedKey ? fittedKey.split(',') : []);
  }, [weapon.name, choice.tint, choice.finish, fittedKey]);

  const change = (next: WeaponCustomChoice) => {
    setDrafts({ ...drafts, [weapon.name]: next });
  };

  const cancel = useCallback(() => {
    weaponCustomApi.cancel();
    onClose();
  }, [onClose]);

  useEffect(() => {
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') cancel();
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [cancel]);

  const changed = Object.fromEntries(
    weapons
      .filter((entry) => {
        const draft = drafts[entry.name];
        return draft && (draft.tint !== entry.tint || draft.finish !== entry.finish);
      })
      .map((entry) => [entry.name, drafts[entry.name]]),
  );
  const hasChanges = Object.keys(changed).length > 0;

  const save = async () => {
    setSaving(true);
    setError(null);
    const result = await weaponCustomApi.save(changed);
    setSaving(false);
    if (!result?.ok) return setError(result?.message ?? t('Le serveur ne répond pas.'));
    onClose();
  };

  const currentTint = weapon.tints.find((tint) => tint.id === choice.tint);
  const finishIndex = weapon.finishes.findIndex((finish) => finish.component === choice.finish) + 1;

  return (
    <div className="creator weapon-custom">
      <aside className="creator-panel">
        <header className="creator-panel__header">
          <Logo size={52} />
          <div className="creator-panel__titles">
            <span className="label">{t('Customiseur')}</span>
            <h1 className="disp creator-panel__title">{t(weapon.label)}</h1>
          </div>
        </header>

        <div className="creator-panel__body">
          {weapon.tints.length > 0 && (
            <div className="ctl">
              <span className="ctl__row">
                <span className="ctl__label">{t('Teinte')}</span>
                <span className="mono ctl__value">{currentTint ? t(currentTint.label) : ''}</span>
              </span>
              <div className="swatches weapon-custom__swatches" role="radiogroup" aria-label={t('Teinte')}>
                {weapon.tints.map((tint) => (
                  <button
                    key={tint.id}
                    role="radio"
                    aria-checked={tint.id === choice.tint}
                    aria-label={t(tint.label)}
                    title={t(tint.label)}
                    className={tint.id === choice.tint ? 'swatch swatch--active' : 'swatch'}
                    style={{ background: tint.hex }}
                    onClick={() => change({ ...choice, tint: tint.id })}
                  />
                ))}
              </div>
            </div>
          )}

          {weapon.finishes.length > 0 && (
            <Stepper
              label={t('Finition')}
              value={finishIndex}
              count={weapon.finishes.length + 1}
              format={(value) => (value === 0 ? t('D\'origine') : t(weapon.finishes[value - 1].label))}
              onChange={(value) => change({ ...choice, finish: value === 0 ? false : weapon.finishes[value - 1].component })}
            />
          )}

          {weapon.attachments.length > 0 && (
            <div className="ctl">
              <span className="ctl__label">{t('Accessoires')}</span>
              <ul className="weapon-custom__list">
                {weapon.attachments.map((attachment) => {
                  const isFitted = fitted.includes(attachment);
                  const available = isFitted || owned.has(attachment);
                  return (
                    <li key={attachment}>
                      <button
                        className={isFitted ? 'weapon-custom__row weapon-custom__row--active' : 'weapon-custom__row'}
                        disabled={!available}
                        onClick={() => actions.attachment(weapon.name, attachment, !isFitted)}
                      >
                        <span className="weapon-custom__icon">
                          <ItemIcon name={attachment} type="attachment" />
                        </span>
                        <span className="disp weapon-custom__name">{itemLabel(state.config, attachment)}</span>
                        <span className={available ? 'mono weapon-custom__changed' : 'mono muted weapon-custom__state'}>
                          {isFitted ? t('Retirer') : available ? t('Fixer') : t('Pas sur toi')}
                        </span>
                      </button>
                    </li>
                  );
                })}
              </ul>
              <p className="muted vehicle-custom__note">{t('Un accessoire se fixe tout de suite, sans passer par Enregistrer.')}</p>
            </div>
          )}

          <div className="ctl">
            <span className="ctl__label">{t('Armes dans ton sac')}</span>
            <ul className="weapon-custom__list">
              {weapons.map((entry) => (
                <li key={entry.name}>
                  <button
                    className={entry.name === weapon.name ? 'weapon-custom__row weapon-custom__row--active' : 'weapon-custom__row'}
                    onClick={() => setSelected(entry.name)}
                  >
                    <span className="weapon-custom__icon">
                      <ItemIcon name={entry.name} type="weapon" />
                    </span>
                    <span className="disp weapon-custom__name">{t(entry.label)}</span>
                    {changed[entry.name] && <span className="mono weapon-custom__changed">{t('modifiée')}</span>}
                  </button>
                </li>
              ))}
            </ul>
          </div>
        </div>

        <footer className="creator-panel__footer">
          {error && <p className="creator-panel__error">{error}</p>}
          <p className="muted vehicle-custom__note">{t('Gardée pour toutes tes prochaines armes de ce modèle.')}</p>
          <div className="creator-panel__actions">
            <button className="btn cut-s" onClick={cancel} disabled={saving}>
              {t('Annuler')}
            </button>
            <button className="btn btn--primary cut-s creator-panel__confirm" onClick={save} disabled={saving || !hasChanges}>
              {saving ? t('Enregistrement…') : t('Enregistrer')}
            </button>
          </div>
        </footer>
      </aside>

      {/* Le modèle tourne sur lui-même : glisser à droite le fait tourner vers la droite */}
      <CustomStage hint={t('[GLISSER] TOURNER L\'ARME')} onRotate={(delta) => weaponCustomApi.rotate(-delta)} />
    </div>
  );
}
