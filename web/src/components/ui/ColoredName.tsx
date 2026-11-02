import { useGame } from '../../store/GameContext';

/** Nom affiché lettre par lettre : `colors` contient un code par lettre (Config.NameColors). */
export function ColoredName({ text, colors }: { text: string; colors?: string }) {
  const palette = useGame().state.config.nameColors?.list;
  if (!colors || !palette) return <>{text}</>;

  return (
    <>
      {Array.from(text).map((letter, index) => {
        const hex = palette.find((color) => color.code === colors[index])?.hex;
        return (
          <span key={index} style={hex ? { color: hex } : undefined}>
            {letter}
          </span>
        );
      })}
    </>
  );
}
