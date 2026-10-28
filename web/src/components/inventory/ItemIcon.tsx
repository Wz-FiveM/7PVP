import { useState } from 'react';
import { useGame } from '../../store/GameContext';
import type { ItemType } from '../../types/game';
import { Icon, itemIconName } from '../icons/Icon';

/** Images déjà connues comme absentes : évite de les redemander à chaque rendu. */
const missingImages = new Set<string>();

interface ItemIconProps {
  name: string;
  type: ItemType;
}

/** Image `web/public/items/<name>.png` si elle existe, sinon icône au trait selon le type. */
export function ItemIcon({ name, type }: ItemIconProps) {
  // Certaines images ne portent pas le nom de l'objet (véhicules : image du modèle)
  const file = useGame().state.config.items[name]?.image ?? name;
  const [missing, setMissing] = useState(() => missingImages.has(file));

  if (missing) {
    return (
      <span className={`item-icon item-icon--${type}`}>
        <Icon name={itemIconName(name, type)} size={40} strokeWidth={1.3} />
      </span>
    );
  }

  return (
    <img
      className="item-icon"
      src={`./items/${file}.png`}
      alt=""
      draggable={false}
      onError={() => {
        missingImages.add(file);
        setMissing(true);
      }}
    />
  );
}
