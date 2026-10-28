import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/chakra-petch/latin-600.css';
import '@fontsource/chakra-petch/latin-700.css';
import '@fontsource/barlow/latin-400.css';
import '@fontsource/barlow/latin-600.css';
import '@fontsource/jetbrains-mono/latin-500.css';
import '@fontsource/jetbrains-mono/latin-700.css';
import '../styles/global.css';
import '../styles/ui.css';
import './loading.css';
import { watchUiScale } from '../utils/scale';
import { LoadingScreen } from './LoadingScreen';

// Écran de chargement : page séparée de l'interface du jeu (loadscreen du fxmanifest)
watchUiScale();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <LoadingScreen />
  </StrictMode>,
);
