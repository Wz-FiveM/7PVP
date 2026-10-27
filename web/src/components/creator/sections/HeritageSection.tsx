import { useCreator } from '../../../store/CreatorProvider';
import type { Sex } from '../../../types/appearance';
import { Slider } from '../controls/Slider';
import { Stepper } from '../controls/Stepper';

const SEXES: { id: Sex; label: string }[] = [
  { id: 'male', label: 'Homme' },
  { id: 'female', label: 'Femme' },
];

export function HeritageSection() {
  const { state, actions } = useCreator();
  if (!state) return null;
  const { appearance, schema } = state;
  const { heritage } = appearance;

  const setHeritage = (change: Partial<typeof heritage>) =>
    actions.update((a) => ({ ...a, heritage: { ...a.heritage, ...change } }));

  return (
    <>
      <div className="ctl">
        <span className="ctl__label">Sexe</span>
        <div className="segmented">
          {SEXES.map((sex) => (
            <button
              key={sex.id}
              className={sex.id === appearance.sex ? 'btn btn--small btn--active cut-s' : 'btn btn--small cut-s'}
              onClick={() => sex.id !== appearance.sex && actions.update((a) => ({ ...a, sex: sex.id }))}
            >
              {sex.label}
            </button>
          ))}
        </div>
        <span className="ctl__note muted">Changer de sexe réinitialise l'apparence.</span>
      </div>

      <Stepper
        label="Mère"
        value={Math.max(0, schema.mothers.indexOf(heritage.mother))}
        count={schema.mothers.length}
        format={(i) => `Mère ${String(i + 1).padStart(2, '0')}`}
        onChange={(i) => setHeritage({ mother: schema.mothers[i] })}
      />
      <Stepper
        label="Père"
        value={Math.max(0, schema.fathers.indexOf(heritage.father))}
        count={schema.fathers.length}
        format={(i) => `Père ${String(i + 1).padStart(2, '0')}`}
        onChange={(i) => setHeritage({ father: schema.fathers[i] })}
      />
      <Slider
        label="Ressemblance"
        value={heritage.shapeMix}
        min={0}
        max={1}
        ends={['MÈRE', 'PÈRE']}
        format={(v) => `${Math.round(v * 100)}%`}
        onChange={(shapeMix) => setHeritage({ shapeMix })}
      />
      <Slider
        label="Couleur de peau"
        value={heritage.skinMix}
        min={0}
        max={1}
        ends={['MÈRE', 'PÈRE']}
        format={(v) => `${Math.round(v * 100)}%`}
        onChange={(skinMix) => setHeritage({ skinMix })}
      />
      <Stepper
        label="Couleur des yeux"
        value={appearance.eyeColor}
        count={32}
        onChange={(eyeColor) => actions.update((a) => ({ ...a, eyeColor }))}
      />
    </>
  );
}
