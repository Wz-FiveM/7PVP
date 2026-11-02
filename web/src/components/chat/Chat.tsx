import { useEffect, useLayoutEffect, useMemo, useRef, useState, type KeyboardEvent } from 'react';
import { useT } from '../../i18n';
import { useGame } from '../../store/GameContext';
import type { ChatMessage } from '../../types/game';
import { ColoredName } from '../ui/ColoredName';
import { ChatSuggestions } from './ChatSuggestions';
import { applyRow, ghostText, mentionParts, splitAuthor, suggest } from './suggestions';
import './chat.css';

/** Durée d'affichage des messages après le dernier reçu, chat fermé */
const VISIBLE_DURATION = 10000;
/** Messages affichés chat fermé / ouvert */
const CLOSED_LINES = 6;
const OPEN_LINES = 14;
const MAX_LENGTH = 200;

function clock(seconds: number): string {
  const date = new Date(seconds * 1000);
  return `${String(date.getHours()).padStart(2, '0')}:${String(date.getMinutes()).padStart(2, '0')}`;
}

function ChatLine({ message, open, selfName }: { message: ChatMessage; open: boolean; selfName?: string }) {
  const parts = message.kind === 'player' ? mentionParts(message.text, selfName) : [];
  const mentioned = parts.some((part) => part.self);
  const author = splitAuthor(message.author ?? '', message.name);

  return (
    <li className={`chat__line chat__line--${message.kind}${mentioned ? ' chat__line--mentioned' : ''}`}>
      {open && <span className="chat__time mono">{clock(message.time)}</span>}
      {message.kind === 'player' ? (
        <>
          {author.title && <span className="chat__title">{author.title}</span>}
          {author.crew && <span className="chat__crew mono">{author.crew}</span>}
          <span className="chat__author">
            <ColoredName text={author.name} colors={message.colors} />
          </span>
          <span className="chat__text">
            {parts.map((part, index) => (
              <span key={index} className={part.mention ? 'chat__mention' : undefined}>
                {part.text}
              </span>
            ))}
          </span>
        </>
      ) : (
        <span className="chat__text">{message.text}</span>
      )}
    </li>
  );
}

/**
 * Chat du mode en cours : T pour écrire, Entrée pour envoyer, Échap pour fermer.
 * Pas de curseur en jeu : les suggestions se parcourent au clavier (↑↓, Tab pour compléter).
 */
