import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/barlow-condensed/latin-600.css';
import '@fontsource/barlow-condensed/latin-700.css';
import '@fontsource/barlow/latin-600.css';
import '@fontsource/jetbrains-mono/latin-700.css';
import '../styles/global.css';
import './board.css';
import { ActivityBoard } from './ActivityBoard';

// Tableau du classement d'un mode de jeu du Freeroam (DUI) : page séparée, rendue en texture et posée
// dans la zone safe, une par mode (voir client/modules/activities/activity_boards.lua). Taille fixe.
createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ActivityBoard />
  </StrictMode>,
);
