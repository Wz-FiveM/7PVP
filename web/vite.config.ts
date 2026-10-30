import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // Chemins relatifs obligatoires : FiveM sert les fichiers depuis nui://7PVP/web/build/
  base: './',
  // Les traductions sont à la racine de la resource (locales/), partagées avec Lua
  server: { fs: { allow: ['..'] } },
  build: {
    outDir: 'build',
    emptyOutDir: true,
    rollupOptions: {
      // Quatre pages : l'interface du jeu (ui_page), l'écran de chargement (loadscreen),
      // l'étiquette 3D et les tableaux du classement (un par mode de jeu du Freeroam), rendus en texture dans le monde (DUI)
      input: {
        main: resolve(__dirname, 'index.html'),
        loading: resolve(__dirname, 'loading.html'),
        dui: resolve(__dirname, 'dui.html'),
        board: resolve(__dirname, 'board.html'),
      },
    },
  },
});
