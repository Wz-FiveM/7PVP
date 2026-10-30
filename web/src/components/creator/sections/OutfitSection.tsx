import { useT } from '../../../i18n';
import { useCreator } from '../../../store/CreatorProvider';
import type { DrawableValue } from '../../../types/appearance';
import { DrawableControl } from '../controls/DrawableControl';

export function OutfitSection() {
  const t = useT();
  const { state, actions } = useCreator();
  if (!state) return null;
  const { appearance, schema, limits } = state;

  const setComponent = (key: string, value: DrawableValue) =>
    actions.update((a) => ({ ...a, components: { ...a.components, [key]: value } }));
  const setProp = (key: string, value: DrawableValue) =>
    actions.update((a) => ({ ...a, props: { ...a.props, [key]: value } }));

  return (
    <>
      {schema.components.map((entry) => (
        <DrawableControl
          key={entry.key}
          label={t(entry.label)}
          value={appearance.components[entry.key]}
          limit={limits.components[entry.key] ?? { drawables: 0, textures: 0 }}
          onChange={(value) => setComponent(entry.key, value)}
        />
      ))}
      <span className="ctl__note muted">{t('Ajuste « Bras » si le haut laisse voir les bras ou les coupe.')}</span>
      {schema.props.map((entry) => (
        <DrawableControl
          key={entry.key}
          label={t(entry.label)}
          value={appearance.props[entry.key]}
          limit={limits.props[entry.key] ?? { drawables: 0, textures: 0 }}
          allowNone
          onChange={(value) => setProp(entry.key, value)}
        />
      ))}
    </>
  );
}
