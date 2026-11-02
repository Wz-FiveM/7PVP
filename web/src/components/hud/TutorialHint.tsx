import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';

/** Prochaine étape des premiers pas, sous le killfeed (voir Config.Tutorial). */
export function TutorialHint() {
  const t = useT();
  const { state } = useGame();
  const steps = state.config.tutorial?.steps;
  const tutorial = state.player?.tutorial;
  if (!steps || !tutorial || tutorial.finished || state.mode !== 'pvp') return null;

  const next = steps.find((step) => !tutorial.done?.[step.id]);
  if (!next) return null;
  const count = steps.filter((step) => tutorial.done?.[step.id]).length;

  return (
    <div className="bounties tutorial-hint">
      <span className="label bounties__title">{t('Premiers pas {count} / {total}', { count, total: steps.length })}</span>
      <div className="bounties__item cut-s">
        <span className="bounties__name">{t(next.label)}</span>
      </div>
      <span className="tutorial-hint__text">{t(next.hint)}</span>
    </div>
  );
}
