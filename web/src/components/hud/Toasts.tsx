import { useGame } from '../../store/GameContext';
import type { ToastKind } from '../../types/game';
import { Icon, type IconName } from '../icons/Icon';

const ICON: Record<ToastKind, IconName> = { info: 'crosshair', success: 'check', error: 'crosshair' };

export function Toasts() {
  const { state } = useGame();

  return (
    <div className="toasts">
      {state.toasts.map((toast) => (
        <div key={toast.id} className={`toast toast--${toast.kind} cut-s`}>
          <Icon name={ICON[toast.kind]} size={16} strokeWidth={2.4} className="toast__icon" />
          {toast.text}
        </div>
      ))}
    </div>
  );
}
