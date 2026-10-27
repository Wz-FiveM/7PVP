import { useCreator } from '../../../store/CreatorProvider';
import { Stepper } from '../controls/Stepper';
import { Swatches } from '../controls/Swatches';
import { OverlaySection } from './OverlaySection';

export function HairSection() {
  const { state, actions } = useCreator();
  if (!state) return null;
  const { appearance, limits, palettes } = state;

  const setHair = (change: Partial<typeof appearance.hair>) =>
    actions.update((a) => ({ ...a, hair: { ...a.hair, ...change } }));

  return (
    <>
      <div className="ctl-group">
        <Stepper label="Coiffure" value={appearance.hair.style} count={limits.hair} onChange={(style) => setHair({ style })} />
        <Swatches label="Couleur" colors={palettes.hair} value={appearance.hair.color} onChange={(color) => setHair({ color })} />
        <Swatches
          label="Reflets"
          colors={palettes.hair}
          value={appearance.hair.highlight}
          onChange={(highlight) => setHair({ highlight })}
        />
      </div>
      <OverlaySection keys={['eyebrows', 'beard', 'chestHair']} />
    </>
  );
}
