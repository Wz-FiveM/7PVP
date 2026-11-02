import { gameApi } from '../api/gameApi';
import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { ActionResult } from '../types/nui';
import { formatMoney } from '../utils/format';
import './pages.css';

/** Hauts faits : objectifs permanents, récompense versée à l'objectif, et choix du titre affiché. */
export function AchievementsPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player } = state;
  const data = player?.achievements;
  if (!data || !config.achievements) return null;

  const report = (result: ActionResult | undefined) => {
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };
  const list = config.achievements;
  const doneCount = list.filter((entry) => data.done?.[entry.id]).length;

  return (
    <div className="contracts">
      <p className="mono muted contracts__reset">
        {t('{done} / {total} TERMINÉS · RÉCOMPENSE VERSÉE DÈS L\'OBJECTIF ATTEINT', { done: doneCount, total: list.length })}
      </p>
      {data.seasonTitles.length > 0 && (
        <Panel className="contract">
          <span className="disp contract__label">{t('Titres de saison')}</span>
          <div className="loadout-set__actions">
            {data.seasonTitles.map((title) => (
              <button
                key={title.id}
                className={data.title === title.id ? 'btn btn--active btn--small cut-s' : 'btn btn--small cut-s'}
                onClick={() => gameApi.selectTitle(data.title === title.id ? '' : title.id).then(report)}
              >
                {t(title.label)} · {title.id.split(':')[0]}
              </button>
            ))}
          </div>
        </Panel>
      )}
      {list.map((entry) => {
        const done = Boolean(data.done?.[entry.id]);
        const value = Math.min(data.stats?.[entry.stat] ?? 0, entry.goal);
        const equipped = data.title === entry.id;
        return (
          <Panel key={entry.id} className={done ? 'contract contract--done' : 'contract'}>
            <div className="contract__head">
              <span className="disp contract__label">{t(entry.label)}</span>
              <span className="mono contract__reward">
                {formatMoney(entry.reward.money)} · {entry.reward.xp} XP
              </span>
            </div>
            <span className="muted">{t(config.achievementStats?.[entry.stat]?.text ?? '', { goal: entry.goal })}</span>
            <SegmentBar value={value} max={entry.goal} segments={Math.min(entry.goal, 20)} color={done ? 'var(--toxine)' : 'var(--signal)'} height={6} />
            <span className="mono contract__progress">
              {done ? t('TERMINÉ') : `${value} / ${entry.goal}`}
            </span>
            {entry.title && done && (
              <button
                className={equipped ? 'btn btn--active btn--small cut-s' : 'btn btn--small cut-s'}
                onClick={() => gameApi.selectTitle(equipped ? '' : entry.id).then(report)}
              >
                {equipped ? t('Titre équipé') : t('Prendre ce titre')}
              </button>
            )}
            {entry.title && !done && <span className="muted">{t('Débloque un titre.')}</span>}
          </Panel>
        );
      })}
    </div>
  );
}
