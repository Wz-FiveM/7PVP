/**
 * Copie dans le presse-papiers. Le navigateur du jeu refuse souvent l'API récente (page sans focus) :
 * on passe alors par un champ de texte sélectionné, `input` s'il est donné, sinon un champ caché.
 */
export async function copyText(text: string, input?: HTMLInputElement | null): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    const field = input ?? document.createElement('textarea');
    if (!input) {
      field.value = text;
      field.style.position = 'fixed';
      field.style.opacity = '0';
      document.body.appendChild(field);
    }
    field.select();
    try {
      return document.execCommand('copy');
    } catch {
      return false;
    } finally {
      if (!input) field.remove();
    }
  }
}
