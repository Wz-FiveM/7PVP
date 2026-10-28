import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // Chemins relatifs obligatoires : FiveM sert les fichiers depuis nui://7PVP/web/build/
  base: './',
  build: {
    outDir: 'build',
    emptyOutDir: true,
    rollupOptions: {
      // Deux pages : l'interface du jeu (ui_page) et l'écran de chargement (loadscreen)
      input: {
        main: resolve(__dirname, 'index.html'),
        loading: resolve(__dirname, 'loading.html'),
      },
    },
  },
});
