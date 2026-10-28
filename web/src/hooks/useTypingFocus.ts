import { useEffect } from 'react';
import { fetchNui } from '../api/nui';

const isTextField = (element: EventTarget | null) =>
  element instanceof HTMLTextAreaElement ||
  (element instanceof HTMLInputElement && !['checkbox', 'radio', 'range', 'button', 'submit'].includes(element.type));

/**
 * Menu ouvert, le clavier va aussi au jeu (déplacement, raccourcis) : pendant la saisie dans un
 * champ, on prévient Lua pour qu'il le reprenne, sinon taper « 1 » sortirait une arme.
 */
export function useTypingFocus() {
  useEffect(() => {
    const onFocusIn = (event: FocusEvent) => {
      if (isTextField(event.target)) void fetchNui('menuTyping', { typing: true });
    };
    const onFocusOut = (event: FocusEvent) => {
      if (isTextField(event.target) && !isTextField(event.relatedTarget)) void fetchNui('menuTyping', { typing: false });
    };
    document.addEventListener('focusin', onFocusIn);
    document.addEventListener('focusout', onFocusOut);
    return () => {
      document.removeEventListener('focusin', onFocusIn);
      document.removeEventListener('focusout', onFocusOut);
    };
  }, []);
}
