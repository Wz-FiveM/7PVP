import { useState, type CSSProperties } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { KillfeedEntry } from '../../types/game';
import { Icon } from '../icons/Icon';
import { ItemIcon } from '../inventory/ItemIcon';
import '../inventory/inventory.css';
import { ColoredName } from '../ui/ColoredName';

/** Images d'armes introuvables : la ligne affiche l'icône de repli sans les redemander. */
const missingImages = new Set<string>();

/**
 * Silhouette de l'arme (feed du mode CoD) : l'image de l'objet sert de masque, remplie d'une couleur unie.
 * L'adresse est absolue : un url() relatif passé par une variable CSS serait résolu depuis
 * la feuille de style (build/assets/), où le dossier items n'existe pas.
 */
export function WeaponSilhouette({ weapon }: { weapon?: string }) {
  const file = useGame().state.config.items[weapon ?? '']?.image ?? weapon;
  const [missing, setMissing] = useState(() => !file || missingImages.has(file));

  if (!file || missing) return <Icon name="crosshair" size={14} strokeWidth={2} className="killfeed__fallback" />;
  const src = new URL(`./items/${file}.png`, document.baseURI).href;
  return (
    <span className="killfeed__weapon" style={{ '--weapon': `url("${src}")` } as CSSProperties}>
      {/* Sonde invisible : détecte une image absente pour passer à l'icône de repli */}
      <img
        src={src}
        alt=""
        hidden
        onError={() => {
          missingImages.add(file);
          setMissing(true);
        }}
      />
    </span>
  );
}

/** Une ligne du killfeed : tueur, image de l'arme (celle de l'inventaire), tir à la tête, victime. */
export function KillfeedRow({ item }: { item: KillfeedEntry }) {
  const t = useT();
  const { state } = useGame();
  const me = state.player?.source;
  const mates = new Set(state.group?.members.map((member) => member.id) ?? []);
  const background = state.config.killfeedBackgrounds?.find((entry) => entry.id === item.background)?.css;

  const nameClass = (id: number | undefined, base: string) => {
    if (id !== undefined && id === me) return `${base} killfeed__name--me`;
    if (id !== undefined && mates.has(id)) return `${base} killfeed__name--mate`;
    return base;
  };

  const rowClass = () => {
    if (me === undefined) return 'killfeed__item';
    if (item.killerId === me) return 'killfeed__item killfeed__item--kill';
    if (item.victimId === me) return 'killfeed__item killfeed__item--death';
    return 'killfeed__item';
  };

  return (
    <div className={rowClass()} style={{ background }}>
      {item.killer && (
        <span className={nameClass(item.killerId, 'killfeed__killer')}>
          <ColoredName text={item.killer} colors={item.killerColors} />
        </span>
      )}
      {item.reason === 'disconnect' ? (
        <span className="mono killfeed__reason">{t('DÉCO')}</span>
      ) : item.weapon ? (
        <span className="killfeed__image">
          <ItemIcon name={item.weapon} type="weapon" />
        </span>
      ) : (
        <Icon name="crosshair" size={14} strokeWidth={2} className="killfeed__fallback" />
      )}
      {item.headshot && <Icon name="crosshair" size={15} strokeWidth={2.2} className="killfeed__headshot" />}
      <span className={nameClass(item.victimId, 'killfeed__victim')}>
        <ColoredName text={item.victim} colors={item.victimColors} />
      </span>
    </div>
  );
}

/** Killfeed (haut droite) */
export function Killfeed() {
  const { state } = useGame();

  return (
    <div className="killfeed">
      {state.killfeed.map((item) => (
        <KillfeedRow key={item.id} item={item} />
      ))}
    </div>
  );
}
