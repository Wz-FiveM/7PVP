import { useEffect, useRef, useState, type KeyboardEvent } from 'react';
import { useGame } from '../../store/GameContext';
import './chat.css';

/** Durée d'affichage des messages après le dernier reçu, chat fermé */
const VISIBLE_DURATION = 10000;
/** Messages affichés chat fermé / ouvert */
const CLOSED_LINES = 6;
const OPEN_LINES = 14;
const MAX_LENGTH = 200;

/** Chat du mode en cours : T pour écrire, Entrée pour envoyer, Échap pour fermer. */
export function Chat() {
  const { state, actions } = useGame();
  const { open, messages } = state.chat;
  const [recent, setRecent] = useState(false);
  const [text, setText] = useState('');
  const history = useRef<string[]>([]);
  const historyIndex = useRef(-1);
  const inputRef = useRef<HTMLInputElement>(null);
  const listRef = useRef<HTMLUListElement>(null);

  // Nouveau message : le chat s'affiche quelques secondes
  const lastId = messages[messages.length - 1]?.id;
  useEffect(() => {
    if (lastId === undefined) return;
    setRecent(true);
    const timer = window.setTimeout(() => setRecent(false), VISIBLE_DURATION);
    return () => window.clearTimeout(timer);
  }, [lastId]);

  useEffect(() => {
    if (open) {
      setText('');
      historyIndex.current = -1;
      inputRef.current?.focus();
    }
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

  const onKeyDown = (event: KeyboardEvent<HTMLInputElement>) => {
    // Le chat garde ses touches pour lui (pas de fermeture du menu, etc.)
    event.stopPropagation();
    if (event.key === 'Enter') {
      event.preventDefault();
      send();
    } else if (event.key === 'Escape') {
      event.preventDefault();
      actions.closeChat();
    } else if (event.key === 'ArrowUp' || event.key === 'ArrowDown') {
      event.preventDefault();
      const step = event.key === 'ArrowUp' ? 1 : -1;
      const next = Math.min(history.current.length - 1, Math.max(-1, historyIndex.current + step));
      historyIndex.current = next;
      setText(next >= 0 ? history.current[next] : '');
    }
  };

  return (
    <div className={open ? 'chat chat--open' : 'chat'}>
      <ul ref={listRef} className="chat__messages" style={{ maxHeight: `${OPEN_LINES * 1.6}rem` }}>
        {visible.map((message) => (
          <li key={message.id} className={`chat__line chat__line--${message.kind}`}>
            {message.kind === 'player' ? (
              <>
                <span className="chat__author">{message.author}</span>
                <span className="chat__text">{message.text}</span>
              </>
            ) : (
              <span className="chat__text">{message.text}</span>
            )}
          </li>
        ))}
      </ul>
      {open && (
        <div className="chat__input-row cut-s">
          <span className="mono chat__prompt">&gt;</span>
          <input
            ref={inputRef}
            className="chat__input"
            value={text}
            maxLength={MAX_LENGTH}
            placeholder="Message · /commande"
            onChange={(event) => setText(event.target.value)}
            onKeyDown={onKeyDown}
            onBlur={() => window.setTimeout(() => inputRef.current?.focus(), 0)}
          />
          <span className="mono chat__count">{MAX_LENGTH - text.length}</span>
        </div>
      )}
    </div>
  );
}
