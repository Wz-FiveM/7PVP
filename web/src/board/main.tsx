import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/barlow-condensed/latin-600.css';
import '@fontsource/barlow-condensed/latin-700.css';
import '@fontsource/barlow/latin-600.css';
import '@fontsource/jetbrains-mono/latin-700.css';
import '../styles/global.css';
import './board.css';
import { ChaseBoard } from './ChaseBoard';

// Tableau du classement de la course poursuite (DUI) : page séparée, rendue en texture et posée
// dans la zone safe du Freeroam (voir client/modules/activities/chase_board.lua). Taille fixe.
createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <ChaseBoard />
  </StrictMode>,
);
