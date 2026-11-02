import { useT } from '../../i18n';
import type { SuggestionRow, Suggestions } from './suggestions';

/** Lignes affichées à la fois : la liste suit la sélection, le clavier est le seul moyen de la parcourir. */
const VISIBLE_ROWS = 6;

/** Syntaxe de la commande : l'argument en cours en surbrillance. */
function Signature({ suggestions, selected }: { suggestions: Suggestions; selected?: SuggestionRow }) {
  const command = suggestions.mode === 'args' ? suggestions.command : selected?.command;
  if (!command?.args.length) return null;
  const active = suggestions.mode === 'args' ? suggestions.argIndex : -1;
  return (
    <p className="chat__signature mono">
      <span className="chat__signature-name">/{command.name}</span>
      {command.args.map((arg, index) => (
        <span
          key={arg.label + index}
          className={index === active ? 'chat__signature-arg chat__signature-arg--active' : 'chat__signature-arg'}
        >
          {arg.label}
        </span>
      ))}
    </p>
  );
}

function Key({ label, children }: { label: string; children: string }) {
  return (
    <span className="chat__key">
      <kbd className="mono">{children}</kbd>
      {label}
    </span>
  );
}

/** Liste sous la saisie : commandes, arguments ou joueurs, selon le texte tapé. */
export function ChatSuggestions({
  suggestions,
  selected,
  error,
}: {
  suggestions: Suggestions;
  selected: number;
  error: string;
}) {
  const t = useT();
  const { rows, mode } = suggestions;
  const start = selected >= VISIBLE_ROWS ? selected - VISIBLE_ROWS + 1 : 0;

  let title = t('Arguments');
  if (mode === 'commands') title = t('Commandes');
  if (mode === 'mention' || (mode === 'args' && suggestions.arg?.players)) title = t('Joueurs du mode');

  let hint = '';
  if (mode === 'args') {
    hint = suggestions.arg?.hint ?? (suggestions.missing.length ? '' : t('Entrée pour envoyer.'));
  }

  let empty = '';
  if (!rows.length && mode === 'commands') empty = t('Aucune commande pour « {query} ».', { query: `/${suggestions.query}` });
  if (!rows.length && mode === 'mention') empty = t('Aucun joueur pour « {query} ».', { query: `@${suggestions.query}` });

  return (
    <div className="chat__suggestions">
      <div className="chat__suggestions-head">
        <span className="label">{title}</span>
        {rows.length > 0 && <span className="mono chat__suggestions-count">{selected + 1}/{rows.length}</span>}
      </div>

      <Signature suggestions={suggestions} selected={rows[selected]} />
      {hint && <p className="chat__hint">{hint}</p>}

      {rows.slice(start, start + VISIBLE_ROWS).map((row, index) => (
        <div key={row.key} className={index + start === selected ? 'chat__row chat__row--selected' : 'chat__row'}>
          <span className="chat__row-key mono">
            {row.before}
            <span className="chat__row-match">{row.match}</span>
            {row.after}
          </span>
          <span className="chat__row-description">{row.description}</span>
          {row.command?.admin && <span className="chat__row-badge mono">{t('Admin')}</span>}
          {row.badge && <span className="chat__row-badge mono">{row.badge}</span>}
        </div>
      ))}

      {empty && <p className="chat__hint">{empty}</p>}
      {error && <p className="chat__error">{error}</p>}

      <div className="chat__keys">
        <Key label={t('Compléter')}>Tab</Key>
        <Key label={t('Choisir')}>↑↓</Key>
        <Key label={t('Envoyer')}>{t('Entrée')}</Key>
        <Key label={t('Fermer')}>{t('Échap')}</Key>
      </div>
    </div>
  );
}
