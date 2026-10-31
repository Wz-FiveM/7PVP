import { useMemo, useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCatalog, CodProfile } from '../../types/cod';
import { BracketButton, prestigeUrl, RankBadge, WeaponImage } from './CodParts';

interface CodPrestigeTabProps {
  profile: CodProfile;
  catalog: CodCatalog;
  /** en recherche de partie : le serveur refuse le Prestige */
  searching: boolean;
  onProfile: (profile: CodProfile) => void;
}

/** Prestige : insignes et passage au niveau suivant à gauche, déblocages permanents à droite. */
export function CodPrestigeTab({ profile, catalog, searching, onProfile }: CodPrestigeTabProps) {
  useT();
  const { actions } = useGame();
  const [confirming, setConfirming] = useState(false);
  const [busy, setBusy] = useState(false);
  const [ceremony, setCeremony] = useState<number | null>(null);
  const next = profile.prestige + 1;
  const finished = profile.prestige >= catalog.maxPrestige;
  const progress = profile.xpNeeded > 0 ? ((profile.rank - 1 + profile.xpInto / profile.xpNeeded) / (profile.maxRank - 1)) * 100 : 100;

  const enter = async () => {
    setBusy(true);
    const result = await codApi.enterPrestige(profile);
    setBusy(false);
    setConfirming(false);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.profile) onProfile(result.profile);
    if (result?.ok && result.profile) setCeremony(result.profile.prestige);
  };

  return (
    <>
      <section className="cod-column">
        <span className="cod-label">{t('Prestige {level} sur {max}', { level: profile.prestige, max: catalog.maxPrestige })}</span>
        <ul className="cod-prestige__ladder">
          {Array.from({ length: catalog.maxPrestige }, (_, index) => {
            const level = index + 1;
            return (
              <li
                key={level}
                className={[
                  'cod-prestige__step',
                  level <= profile.prestige && 'cod-prestige__step--owned',
                  level === profile.prestige && 'cod-prestige__step--current',
                ].filter(Boolean).join(' ')}
                title={t('Prestige {level}', { level })}
              >
                <img src={prestigeUrl(level)} alt="" draggable={false} />
                <span>{level}</span>
              </li>
            );
          })}
        </ul>

        <div className="cod-prestige__rank">
          <RankBadge rank={profile.rank} prestige={profile.prestige} size={56} />
          <div className="cod-prestige__rank-text">
            <span className="cod-label">{t('Rang {rank} sur {max}', { rank: profile.rank, max: profile.maxRank })}</span>
            <span className="cod-xpbar"><span style={{ width: `${progress}%` }} /></span>
          </div>
        </div>

        {finished
          ? <p className="cod-text">{t('Tu as atteint le dernier Prestige.')}</p>
          : (
            <ul className="cod-prestige__rules">
              <li>{t('Tu repars du rang 1 : armes, atouts et séries se rebloquent.')}</li>
              <li>{t('Tu gardes tes statistiques, ta carte de joueur et tes déblocages permanents.')}</li>
              <li>{t('Tu gagnes l\'insigne, la bannière et l\'emblème du Prestige {level}, et {count} jeton(s).', { level: next, count: catalog.prestigeTokens })}</li>
            </ul>
          )}

        <div className="cod-column__foot">
          {!finished && !profile.canPrestige && (
            <p className="cod-text">{t('Atteins le rang {rank} pour passer en Prestige.', { rank: profile.maxRank })}</p>
          )}
          {profile.canPrestige && searching && (
            <p className="cod-text">{t('Annule ta recherche de partie avant de passer en Prestige.')}</p>
          )}
          {profile.canPrestige && !confirming && (
            <BracketButton onClick={() => setConfirming(true)} disabled={searching}>
              {t('Passer en Prestige {level}', { level: next })}
            </BracketButton>
          )}
          {profile.canPrestige && confirming && (
            <>
              <p className="cod-prestige__warning">{t('Ce choix est définitif. Ton rang repart de 1.')}</p>
              <div className="cod-column__foot--row cod-prestige__confirm">
                <BracketButton onClick={enter} disabled={busy || searching} danger>{t('Confirmer')}</BracketButton>
                <BracketButton onClick={() => setConfirming(false)} disabled={busy}>{t('Annuler')}</BracketButton>
              </div>
            </>
          )}
        </div>
      </section>

      <PermanentShop profile={profile} catalog={catalog} onProfile={onProfile} />

      {ceremony !== null && <PrestigeCeremony level={ceremony} onClose={() => setCeremony(null)} />}
    </>
  );
}

