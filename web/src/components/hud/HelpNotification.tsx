import { useGame } from '../../store/GameContext';

/** Aide contextuelle (touche + action), au-dessus des notifications. */
export function HelpNotification() {
  const { state } = useGame();
  const help = state.helpNotify;
  if (!help) return null;

  return (
    <div key={`${help.key}|${help.text}`} className="help-notify cut-s">
      <span className="mono help-notify__key cut-s">{help.key}</span>
      <span className="help-notify__text">{help.text}</span>
    </div>
  );
}
