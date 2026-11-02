import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { entriesOf, itemLabel } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';

/** Sets d'équipement, chez le banquier : enregistrer le sac, puis le ressortir des coffres en un clic. */
export function LoadoutSetsSection() {
  const t = useT();
  const { state, actions } = useGame();
  const { player, config } = state;
  if (!player) return null;
  const sets = player.loadoutSets ?? [];

  return (
    <section className="container container--stash">
      <SectionTitle
        title={t('Sets d\'équipement')}
        icon={<Icon name="inventory" size={15} strokeWidth={2.4} className="stash-icon" />}
      />
      <p className="muted inventory__help">{t('Un set sort des coffres ce qui te manque. Il n\'enregistre que ton sac, sans l\'argent.')}</p>
      {sets.map((set, index) => {
        const slot = index + 1;
        return (
          <div key={slot} className="loadout-set">
            <span className="label">{t('Set {slot}', { slot })}</span>
            <p className="loadout-set__items">
              {set
                ? entriesOf(set).map(([name, count]) => `${count} x ${itemLabel(config, name)}`).join(' · ')
                : t('Emplacement vide.')}
            </p>
            <div className="loadout-set__actions">
              <button className="btn btn--primary btn--small cut-s" disabled={!set} onClick={() => actions.loadoutSetApply(slot)}>
                {t('Sortir du coffre')}
              </button>
              <button className="btn btn--small cut-s" onClick={() => actions.loadoutSetSave(slot)}>
                {t('Enregistrer mon sac')}
              </button>
              {set && (
                <button className="btn btn--small cut-s" onClick={() => actions.loadoutSetClear(slot)}>
                  {t('Effacer')}
                </button>
              )}
            </div>
          </div>
        );
      })}
    </section>
  );
}