interface ShopEntry {
  id: string;
  label: string;
  rank: number;
  description?: string;
  weapon: boolean;
}

function PermanentShop({ profile, catalog, onProfile }: Omit<CodPrestigeTabProps, 'searching'>) {
  useT();
  const { actions } = useGame();
  const [selected, setSelected] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  // Ce qui est disponible dès le rang 1 n'a pas besoin de jeton
  const groups = useMemo(() => {
    const weapons = (list: typeof catalog.primary): ShopEntry[] =>
      list.filter((entry) => entry.rank > 1).map((entry) => ({ id: entry.id, label: entry.label, rank: entry.rank, weapon: true }));
    const others = (list: typeof catalog.perks | typeof catalog.streaks): ShopEntry[] =>
      list.filter((entry) => entry.rank > 1).map((entry) => ({ id: entry.id, label: entry.label, rank: entry.rank, description: entry.description, weapon: false }));
    return [
      { label: 'Armes principales', entries: weapons(catalog.primary) },
      { label: 'Armes secondaires', entries: weapons(catalog.secondary) },
      { label: 'Équipement', entries: weapons(catalog.equipment) },
      { label: 'Équipement tactique', entries: weapons(catalog.tactical) },
      { label: 'Atouts', entries: others(catalog.perks) },
      { label: 'Séries', entries: others(catalog.streaks) },
    ];
  }, [catalog]);
  const chosen = groups.flatMap((group) => group.entries).find((entry) => entry.id === selected);

  const spend = async () => {
    if (!chosen) return;
    setBusy(true);
    const result = await codApi.unlockPermanent(chosen.id, profile);
    setBusy(false);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.profile) onProfile(result.profile);
    if (result?.ok) setSelected(null);
  };

  return (
    <section className="cod-column cod-column--right cod-column--scroll">
      <span className="cod-label">{t('Déblocages permanents')}</span>
      <div className="cod-prestige__tokens">
        <span className="cod-prestige__token-count">{profile.tokens}</span>
        <span className="cod-text">{t('Un jeton garde un choix débloqué à tous tes prochains Prestiges. Chaque Prestige en rapporte {count}.', { count: catalog.prestigeTokens })}</span>
      </div>
      <ul className="cod-options">
        {groups.map((group) => group.entries.map((entry, index) => {
          const kept = profile.permanent.includes(entry.id);
          return (
            <li key={entry.id}>
              {index === 0 && <span className="cod-options__group">{t(group.label)}</span>}
              <button
                className={['cod-option', entry.id === selected && 'cod-option--active'].filter(Boolean).join(' ')}
                disabled={kept || profile.tokens < 1}
                onClick={() => setSelected(entry.id)}
              >
                {entry.weapon && <WeaponImage id={entry.id} />}
                <span className="cod-option__text">
                  <span>{t(entry.label)}</span>
                  {entry.description && <span className="cod-list__hint">{t(entry.description)}</span>}
                </span>
                {kept
                  ? <span className="cod-prestige__kept">{t('GARDÉ')}</span>
                  : <span className="cod-prestige__needs">{t('RANG {rank}', { rank: entry.rank })}</span>}
              </button>
            </li>
          );
        }))}
      </ul>
      <div className="cod-column__foot">
        <BracketButton onClick={spend} disabled={!chosen || busy || profile.tokens < 1}>
          {chosen ? t('Garder pour toujours : {name}', { name: t(chosen.label) }) : t('Choisis ce que tu veux garder')}
        </BracketButton>
      </div>
    </section>
  );
}

/** Le nouvel insigne, en grand, juste après le passage en Prestige. */
function PrestigeCeremony({ level, onClose }: { level: number; onClose: () => void }) {
  useT();
  return (
    <div className="cod-prestige-up">
      <div className="cod-prestige-up__glow" />
      <img className="cod-prestige-up__insignia" src={prestigeUrl(level)} alt="" draggable={false} />
      <h2 className="cod-title cod-prestige-up__title">{t('Prestige {level}', { level })}</h2>
      <span className="cod-subtitle">{t('Nouvel insigne, nouvelle bannière et nouvel emblème débloqués')}</span>
      <BracketButton onClick={onClose}>{t('Continuer')}</BracketButton>
    </div>
  );
}
