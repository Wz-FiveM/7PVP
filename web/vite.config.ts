import { resolve } from 'node:path';
import { defineConfig, normalizePath, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import JavaScriptObfuscator from 'javascript-obfuscator';

const OWN_CODE = normalizePath(resolve(__dirname, 'src'));

// Réglage léger : le HUD tourne en permanence en jeu, donc ni controlFlowFlattening, ni selfDefending, ni debugProtection
const OBFUSCATION = {
  seed: 7,
  target: 'browser',
  identifierNamesGenerator: 'mangled',
  stringArray: true,
  stringArrayEncoding: ['base64'],
  stringArrayThreshold: 0.75,
} as const;

// Ne freine que la lecture du JS : le CSS et le HTML restent lisibles, et rien n'est chiffré.
// React et les traductions n'ont rien à cacher, ils restent tels quels.
function obfuscate(): Plugin {
  return {
    name: '7pvp-obfuscate',
    apply: 'build',
    enforce: 'post',
    generateBundle(_, bundle) {
      for (const file of Object.values(bundle)) {
        if (file.type !== 'chunk' || !file.moduleIds.some((id) => id.startsWith(OWN_CODE))) continue;
        file.code = JavaScriptObfuscator.obfuscate(file.code, OBFUSCATION).getObfuscatedCode();
      }
    },
  };
}

export default defineConfig({
  plugins: [react(), obfuscate()],
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
      output: {
        // React à part, pour ne pas l'obfusquer avec le code qui le partage
        manualChunks(id) {
          if (/node_modules\/(react|react-dom|scheduler)\//.test(id)) return 'vendor';
        },
      },
    },
  },
});
