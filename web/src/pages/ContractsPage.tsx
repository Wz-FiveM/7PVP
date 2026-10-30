import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import { formatMoney } from '../utils/format';
import './pages.css';

/** Durée lisible : « 5 h 12 » ou « 12 min ». */
function formatDuration(seconds: number): string {
  const hours = Math.floor(seconds / 3600);
  const minutes = Math.floor((seconds % 3600) / 60);
  return hours > 0 ? `${hours} h ${String(minutes).padStart(2, '0')}` : `${minutes} min`;
}

/** Contrats du jour : progression et récompenses (versées automatiquement). */
export function ContractsPage() {
  const t = useT();
  const { state } = useGame();
  const contracts = state.player?.contracts;
  if (!contracts) return null;

  return (
    <div className="contracts">
      <p className="mono muted contracts__reset">
        {t('NOUVEAUX CONTRATS DANS {time} · RÉCOMPENSE VERSÉE DÈS L\'OBJECTIF ATTEINT', { time: formatDuration(contracts.resetIn).toUpperCase() })}
      </p>
      {contracts.list.map((contract) => (
        <Panel key={contract.id} className={contract.done ? 'contract contract--done' : 'contract'}>
          <div className="contract__head">
            <span className="disp contract__label">{t(contract.label)}</span>
            <span className="mono contract__reward">
              {formatMoney(contract.reward.money)} · {contract.reward.xp} XP
            </span>
          </div>
          <SegmentBar
            value={contract.progress}
            max={contract.goal}
            segments={Math.min(contract.goal, 20)}
            color={contract.done ? 'var(--toxine)' : 'var(--signal)'}
            height={6}
          />
          <span className="mono contract__progress">
            {contract.done ? t('TERMINÉ') : `${contract.progress} / ${contract.goal}`}
          </span>
        </Panel>
      ))}
    </div>
  );
}
