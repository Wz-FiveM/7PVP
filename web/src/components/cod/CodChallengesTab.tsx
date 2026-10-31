import { t, useT } from '../../i18n';
import type { CodChallengeGroup, CodProfile } from '../../types/cod';

/** Temps restant, en jours et heures au-delà d'une journée. */
function formatReset(seconds: number): string {
  const hours = Math.ceil(seconds / 3600);
  return hours < 24 ? t('{hours} h', { hours }) : t('{days} j {hours} h', { days: Math.floor(hours / 24), hours: hours % 24 });
}

function ChallengeList({ title, group, right }: { title: string; group: CodChallengeGroup; right?: boolean }) {
  useT();
  return (
    <section className={right ? 'cod-column cod-column--right' : 'cod-column'}>
      <span className="cod-label">{t(title)}</span>
      <ul className="cod-challenges">
        {group.items.map((item) => {
          const done = item.progress >= item.target;
          return (
            <li key={item.id} className={done ? 'cod-challenge cod-challenge--done' : 'cod-challenge'}>
              <span className="cod-challenge__label">{t(item.label)}</span>
              <span className="cod-xpbar"><span style={{ width: `${(item.progress / item.target) * 100}%` }} /></span>
              <span className="cod-challenge__foot">
                <span>{done ? t('TERMINÉ') : `${item.progress} / ${item.target}`}</span>
                <span className="cod-challenge__xp">+{item.xp} XP</span>
              </span>
            </li>
          );
        })}
      </ul>
      <p className="cod-text">{t('Nouveaux défis dans {time}', { time: formatReset(group.resetIn) })}</p>
    </section>
  );
}

/** Défis du jour à gauche, de la semaine à droite, le personnage reste visible au centre. */
export function CodChallengesTab({ profile }: { profile: CodProfile }) {
  return (
    <>
      <ChallengeList title="Défis du jour" group={profile.challenges.daily} />
      <ChallengeList title="Défis de la semaine" group={profile.challenges.weekly} right />
    </>
  );
}
