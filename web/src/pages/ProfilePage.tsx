import { useEffect, useState } from 'react';
import { gameApi } from '../api/gameApi';
import { KillfeedRow } from '../components/hud/Killfeed';
import { ColoredName } from '../components/ui/ColoredName';
import { Panel } from '../components/ui/Panel';
import { SegmentBar } from '../components/ui/SegmentBar';
import { formatNumber, useT } from '../i18n';
import { useGame } from '../store/GameContext';
import type { ActionResult } from '../types/nui';
import { formatKd, formatMoney, formatPoints } from '../utils/format';
import './pages.css';

/** Lettre sans couleur (NameColors.NONE côté Lua) */
const NO_COLOR = '-';

/**
 * Couleurs du nom, en PvP : on prend une couleur, puis on clique sur les lettres.
 * Rien ne part au serveur avant « Enregistrer » : un envoi par clic ferait des requêtes en rafale.
 */
function NameColorEditor({ name }: { name: string }) {
  const t = useT();
  const { state, actions } = useGame();
  const config = state.config.nameColors;
  const saved = state.player?.nameColor ?? '';
  const [draft, setDraft] = useState(saved);
  const [brush, setBrush] = useState(() => config?.list[0]?.code ?? NO_COLOR);

  useEffect(() => setDraft(saved), [saved]);

  if (!config) return null;
  const letters = Array.from(name).slice(0, config.maxLetters);
  const paint = (codeOf: (current: string, index: number) => string) =>
    setDraft(letters.map((_, index) => codeOf(draft[index] ?? NO_COLOR, index)).join('').replace(/-+$/, ''));

  const save = () => {
    gameApi.selectNameColors(draft).then((result) => {
      if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    });
  };

  return (
    <div className="name-colors">
      <span className="label">{t('Couleurs du nom')}</span>
      <div className="name-colors__list">
        <button
          className={brush === NO_COLOR ? 'name-color name-color--default name-color--on cut-s' : 'name-color name-color--default cut-s'}
          title={t('Par défaut')}
          aria-label={t('Par défaut')}
          aria-pressed={brush === NO_COLOR}
          onClick={() => setBrush(NO_COLOR)}
        />
        {config.list.map((color) => (
          <button
            key={color.code}
            className={brush === color.code ? 'name-color name-color--on cut-s' : 'name-color cut-s'}
            style={{ background: color.hex }}
            title={t(color.label)}
            aria-label={t(color.label)}
            aria-pressed={brush === color.code}
            onClick={() => setBrush(color.code)}
          />
        ))}
      </div>
      <div className="name-colors__letters">
        {letters.map((letter, index) => (
          <button
            key={index}
            className="disp name-letter cut-s"
            style={{ color: config.list.find((color) => color.code === draft[index])?.hex }}
            onClick={() => paint((current, position) => (position === index ? brush : current))}
          >
            {letter.trim() || ' '}
          </button>
        ))}
      </div>
      <div className="name-colors__actions">
        <button className="btn btn--small cut-s" onClick={() => paint(() => brush)}>
          {t('Tout colorier')}
        </button>
        <button className="btn btn--primary btn--small cut-s" disabled={draft === saved} onClick={save}>
          {t('Enregistrer')}
        </button>
      </div>
      <span className="muted name-colors__hint">{t('Choisis une couleur, puis clique sur les lettres de ton nom. Visible sur ton gamertag et dans le killfeed en PvP.')}</span>
    </div>
  );
}

/**
 * Fond du killfeed, en PvP : cliquer sur un fond ne fait que l'essayer sur la ligne d'aperçu.
 * Seul le bouton paie ou équipe, et le serveur décide du paiement.
 */
