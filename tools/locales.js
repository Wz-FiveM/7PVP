#!/usr/bin/env node
// Outil des traductions (locales/<langue>.json, le texte français sert de clé).
//
//   node tools/locales.js check [chemins...] [--with=fichier.json]
//                                                  textes du code sans traduction, placeholders faux
//                                                  (--with : compte aussi les traductions d'un fichier à fusionner)
//   node tools/locales.js merge <fichiers.json...>  ajoute des traductions { "texte fr": { "en": "...", ... } }
//
// `check` repère les appels avec un texte écrit en dur : t('...') côté React, Locale.t('...') côté Lua.
// Les textes de la config (noms d'objets, de zones...) passent par t(variable) : ils ne sont pas
// détectables, il faut les ajouter à la main (ou avec `merge`).
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const LOCALES = path.join(ROOT, 'locales');
const SOURCE_DIRS = ['client', 'server', 'shared', 'config', 'web/src'];
const EXTENSIONS = new Set(['.lua', '.ts', '.tsx']);
// Panneau de développement du navigateur : jamais affiché en jeu
const IGNORED = [/web[\\/]src[\\/]dev[\\/]/];

const LUA_CALL = /Locale\.t\(\s*('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*")/g;
const TS_CALL = /(?<![\w.])t\(\s*('(?:[^'\\\n]|\\.)*'|"(?:[^"\\\n]|\\.)*"|`[^`$\\]*`)/g;

const languages = () =>
  fs.readdirSync(LOCALES).filter((file) => file.endsWith('.json')).map((file) => file.slice(0, -5));

const readLocale = (lang) => JSON.parse(fs.readFileSync(path.join(LOCALES, `${lang}.json`), 'utf8'));

const writeLocale = (lang, dictionary) => {
  const sorted = Object.fromEntries(Object.entries(dictionary).sort(([a], [b]) => a.localeCompare(b, 'fr')));
  fs.writeFileSync(path.join(LOCALES, `${lang}.json`), `${JSON.stringify(sorted, null, 2)}\n`);
};

const unescape = (literal) =>
  literal.slice(1, -1).replace(/\\(.)/g, (_, char) => ({ n: '\n', t: '\t' })[char] ?? char);

/** %s, %d, %.1f... (Lua) et {nom} (React), dans l'ordre */
const placeholders = (text) => (text.match(/%[-+ #0-9.]*[sdif]|\{\w+\}/g) ?? []).join(' ');

function* walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== 'node_modules' && entry.name !== 'build') yield* walk(full);
    } else if (EXTENSIONS.has(path.extname(entry.name)) && !IGNORED.some((pattern) => pattern.test(full))) {
      yield full;
    }
  }
}

/** @returns {Map<string, string[]>} texte -> fichiers qui l'utilisent */
function collectKeys(targets) {
  const keys = new Map();
  for (const target of targets) {
    const full = path.resolve(ROOT, target);
    const files = fs.statSync(full).isDirectory() ? [...walk(full)] : [full];
    for (const file of files) {
      const code = fs.readFileSync(file, 'utf8');
      const pattern = file.endsWith('.lua') ? LUA_CALL : TS_CALL;
      for (const match of code.matchAll(pattern)) {
        // Exemples dans les commentaires
        const line = code.slice(code.lastIndexOf('\n', match.index) + 1, match.index).trim();
        if (/^(--|\/\/|\/?\*)/.test(line)) continue;
        const key = unescape(match[1]);
        const where = path.relative(ROOT, file).replace(/\\/g, '/');
        keys.set(key, [...(keys.get(key) ?? []), where]);
      }
    }
  }
  return keys;
}

function check(args) {
  const targets = args.filter((arg) => !arg.startsWith('--with='));
  const extra = args.filter((arg) => arg.startsWith('--with=')).map((arg) => readFragment(arg.slice(7)));
  const keys = collectKeys(targets.length ? targets : SOURCE_DIRS);
  let problems = 0;
  for (const lang of languages()) {
    const dictionary = readLocale(lang);
    for (const fragment of extra) {
      for (const [key, translations] of Object.entries(fragment)) {
        if (typeof translations[lang] === 'string') dictionary[key] = translations[lang];
      }
    }
    const missing = [...keys.keys()].filter((key) => !(key in dictionary));
    const broken = Object.entries(dictionary).filter(([key, value]) => placeholders(key) !== placeholders(value));
    problems += missing.length + broken.length;
    console.log(`${lang} : ${Object.keys(dictionary).length} traductions, ${missing.length} manquantes, ${broken.length} placeholders faux`);
    for (const key of missing) console.log(`  manque  ${JSON.stringify(key)}  (${[...new Set(keys.get(key))].join(', ')})`);
    for (const [key, value] of broken) console.log(`  faux    ${JSON.stringify(key)} -> ${JSON.stringify(value)}`);
  }
  console.log(`${keys.size} textes trouvés dans le code`);
  process.exitCode = problems ? 1 : 0;
}

const readFragment = (file) => JSON.parse(fs.readFileSync(path.resolve(file), 'utf8'));

function merge(files) {
  const dictionaries = Object.fromEntries(languages().map((lang) => [lang, readLocale(lang)]));
  let added = 0;
  for (const file of files) {
    const fragment = readFragment(file);
    for (const [key, translations] of Object.entries(fragment)) {
      for (const [lang, value] of Object.entries(translations)) {
        if (!dictionaries[lang]) {
          console.warn(`langue inconnue « ${lang} » (${file}) : créer locales/${lang}.json d'abord`);
          continue;
        }
        if (typeof value !== 'string' || placeholders(key) !== placeholders(value)) {
          console.warn(`ignoré (placeholders) ${lang} ${JSON.stringify(key)} -> ${JSON.stringify(value)}`);
          continue;
        }
        if (dictionaries[lang][key] !== value) added += 1;
        dictionaries[lang][key] = value;
      }
    }
  }
  for (const [lang, dictionary] of Object.entries(dictionaries)) writeLocale(lang, dictionary);
  console.log(`${added} traductions ajoutées ou modifiées`);
}

const [command, ...args] = process.argv.slice(2);
if (command === 'check') check(args);
else if (command === 'merge') merge(args);
else console.log('Usage : node tools/locales.js check [chemins...] | merge <fichiers.json...>');
