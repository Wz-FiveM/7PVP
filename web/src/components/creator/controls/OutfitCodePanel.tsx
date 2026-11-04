import { useRef, useState } from 'react';
import { useT } from '../../../i18n';
import { useCreator } from '../../../store/CreatorProvider';
import type { Appearance } from '../../../types/appearance';

const CODE_LENGTH = 6;

/** Tenue seule (vêtements et accessoires) : le code créé ne vaut que pour la tenue affichée. */
const outfitKey = (appearance: Appearance) => JSON.stringify([appearance.sex, appearance.components, appearance.props]);

/** Code tapé ou collé : majuscules, sans espaces ni tirets. */
const cleanCode = (value: string) => value.toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, CODE_LENGTH);

/** Copie dans le presse-papiers ; l'API récente manque souvent dans le navigateur du jeu. */
async function copyText(text: string, input: HTMLInputElement | null): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    if (!input) return false;
    input.select();
    try {
      return document.execCommand('copy');
    } catch {
      return false;
    }
  }
}

/**
 * Code de tenue : partager la sienne (crew, amis) ou essayer celle d'un autre joueur.
 * La tenue essayée s'enregistre comme toute modification du créateur.
 */
export function OutfitCodePanel() {
  const t = useT();
  const { state, actions } = useCreator();
  const [input, setInput] = useState('');
  const [shared, setShared] = useState<{ code: string; key: string } | null>(null);
  const [copied, setCopied] = useState(false);
  const [busy, setBusy] = useState(false);
  const [feedback, setFeedback] = useState<{ text: string; error: boolean } | null>(null);
  const codeRef = useRef<HTMLInputElement>(null);
  if (!state) return null;

  const currentKey = outfitKey(state.appearance);
  const sharedCode = shared && shared.key === currentKey ? shared.code : null;

  const share = async () => {
    setBusy(true);
    setFeedback(null);
    const result = await actions.shareOutfit();
    setBusy(false);
    if (result.ok && result.code) {
      setShared({ code: result.code, key: currentKey });
      setCopied(false);
    } else {
      setFeedback({ text: result.message ?? t('Le serveur ne répond pas.'), error: true });
    }
  };

  const copy = async () => {
    if (!sharedCode) return;
    setCopied(await copyText(sharedCode, codeRef.current));
  };

  const apply = async () => {
    if (input.length !== CODE_LENGTH) return;
    setBusy(true);
    setFeedback(null);
    const result = await actions.useOutfitCode(input);
    setBusy(false);
    setFeedback({ text: result.message ?? (result.ok ? '' : t('Le serveur ne répond pas.')), error: !result.ok });
    if (result.ok) setInput('');
  };

  return (
    <div className="ctl-group outfit-code">
      <div className="ctl__row">
        <span className="ctl__label">{t('Code de tenue')}</span>
      </div>
      <span className="ctl__note muted">
        {t('Partage ta tenue avec ton crew, ou entre le code d’un autre joueur pour l’essayer.')}
      </span>

      <div className="outfit-code__row">
        {sharedCode ? (
          <>
            <input
              ref={codeRef}
              className="field outfit-code__field outfit-code__field--code disp"
              value={sharedCode}
              readOnly
              onFocus={(event) => event.target.select()}
            />
            <button className="btn btn--small cut-s" onClick={copy}>
              {copied ? t('Copié') : t('Copier')}
            </button>
          </>
        ) : (
          <button className="btn btn--small cut-s outfit-code__grow" onClick={share} disabled={busy}>
            {t('Créer le code de ma tenue')}
          </button>
        )}
      </div>

      <form
        className="outfit-code__row"
        onSubmit={(event) => {
          event.preventDefault();
          void apply();
        }}
      >
        <input
          className="field outfit-code__field disp"
          value={input}
          placeholder={t('Code d’une tenue')}
          maxLength={CODE_LENGTH + 2}
          spellCheck={false}
          onChange={(event) => setInput(cleanCode(event.target.value))}
        />
        <button className="btn btn--small cut-s" type="submit" disabled={busy || input.length !== CODE_LENGTH}>
          {t('Essayer')}
        </button>
      </form>

      {feedback?.text && (
        <span className={feedback.error ? 'ctl__note outfit-code__error' : 'ctl__note outfit-code__ok'}>{feedback.text}</span>
      )}
    </div>
  );
}
