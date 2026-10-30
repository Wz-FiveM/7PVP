import { useState } from 'react';
import { codApi } from '../../api/codApi';
import { t, useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { CodCardAsset, CodCatalog, CodProfile } from '../../types/cod';
import { BracketButton } from './CodParts';
import { bannerUrl, CodPlayerCard, emblemUrl } from './CodPlayerCard';

const TAG_FILTER = /[^A-Za-z0-9\-_!.]/g;

interface PlayerCardTabProps {
  profile: CodProfile;
  catalog: CodCatalog;
  onProfile: (profile: CodProfile) => void;
}

/** Personnalisation de la carte : bannières à gauche avec l'aperçu, tag et emblèmes à droite. */
export function CodPlayerCardTab({ profile, catalog, onProfile }: PlayerCardTabProps) {
  useT();
  const { actions } = useGame();
  const [draft, setDraft] = useState(profile.card);
  const dirty = JSON.stringify(draft) !== JSON.stringify(profile.card);
  const bannerLabel = catalog.banners.find((entry) => entry.id === draft.banner)?.label ?? '';
  const emblemLabel = catalog.emblems.find((entry) => entry.id === draft.emblem)?.label ?? '';

  const save = async () => {
    const result = await codApi.savePlayerCard(draft);
    if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    if (result?.profile) onProfile(result.profile);
  };

  return (
    <>
      <section className="cod-column cod-column--wide">
        <span className="cod-label">{t('Aperçu')}</span>
        <CodPlayerCard card={{ ...draft, name: profile.name, rank: profile.rank, prestige: profile.prestige }} />
        <span className="cod-pcard-tab__names">{t(bannerLabel)} · {t(emblemLabel)}</span>

        <span className="cod-label">{t('Bannière')}</span>
        <AssetGrid
          kind="banner"
          assets={catalog.banners}
          selected={draft.banner}
          profile={profile}
          onSelect={(banner) => setDraft({ ...draft, banner })}
        />
        <div className="cod-column__foot">
          <BracketButton onClick={save} disabled={!dirty}>{t('Enregistrer')}</BracketButton>
        </div>
      </section>

      <section className="cod-column cod-column--right">
        <span className="cod-label">{t('Tag de clan ({count} caractères maximum)', { count: catalog.tagLength })}</span>
        <input
          className="cod-input"
          value={draft.tag}
          maxLength={catalog.tagLength}
          spellCheck={false}
          placeholder={t('Aucun tag')}
          onChange={(event) => setDraft({ ...draft, tag: event.target.value.replace(TAG_FILTER, '') })}
        />
        <span className="cod-label">{t('Emblème')}</span>
        <AssetGrid
          kind="emblem"
          assets={catalog.emblems}
          selected={draft.emblem}
          profile={profile}
          onSelect={(emblem) => setDraft({ ...draft, emblem })}
        />
      </section>
    </>
  );
}

interface AssetGridProps {
  kind: 'banner' | 'emblem';
  assets: CodCardAsset[];
  selected: string;
  profile: CodProfile;
  onSelect: (id: string) => void;
}

/** Dessins disponibles, du premier débloqué au dernier ; ceux au-dessus du niveau du joueur restent visibles. Passer en Prestige demande le rang maximum : les dessins à rang restent acquis ensuite. */
function AssetGrid({ kind, assets, selected, profile, onSelect }: AssetGridProps) {
  useT();
  return (
    <ul className={`cod-pcard-grid cod-pcard-grid--${kind}`}>
      {assets.map((asset) => {
        const needsPrestige = (asset.prestige ?? 0) > profile.prestige;
        const needsRank = profile.prestige === 0 && asset.rank > profile.rank;
        const locked = needsPrestige || needsRank;
        return (
          <li key={asset.id}>
            <button
              className={[
                'cod-pcard-grid__item',
                asset.id === selected && 'cod-pcard-grid__item--active',
                locked && 'cod-pcard-grid__item--locked',
              ].filter(Boolean).join(' ')}
              title={t(asset.label)}
              disabled={locked}
              onClick={() => onSelect(asset.id)}
            >
              <img src={kind === 'banner' ? bannerUrl(asset.id) : emblemUrl(asset.id)} alt="" draggable={false} />
              {locked && (
                <span className="cod-pcard-grid__rank">
                  {needsPrestige ? t('PRESTIGE {level}', { level: asset.prestige ?? 0 }) : t('RANG {rank}', { rank: asset.rank })}
                </span>
              )}
            </button>
          </li>
        );
      })}
    </ul>
  );
}