function KillfeedBackgroundPicker({ name, colors }: { name: string; colors?: string }) {
  const t = useT();
  const { state, actions } = useGame();
  const { player } = state;
  const list = state.config.killfeedBackgrounds;
  const saved = player?.killfeedBackground ?? '';
  const [selected, setSelected] = useState(saved);
  const [busy, setBusy] = useState(false);

  useEffect(() => setSelected(saved), [saved]);

  if (!player || !list?.length) return null;
  const entry = list.find((background) => background.id === selected);
  const owned = !entry || (player.killfeedOwned ?? []).includes(entry.id);
  const short = state.config.shopPoints?.short ? t(state.config.shopPoints.short) : undefined;

  const run = (action: Promise<ActionResult>) => {
    setBusy(true);
    action.then((result) => {
      setBusy(false);
      if (result?.message) actions.notify(result.message, result.ok ? 'success' : 'error');
    });
  };

  return (
    <div className="name-colors">
      <span className="label">{t('Fond du killfeed')}</span>
      <div className="killfeed-preview">
        <KillfeedRow
          item={{
            killer: name,
            killerColors: colors,
            killerId: player.source,
            victim: t('Adversaire'),
            weapon: 'weapon_carbinerifle',
            background: selected,
          }}
        />
      </div>
      <div className="name-colors__list">
        <button
          className={selected === '' ? 'name-color name-color--default name-color--on cut-s' : 'name-color name-color--default cut-s'}
          title={t('Par défaut')}
          aria-label={t('Par défaut')}
          aria-pressed={selected === ''}
          onClick={() => setSelected('')}
        />
        {list.map((background) => (
          <button
            key={background.id}
            className={selected === background.id ? 'name-color name-color--on cut-s' : 'name-color cut-s'}
            style={{ background: background.css }}
            title={t(background.label)}
            aria-label={t(background.label)}
            aria-pressed={selected === background.id}
            onClick={() => setSelected(background.id)}
          />
        ))}
      </div>
      <div className="name-colors__actions killfeed-preview__actions">
        <span className="mono muted">{entry ? t(entry.label) : t('Par défaut')}</span>
        {owned ? (
          <button
            className="btn btn--primary btn--small cut-s"
            disabled={busy || selected === saved}
            onClick={() => run(gameApi.selectKillfeedBackground(selected))}
          >
            {selected === saved ? t('Équipé') : t('Équiper')}
          </button>
        ) : (
          <button
            className="btn btn--primary btn--small cut-s"
            disabled={busy || (player.shopPoints ?? 0) < entry.price}
            onClick={() => run(gameApi.buyKillfeedBackground(entry.id))}
          >
            {t('Acheter : {price}', { price: formatPoints(entry.price, short) })}
          </button>
        )}
      </div>
      <span className="muted name-colors__hint">{t('Ton fond s\'affiche sur tes kills, pour tous les joueurs en PvP. Un fond acheté est gardé pour toujours.')}</span>
    </div>
  );
}

export function ProfilePage() {
  const t = useT();
  const { state } = useGame();
  const { player, config } = state;
  if (!player) return null;

  const pvp = state.mode === 'pvp';
  const displayName = player.displayName ?? player.name;
  // Le label du crew reste sans couleur : les codes commencent après lui
  const labelLetters = Array.from(displayName).length - Array.from(player.name).length;
  const nameColors = pvp && player.nameColor ? NO_COLOR.repeat(labelLetters) + player.nameColor : undefined;
  const levelXp = player.xp % config.xpPerLevel;
  const season = player.season;
  const stats: [string, string | number][] = [
    [t('Kills'), player.kills],
    [t('Morts'), player.deaths],
    ['K/D', formatKd(player.kills, player.deaths)],
    [t('Assistances'), player.assists ?? 0],
    [t('Zombies tués'), player.npcKills],
    [t('Argent total'), formatMoney(player.money)],
    [
      t(config.shopPoints?.label ?? 'Points boutique'),
      formatPoints(player.shopPoints ?? 0, config.shopPoints?.short ? t(config.shopPoints.short) : undefined),
    ],
    [t('XP totale'), formatNumber(player.xp)],
  ];
  if (player.nemeses?.length) stats.push([t('Némésis'), player.nemeses.join(', ')]);
  if (season) {
    stats.push(
      [`${season.label} · ${t('kills')}`, season.kills],
      [`${season.label} · K/D`, formatKd(season.kills, season.deaths)],
      [`${season.label} · ${t('zombies')}`, season.npcKills],
    );
  }

  return (
    <div className="profile">
      <Panel className="profile__card">
        <span className="label">{t('Opérateur')}</span>
        <span className="disp profile__name">
          <ColoredName text={displayName} colors={nameColors} />
        </span>
        <span className="disp profile__level">{t('Niveau {level}', { level: player.level })}</span>
        <SegmentBar value={levelXp} max={config.xpPerLevel} segments={20} color="var(--signal)" height={8} />
        <span className="mono muted profile__xp">
          {t('{xp} / {max} XP avant le niveau {level}', { xp: levelXp, max: config.xpPerLevel, level: player.level + 1 })}
        </span>
        {pvp && <NameColorEditor name={player.name} />}
        {pvp && <KillfeedBackgroundPicker name={displayName} colors={nameColors} />}
      </Panel>

      <div className="stat-grid">
        {stats.map(([label, value]) => (
          <Panel key={label} className="stat">
            <span className="label">{label}</span>
            <span className="mono stat__value">{value}</span>
          </Panel>
        ))}
      </div>
    </div>
  );
}
