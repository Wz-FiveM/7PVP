import { useCountdown } from '../../hooks/useCountdown';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { classOf } from '../../utils/classes';
import { Icon } from '../icons/Icon';

/** Compétence de classe (bas droite, au-dessus des effets) : touche, ou temps avant de pouvoir la relancer. */
export function ClassAbility() {
  const t = useT();
  const { state } = useGame();
  const { config, player } = state;
  const info = player?.playerClass;
  const remaining = useCountdown(info?.cooldown ?? 0, info);
  const entry = classOf(config, player);
  if (!config.classes) return null;
  if (!entry) {
    return (
      <div className="class-ability">
        <span className="disp class-ability__name">{t('Choisis ta classe : {key} > Classe', { key: config.menuKey ?? 'TAB' })}</span>
      </div>
    );
  }

  const ratio = remaining > 0 ? Math.min(1, remaining / entry.ability.cooldown) : 0;
  return (
    <div className={remaining > 0 ? 'class-ability class-ability--waiting' : 'class-ability'}>
      <span className="disp class-ability__name">{t(entry.ability.label)}</span>
      <div className="class-ability__tile cut-s">
        <span className="class-ability__veil" style={{ height: `${ratio * 100}%` }} />
        <Icon name={entry.icon} size={24} strokeWidth={2} />
        <span className="mono class-ability__key">{remaining > 0 ? `${remaining}s` : config.classes.keyLabel}</span>
      </div>
    </div>
  );
}
