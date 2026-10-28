import { useState, type CSSProperties } from 'react';
import { useGame } from '../../store/GameContext';
import type { KillfeedItem } from '../../types/game';
import { Icon } from '../icons/Icon';

/** Images d'armes introuvables : la ligne affiche l'icône de repli sans les redemander. */
const missingImages = new Set<string>();

/**
 * Silhouette de l'arme : l'image de l'objet sert de masque, remplie d'une couleur unie.
 * L'adresse est absolue : un url() relatif passé par une variable CSS serait résolu depuis
 * la feuille de style (build/assets/), où le dossier items n'existe pas.
 */
function WeaponSilhouette({ weapon }: { weapon?: string }) {
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

/** Killfeed (haut droite) : tueur, silhouette de l'arme, tir à la tête, victime. */
export function Killfeed() {
  const { state } = useGame();
  const me = state.player?.source;
  const mates = new Set(state.group?.members.map((member) => member.id) ?? []);

  const nameClass = (id: number | undefined, base: string) => {
    if (id !== undefined && id === me) return `${base} killfeed__name--me`;
    if (id !== undefined && mates.has(id)) return `${base} killfeed__name--mate`;
    return base;
  };

  const rowClass = (item: KillfeedItem) => {
    if (me === undefined) return 'killfeed__item';
    if (item.killerId === me) return 'killfeed__item killfeed__item--kill';
    if (item.victimId === me) return 'killfeed__item killfeed__item--death';
    return 'killfeed__item';
  };

  return (
    <div className="killfeed">
      {state.killfeed.map((item) => (
        <div key={item.id} className={rowClass(item)}>
          {item.killer && <span className={nameClass(item.killerId, 'killfeed__killer')}>{item.killer}</span>}
          {item.reason === 'disconnect' ? (
            <span className="mono killfeed__reason">DÉCO</span>
          ) : (
            <WeaponSilhouette weapon={item.weapon} />
          )}
          {item.headshot && <Icon name="crosshair" size={15} strokeWidth={2.2} className="killfeed__headshot" />}
          <span className={nameClass(item.victimId, 'killfeed__victim')}>{item.victim}</span>
        </div>
      ))}
    </div>
  );
}
