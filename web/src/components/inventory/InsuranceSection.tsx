import { gameApi } from '../../api/gameApi';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';
import { entriesOf, itemLabel } from '../../utils/inventory';
import { Icon } from '../icons/Icon';
import { SectionTitle } from '../menu/SectionTitle';

/** Assurance du sac, chez le banquier : une arme assurée revient au coffre si personne ne la prend. */
export function InsuranceSection() {
  const t = useT();
  const { state, actions } = useGame();
  const { player, config } = state;
  const insurance = player?.insurance;
  if (!insurance) return null;

  const full = insurance.policies.length >= insurance.max;
  const buy = async (item: string) => {
    const result = await gameApi.insuranceBuy(item);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
  };

  return (
    <section className="container container--stash">
      <SectionTitle
        title={t('Assurance')}
        icon={<Icon name="lock" size={15} strokeWidth={2.4} className="stash-icon" />}
      />
      <p className="muted inventory__help">
        {t('Une arme assurée dans ton sac revient au coffre si personne ne la prend sur ton butin. L\'assurance sert une fois, à ta prochaine mort avec cette arme. Un redémarrage du serveur annule ce retour.')}
      </p>
      <div className="loadout-set">
        <span className="label">{t('Assurées : {count} / {max}', { count: insurance.policies.length, max: insurance.max })}</span>
        <p className="loadout-set__items">
          {insurance.policies.length > 0
            ? insurance.policies.map((item) => itemLabel(config, item)).join(' · ')
            : t('Aucune arme assurée.')}
        </p>
      </div>
      <div className="loadout-set__actions">
        {entriesOf(insurance.prices).map(([item, price]) => (
          <button
            key={item}
            className="btn btn--small cut-s"
            disabled={full || (player?.money ?? 0) < price}
            onClick={() => buy(item)}
          >
            {t('Assurer {item} · {price}', { item: itemLabel(config, item), price: formatMoney(price) })}
          </button>
        ))}
      </div>
    </section>
  );
}
