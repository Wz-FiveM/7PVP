import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/barlow-condensed/latin-600.css';
import '@fontsource/barlow-condensed/latin-700.css';
import '@fontsource/barlow/latin-600.css';
import '@fontsource/jetbrains-mono/latin-700.css';
import '../styles/global.css';
import '../styles/ui.css';
import './dui.css';
import { WorldLabel } from './WorldLabel';

// Étiquette affichée dans le monde (DUI) : page séparée, rendue en texture par le jeu
// (voir client/modules/dui/dui_labels.lua). Taille fixe : pas de mise à l'échelle de l'interface.
createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <WorldLabel />
  </StrictMode>,
);
