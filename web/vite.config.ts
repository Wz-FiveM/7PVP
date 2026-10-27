import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // Chemins relatifs obligatoires : FiveM sert les fichiers depuis nui://7PVP/web/build/
  base: './',
  build: {
    outDir: 'build',
    emptyOutDir: true,
  },
});
