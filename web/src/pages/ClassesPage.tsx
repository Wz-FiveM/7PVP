import { Icon } from '../components/icons/Icon';
import { Panel } from '../components/ui/Panel';
import { useCountdown } from '../hooks/useCountdown';
import { useT } from '../i18n';
import { useGame } from '../store/GameContext';
import { itemLabel } from '../utils/inventory';
import './classes.css';

/** Choix de la classe : passifs, compétence et armes de prédilection. Le changement se fait en zone safe. */
export function ClassesPage() {
  const t = useT();
  const { state, actions } = useGame();
  const { config, player, menu } = state;
  const info = player?.playerClass;
  const changeIn = useCountdown(info?.changeIn ?? 0, info);
  const classes = config.classes;
  if (!player || !classes) return null;

  // Le premier choix n'a pas de délai
  const waiting = info?.id ? changeIn : 0;

  return (
    <>
      {!menu.inSafe && <p className="hint cut-s">{t('Le choix de la classe se fait en zone safe, hors combat.')}</p>}
      {menu.inSafe && waiting > 0 && (
        <p className="hint cut-s">{t('Changement de classe possible dans {seconds} s.', { seconds: waiting })}</p>
      )}
      <div className="classes">
        {classes.list.map((entry) => {
          const selected = info?.id === entry.id;
          return (
            <Panel key={entry.id} className={selected ? 'class-card class-card--selected' : 'class-card'}>
              <header className="class-card__head">
                <span className="class-card__icon cut-s"><Icon name={entry.icon} size={22} strokeWidth={2} /></span>
                <span className="class-card__title">
                  <span className="disp class-card__name">{t(entry.label)}</span>
                  <span className="muted class-card__role">{t(entry.role)}</span>
                </span>
                {selected && <span className="chip">{t('Équipée')}</span>}
              </header>
              <p className="class-card__summary">{t(entry.summary)}</p>

              <h3 className="mono muted class-card__section">{t('PASSIF')}</h3>
              <ul className="class-card__list">
                {entry.passives.map((passive) => <li key={passive}>{t(passive)}</li>)}
              </ul>

              <h3 className="mono muted class-card__section">
                {t('COMPÉTENCE [{key}] · {seconds} S', { key: classes.keyLabel, seconds: entry.ability.cooldown })}
              </h3>
              <p className="class-card__ability">
                <strong>{t(entry.ability.label)}</strong> : {t(entry.ability.description)}
              </p>

              <h3 className="mono muted class-card__section">{t('ÉQUIPEMENT DE PRÉDILECTION')}</h3>
              <p className="class-card__signature">{entry.signature.map((name) => itemLabel(config, name)).join(' · ')}</p>

              <button
                className="btn btn--primary btn--small cut-s class-card__select"
                disabled={selected || !menu.inSafe || waiting > 0}
                onClick={() => actions.selectClass(entry.id)}
              >
                {selected ? t('Classe actuelle') : t('Choisir')}
              </button>
            </Panel>
          );
        })}
      </div>
    </>
  );
}
