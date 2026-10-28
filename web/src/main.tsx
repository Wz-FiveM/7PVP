import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import '@fontsource/barlow-condensed/latin-600.css';
import '@fontsource/barlow-condensed/latin-700.css';
import '@fontsource/barlow/latin-400.css';
import '@fontsource/barlow/latin-600.css';
import '@fontsource/jetbrains-mono/latin-500.css';
import '@fontsource/jetbrains-mono/latin-700.css';
import { App } from './App';
import { CreatorProvider } from './store/CreatorProvider';
import { GameProvider } from './store/GameProvider';
import './styles/global.css';
import './styles/ui.css';
import { watchUiScale } from './utils/scale';

// Avant le premier rendu : l'interface s'adapte à la résolution (720p → 4K)
watchUiScale();

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <GameProvider>
      <CreatorProvider>
        <App />
      </CreatorProvider>
    </GameProvider>
  </StrictMode>,
);
