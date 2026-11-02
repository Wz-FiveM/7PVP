import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import { formatMoney } from '../../utils/format';
import { itemLabel } from '../../utils/inventory';
import { QuantityModal } from './QuantityModal';

interface BuyModalProps {
  item: string;
  /** contenu d'un lot */
  count: number;
  /** prix d'un lot */
  price: number;
  /** lots achetables */
  max: number;
  onConfirm: (lots: number) => void;
  onCancel: () => void;
}

/** Choix du nombre de lots à acheter auprès d'un PNJ : part de 1, le bouton donne le prix total. */
export function BuyModal({ item, count, price, max, onConfirm, onCancel }: BuyModalProps) {
  const t = useT();
  const { state } = useGame();
  const note = count > 1
    ? t('Lot de {count} : {price}', { count, price: formatMoney(price) })
    : t('{price} / unité', { price: formatMoney(price) });

  return (
    <QuantityModal
      title={itemLabel(state.config, item)}
      note={note}
      max={Math.max(1, max)}
      initial={1}
      confirmLabel={(lots) => t('Acheter · {price}', { price: formatMoney(price * lots) })}
      onConfirm={onConfirm}
      onCancel={onCancel}
    />
  );
}