export function Chat() {
  const t = useT();
  const { state, actions } = useGame();
  const { open, messages, commands, players } = state.chat;
  const [recent, setRecent] = useState(false);
  const [text, setText] = useState('');
  const [selected, setSelected] = useState(0);
  /** Le joueur a choisi une ligne avec ↑↓ : Entrée la complète même si elle ne commence pas par le texte */
  const [moved, setMoved] = useState(false);
  const [error, setError] = useState('');
  /** Texte repris de l'historique : pas de suggestions, ↑↓ continue dans l'historique */
  const [browsing, setBrowsing] = useState(false);
  const history = useRef<string[]>([]);
  const historyIndex = useRef(-1);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);

  const suggestions = useMemo(
    () => suggest(browsing ? '' : text, commands, players),
    [browsing, text, commands, players],
  );
  const { rows } = suggestions;
  const current = Math.min(selected, Math.max(0, rows.length - 1));
  const row = rows[current];

  const changeText = (value: string) => {
    setText(value);
    setSelected(0);
    setMoved(false);
    setError('');
    setBrowsing(false);
  };

  // Nouveau message : le chat s'affiche quelques secondes
  const lastId = messages[messages.length - 1]?.id;
  useEffect(() => {
    if (lastId === undefined) return;
    setRecent(true);
    const timer = window.setTimeout(() => setRecent(false), VISIBLE_DURATION);
    return () => window.clearTimeout(timer);
  }, [lastId]);

  // Avant l'affichage, et à la fermeture aussi : le texte précédent ne réapparaît jamais à la réouverture
  useLayoutEffect(() => {
    changeText('');
    historyIndex.current = -1;
    if (open) inputRef.current?.focus();
  }, [open]);

  // Alt seul active le « menu » de la fenêtre : le champ perd le clavier et le chat reste bloqué.
  // On l'intercepte avant tout le monde (capture) et on rend le clavier au champ s'il le perd.
  useEffect(() => {
    if (!open) return;
    const blockAlt = (event: globalThis.KeyboardEvent) => {
      if (event.key === 'Alt') event.preventDefault();
    };
    const refocus = () => window.setTimeout(() => inputRef.current?.focus(), 0);
    window.addEventListener('keydown', blockAlt, true);
    window.addEventListener('keyup', blockAlt, true);
    window.addEventListener('focus', refocus);
    return () => {
      window.removeEventListener('keydown', blockAlt, true);
      window.removeEventListener('keyup', blockAlt, true);
      window.removeEventListener('focus', refocus);
    };
  }, [open]);

  // Toujours sur le dernier message
  useEffect(() => {
    listRef.current?.scrollTo({ top: listRef.current.scrollHeight });
  }, [messages.length, open]);

  if (!open && !recent) return null;

  const visible = messages.slice(-(open ? OPEN_LINES * 3 : CLOSED_LINES));

  const send = () => {
    const value = text.trim();
    if (value) {
      history.current = [value, ...history.current.filter((h) => h !== value)].slice(0, 20);
    }
    actions.sendChat(value);
  };

  const complete = () => {
    if (row) changeText(applyRow(text, suggestions, row));
  };

  /** Entrée : complète une commande inachevée, refuse s'il manque un argument, sinon envoie. */
  const submit = () => {
    if (suggestions.mode === 'commands') {
      const { query } = suggestions;
      const exact = rows.find((candidate) => candidate.key === query)?.command;
      if (exact) {
        const missing = exact.args.find((arg) => arg.required);
        if (missing) {
          changeText(`/${exact.name} `);
          setError(t('Il manque {arg}.', { arg: missing.label }));
          return;
        }
      } else if (row && (moved || (query && row.key.startsWith(query)))) {
        return complete();
      }
    }
    if (suggestions.mode === 'args' && suggestions.missing.length) {
      return setError(t('Il manque {arg}.', { arg: suggestions.missing[0].label }));
    }
    send();
  };

  const browseHistory = (step: number) => {
    const next = Math.min(history.current.length - 1, Math.max(-1, historyIndex.current + step));
    historyIndex.current = next;
    setText(next >= 0 ? history.current[next] : '');
    setBrowsing(next >= 0);
    setError('');
  };

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    // Le chat garde ses touches pour lui (pas de fermeture du menu, etc.)
    event.stopPropagation();
    if (event.key === 'Enter') {
      event.preventDefault();
      submit();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      actions.closeChat();
    } else if (event.key === 'Tab') {
      event.preventDefault();
      complete();
    } else if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      event.preventDefault();
      if (rows.length) {
        const step = event.key === 'ArrowDown' ? 1 : -1;
        setSelected((current + step + rows.length) % rows.length);
        setMoved(true);
        setError('');
      } else {
        browseHistory(event.key === 'ArrowUp' ? 1 : -1);
      }
    }
  };

  const isCommand = text.startsWith('/');
  const ghost = text ? ghostText(suggestions, row) : t('Message · /commande · @joueur');

  return (
    <div className={open ? 'chat chat--open' : 'chat'}>
      <div className="chat__history">
        {open && <span className="label chat__room">{t('Salon du mode')}</span>}
        <ul ref={listRef} className="chat__messages" style={{ maxHeight: `${OPEN_LINES * 1.6}rem` }}>
          {visible.map((message) => (
            <ChatLine key={message.id} message={message} open={open} selfName={state.player?.name} />
          ))}
        </ul>
      </div>
      {open && (
        <>
          <div className="chat__input-row cut-s">
            <span className="mono chat__prompt">&gt;</span>
            <div className={isCommand ? 'chat__field chat__field--command' : 'chat__field'}>
              <div className="chat__ghost" aria-hidden="true">
                <span className="chat__ghost-typed">{text}</span>
                {ghost}
              </div>
              <input
                ref={inputRef}
                className="chat__input"
                value={text}
                maxLength={MAX_LENGTH}
                autoComplete="off"
                spellCheck={false}
                aria-label={t('Message · /commande · @joueur')}
                onChange={(event) => changeText(event.target.value)}
                onKeyDown={onKeyDown}
                onBlur={() => window.setTimeout(() => inputRef.current?.focus(), 0)}
              />
            </div>
            <span className="mono chat__count">{MAX_LENGTH - text.length}</span>
          </div>
          {suggestions.mode !== 'none' && <ChatSuggestions suggestions={suggestions} selected={current} error={error} />}
        </>
      )}
    </div>
  );
}
