import { useCreator } from '../../../store/CreatorProvider';
import type { OverlayValue } from '../../../types/appearance';
import { OverlayControl } from '../controls/OverlayControl';

interface OverlaySectionProps {
  /** Clés des calques à afficher, dans l'ordre */
  keys: string[];
}

/** Liste de calques de la tête (pilosité, peau, maquillage). */
export function OverlaySection({ keys }: OverlaySectionProps) {
  const { state, actions } = useCreator();
  if (!state) return null;
  const { appearance, schema, limits, palettes } = state;

  const setOverlay = (key: string, value: OverlayValue) =>
    actions.update((a) => ({ ...a, overlays: { ...a.overlays, [key]: value } }));

  return (
    <>
      {schema.overlays
        .filter((entry) => keys.includes(entry.key))
        .map((entry) => (
          <OverlayControl
            key={entry.key}
            entry={entry}
            value={appearance.overlays[entry.key]}
            count={limits.overlays[entry.key] ?? 0}
            colors={entry.color === 1 ? palettes.hair : entry.color === 2 ? palettes.makeup : undefined}
            onChange={(value) => setOverlay(entry.key, value)}
          />
        ))}
    </>
  );
}
