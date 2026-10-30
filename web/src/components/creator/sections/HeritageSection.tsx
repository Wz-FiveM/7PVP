import { useT } from '../../../i18n';
import { useCreator } from '../../../store/CreatorProvider';
import type { Sex } from '../../../types/appearance';
import { Slider } from '../controls/Slider';
import { Stepper } from '../controls/Stepper';

const SEXES: { id: Sex; label: string }[] = [
  { id: 'male', label: 'Homme' },
  { id: 'female', label: 'Femme' },
];

export function HeritageSection() {
  const t = useT();
  const { state, actions } = useCreator();
  if (!state) return null;
  const { appearance, schema } = state;
  const { heritage } = appearance;

  const setHeritage = (change: Partial<typeof heritage>) =>
    actions.update((a) => ({ ...a, heritage: { ...a.heritage, ...change } }));

  return (
    <>
      <div className="ctl">
        <span className="ctl__label">{t('Sexe')}</span>
        <div className="segmented">
          {SEXES.map((sex) => (
            <button
              key={sex.id}
              className={sex.id === appearance.sex ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
              onClick={() => sex.id !== appearance.sex && actions.update((a) => ({ ...a, sex: sex.id }))}
            >
              {t(sex.label)}
            </button>
          ))}
        </div>
        <span className="ctl__note muted">{t("Changer de sexe réinitialise l'apparence.")}</span>
      </div>

      <Stepper
        label={t('Mère')}
        value={Math.max(0, schema.mothers.indexOf(heritage.mother))}
        count={schema.mothers.length}
        format={(i) => t('Mère {number}', { number: String(i + 1).padStart(2, '0') })}
        onChange={(i) => setHeritage({ mother: schema.mothers[i] })}
      />
      <Stepper
        label={t('Père')}
        value={Math.max(0, schema.fathers.indexOf(heritage.father))}
        count={schema.fathers.length}
        format={(i) => t('Père {number}', { number: String(i + 1).padStart(2, '0') })}
        onChange={(i) => setHeritage({ father: schema.fathers[i] })}
      />
      <Slider
        label={t('Ressemblance')}
        value={heritage.shapeMix}
        min={0}
        max={1}
        ends={[t('MÈRE'), t('PÈRE')]}
        format={(v) => `${Math.round(v * 100)}%`}
        onChange={(shapeMix) => setHeritage({ shapeMix })}
      />
      <Slider
        label={t('Couleur de peau')}
        value={heritage.skinMix}
        min={0}
        max={1}
        ends={[t('MÈRE'), t('PÈRE')]}
        format={(v) => `${Math.round(v * 100)}%`}
        onChange={(skinMix) => setHeritage({ skinMix })}
      />
      <Stepper
        label={t('Couleur des yeux')}
        value={appearance.eyeColor}
        count={32}
        onChange={(eyeColor) => actions.update((a) => ({ ...a, eyeColor }))}
      />
    </>
  );
}
