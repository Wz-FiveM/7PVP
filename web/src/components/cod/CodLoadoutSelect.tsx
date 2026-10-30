import { useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import type { CodCatalog, CodCatalogEntry, CodHudState, CodLoadoutData, CodProfile } from '../../types/cod';
import { BracketButton, RankBadge, useSecondsLeft, WeaponImage } from './CodParts';
import { CodStreakIcon } from './CodStreakIcon';

interface CodLoadoutSelectProps {
  data: CodLoadoutData;
  profile: CodProfile;
  catalog: CodCatalog;
  hud: CodHudState | null;
  onProfile: (profile: CodProfile) => void;
}

/** Choix de la classe à l'arrivée dans une partie, sur la vue aérienne de la carte. Sans choix, la classe en cours part. */
export function CodLoadoutSelect({ data, profile, catalog, hud, onProfile }: CodLoadoutSelectProps) {
  useT();
  const [index, setIndex] = useState(profile.selected);
  const seconds = useSecondsLeft(data.seconds, data.at);
  const current = profile.classes[index - 1];

  const pick = async (position: number) => {
    setIndex(position);
    const result = await codApi.selectClass(position);
    if (result?.profile) onProfile(result.profile);
  };
  // Détermination : chaque série demande un kill de moins (CodStreaks.killsNeeded)
  const killsOff = current.perks.includes('hardline') ? 1 : 0;
  const streaks = catalog.streaks
    .filter((streak) => profile.streaks.includes(streak.id))
    .sort((a, b) => a.kills - b.kills);
  const perks = current.perks.map((id) => catalog.perks.find((perk) => perk.id === id));
  const equipment = catalog.equipment.find((entry) => entry.id === current.equipment);

  return (
    <div className="cod-deploy">
      <section className="cod-deploy__side">
        <div className="cod-deploy__crumb">
          {t('Multijoueur')} / {t(hud?.playlist.label ?? '')}
        </div>
        <h1 className="cod-deploy__title">{t('Choix de la classe')}</h1>

        <div className="cod-deploy__portrait">
          {data.portrait
            ? <img src={`https://nui-img/${data.portrait}/${data.portrait}`} alt="" draggable={false} />
            : <RankBadge rank={profile.rank} prestige={profile.prestige} size={72} />}
        </div>
        <div className="cod-deploy__operator">
          <span>{profile.name}</span>
          <span className="cod-deploy__rank">
            {profile.prestige > 0 && `${t('Prestige {level}', { level: profile.prestige })} · `}
            {t('Rang {rank}', { rank: profile.rank })}
          </span>
        </div>

        <ul className="cod-deploy__classes">
          {profile.classes.map((entry, position) => (
            <li key={position}>
              <button
                className={position + 1 === index ? 'cod-deploy__class cod-deploy__class--active' : 'cod-deploy__class'}
                onClick={() => pick(position + 1)}
              >
                {entry.name}
              </button>
            </li>
          ))}
        </ul>

        <div className="cod-deploy__streaks">
          <span className="cod-deploy__streaks-title">{t('Séries')}</span>
          <ul className="cod-deploy__streak-list">
            {streaks.map((streak) => (
              <li key={streak.id} title={t(streak.label)}>
                <CodStreakIcon id={streak.id} />
                <span className="cod-deploy__streak-kills">{streak.kills - killsOff}</span>
              </li>
            ))}
          </ul>
        </div>
      </section>

      <section className="cod-deploy__sheet">
        <div className="cod-deploy__bar">
          <span>{t(hud?.map.label ?? '')} · {t(hud?.map.place ?? '')}</span>
          <span className="cod-deploy__timer">{t('Déploiement dans {seconds} s', { seconds })}</span>
        </div>

        <WeaponRow label="Arme principale" entry={catalog.primary.find((entry) => entry.id === current.primary)} id={current.primary} />
        <WeaponRow label="Arme secondaire" entry={catalog.secondary.find((entry) => entry.id === current.secondary)} id={current.secondary} />

        <div className="cod-deploy__row">
          <div className="cod-deploy__slot cod-deploy__slot--equipment">
            <span className="cod-deploy__label">{t('Équipement')}</span>
            <div className="cod-deploy__art">
              {equipment
                ? <WeaponImage id={equipment.id} />
                : <span className="cod-deploy__value cod-deploy__value--muted">{t('Aucun')}</span>}
            </div>
            {equipment && <span className="cod-deploy__name">{t(equipment.label)} × {equipment.ammo}</span>}
          </div>
          <div className="cod-deploy__cells">
            {perks.map((perk, position) => (
              <div key={position} className="cod-deploy__cell cod-deploy__cell--perk">
                <span className="cod-deploy__label">{t('Atout {tier}', { tier: position + 1 })}</span>
                <span className="cod-deploy__value">{t(perk?.label ?? 'Aucun')}</span>
                {perk && <span className="cod-deploy__hint">{t(perk.description)}</span>}
              </div>
            ))}
          </div>
        </div>

        <div className="cod-deploy__foot">
          <BracketButton onClick={() => codApi.deploy()}>{t('Déployer')}</BracketButton>
        </div>
      </section>
    </div>
  );
}

function WeaponRow({ label, entry, id }: { label: string; entry: CodCatalogEntry | undefined; id: string }) {
  useT();
  return (
    <div className="cod-deploy__row">
      <div className="cod-deploy__slot">
        <span className="cod-deploy__label">{t(label)}</span>
        <div className="cod-deploy__art"><WeaponImage id={id} /></div>
      </div>
      <div className="cod-deploy__cells">
        <div className="cod-deploy__cell">
          <span className="cod-deploy__label">{t('Modèle')}</span>
          <span className="cod-deploy__value">{t(entry?.label ?? id)}</span>
        </div>
        <div className="cod-deploy__cell">
          <span className="cod-deploy__label">{t('Catégorie')}</span>
          <span className="cod-deploy__value">{t(entry?.category ?? '')}</span>
        </div>
        <div className="cod-deploy__cell">
          <span className="cod-deploy__label">{t('Munitions')}</span>
          <span className="cod-deploy__value">{entry?.ammo ?? 0}</span>
        </div>
      </div>
    </div>
  );
}
