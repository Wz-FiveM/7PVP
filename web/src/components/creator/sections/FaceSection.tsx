import { useT } from '../../../i18n';
import { useCreator } from '../../../store/CreatorProvider';
import { Slider } from '../controls/Slider';

/** Traits regroupés par zone du visage (index GTA 0 à 19) */
const GROUPS: { title: string; features: number[] }[] = [
  { title: 'Nez', features: [0, 1, 2, 3, 4, 5] },
  { title: 'Sourcils', features: [6, 7] },
  { title: 'Pommettes & joues', features: [8, 9, 10] },
  { title: 'Yeux & lèvres', features: [11, 12] },
  { title: 'Mâchoire & menton', features: [13, 14, 15, 16, 17, 18] },
  { title: 'Cou', features: [19] },
];

const formatSigned = (value: number) => `${value > 0 ? '+' : ''}${Math.round(value * 100)}`;

export function FaceSection() {
  const t = useT();
  const { state, actions } = useCreator();
  if (!state) return null;
  const { appearance, schema } = state;

  const setFeature = (index: number, value: number) =>
    actions.update((a) => ({ ...a, features: a.features.map((v, i) => (i === index ? value : v)) }));

  return (
    <>
      {GROUPS.map((group) => (
        <div key={group.title} className="ctl-section">
          <span className="label">{t(group.title)}</span>
          {group.features.map((index) => (
            <Slider
              key={index}
              label={t(schema.features[index])}
              value={appearance.features[index] ?? 0}
              min={-1}
              max={1}
              step={0.05}
              format={formatSigned}
              onChange={(value) => setFeature(index, value)}
            />
          ))}
        </div>
      ))}
      <button
        className="btn btn--small cut-s"
        onClick={() => actions.update((a) => ({ ...a, features: a.features.map(() => 0) }))}
      >
        {t('Réinitialiser le visage')}
      </button>
    </>
  );
}
