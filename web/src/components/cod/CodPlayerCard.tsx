import type { CodPlayerCardData } from '../../types/cod';
import './codPlayerCard.css';

export const bannerUrl = (id: string) => `./cod/banners/${id}.svg`;
export const emblemUrl = (id: string) => `./cod/emblems/${id}.svg`;

interface CodPlayerCardProps {
  card: CodPlayerCardData;
  /** petit texte au-dessus de la carte (« Éliminé », « Tué par ») */
  label?: string;
  /** version basse, pour les listes de joueurs */
  compact?: boolean;
}

/** Carte de joueur : bannière en fond, emblème à gauche, pseudo, tag de clan et rang. */
export function CodPlayerCard({ card, label, compact }: CodPlayerCardProps) {
  return (
    <div className={compact ? 'cod-pcard cod-pcard--compact' : 'cod-pcard'}>
      {label && <span className="cod-pcard__label">{label}</span>}
      <div className="cod-pcard__banner" style={{ backgroundImage: `url("${bannerUrl(card.banner)}")` }}>
        <img className="cod-pcard__emblem" src={emblemUrl(card.emblem)} alt="" draggable={false} />
        <div className="cod-pcard__text">
          <span className="cod-pcard__name">{card.name}</span>
          <span className="cod-pcard__meta">
            {card.tag && <span>[{card.tag}]</span>}
            <span className="cod-pcard__rank">
              <svg viewBox="0 0 24 24" aria-hidden="true"><path d="M12 1.5 15.2 8.6 23 9.4 17.2 14.6 18.8 22.3 12 18.4 5.2 22.3 6.8 14.6 1 9.4 8.8 8.6Z" /></svg>
              {card.rank}
            </span>
          </span>
        </div>
      </div>
    </div>
  );
}
