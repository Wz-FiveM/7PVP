import type { ChatCommand, ChatCommandArg, ChatPlayer } from '../../types/game';

/** Ligne de la liste : `before` + `match` (surligné) + `after` forment le texte de gauche. */
export interface SuggestionRow {
  key: string;
  before: string;
  match: string;
  after: string;
  description: string;
  badge?: string;
  /** remplace ce qui est en cours de saisie quand la ligne est choisie */
  fill: string;
  command?: ChatCommand;
}

export type Suggestions =
  | { mode: 'none'; rows: SuggestionRow[] }
  | { mode: 'commands'; query: string; rows: SuggestionRow[] }
  | {
      mode: 'args';
      command: ChatCommand;
      argIndex: number;
      token: string;
      arg?: ChatCommandArg;
      /** arguments obligatoires pas encore saisis */
      missing: ChatCommandArg[];
      rows: SuggestionRow[];
    }
  | { mode: 'mention'; query: string; rows: SuggestionRow[] };

const NONE: Suggestions = { mode: 'none', rows: [] };

function splitMatch(value: string, query: string) {
  const index = query ? value.toLowerCase().indexOf(query.toLowerCase()) : -1;
  if (index < 0) return { before: value, match: '', after: '' };
  return { before: value.slice(0, index), match: value.slice(index, index + query.length), after: value.slice(index + query.length) };
}

function commandRows(commands: ChatCommand[], query: string): SuggestionRow[] {
  const first = commands.filter((command) => command.name.startsWith(query));
  const others = commands.filter((command) => !command.name.startsWith(query) && command.name.includes(query));
  return [...first, ...others].map((command) => {
    const parts = splitMatch(command.name, query);
    return {
      key: command.name,
      ...parts,
      before: `/${parts.before}`,
      description: command.description,
      fill: `/${command.name}${command.args.length ? ' ' : ''}`,
      command,
    };
  });
}

function playerRows(players: ChatPlayer[], token: string): SuggestionRow[] {
  const query = token.toLowerCase();
  return players
    .filter((player) => String(player.id).startsWith(query) || player.name.toLowerCase().includes(query))
    .map((player) => {
      const id = String(player.id);
      return {
        key: id,
        ...splitMatch(id, id.startsWith(query) ? query : ''),
        description: player.name,
        badge: player.crew,
        fill: id,
      };
    });
}

function argRows(arg: ChatCommandArg | undefined, players: ChatPlayer[], token: string): SuggestionRow[] {
  if (!arg) return [];
  const values = (Array.isArray(arg.values) ? arg.values : [])
    .filter((entry) => entry.value.startsWith(token.toLowerCase()))
    .map((entry) => ({
      key: entry.value,
      ...splitMatch(entry.value, token),
      description: entry.label,
      fill: entry.value,
    }));
  return arg.players ? [...values, ...playerRows(players, token)] : values;
}

function mentionRows(players: ChatPlayer[], query: string): SuggestionRow[] {
  return players
    .filter((player) => player.name.toLowerCase().includes(query.toLowerCase()))
    .map((player) => {
      const parts = splitMatch(player.name, query);
      return {
        key: player.name,
        ...parts,
        before: `@${parts.before}`,
        description: `id ${player.id}`,
        badge: player.crew,
        fill: player.name,
      };
    });
}

/**
 * Ce que le chat propose pour le texte en cours de saisie : les commandes après « / », leurs
 * arguments une fois le nom complet, les joueurs après « @ ». Une commande qui n'est pas dans
 * la liste ne propose rien : elle part telle quelle, le serveur peut la connaître.
 */
export function suggest(text: string, commands: ChatCommand[], players: ChatPlayer[]): Suggestions {
  if (text.startsWith('/')) {
    const body = text.slice(1);
    const space = body.search(/\s/);
    if (space < 0) {
      const query = body.toLowerCase();
      return { mode: 'commands', query, rows: commandRows(commands, query) };
    }

    const name = body.slice(0, space).toLowerCase();
    const command = commands.find((candidate) => candidate.name === name);
    if (!command) return NONE;
    const args = Array.isArray(command.args) ? command.args : [];
    const tokens = body.slice(space + 1).trimStart().split(/\s+/);
    const argIndex = tokens.length - 1;
    const token = tokens[argIndex];
    const arg = args[argIndex];
    return {
      mode: 'args',
      command,
      argIndex,
      token,
      arg,
      missing: args.slice(tokens.filter(Boolean).length).filter((candidate) => candidate.required),
      rows: argRows(arg, players, token),
    };
  }

  const mention = text.match(/(?:^|\s)@(\S*)$/);
  if (mention) return { mode: 'mention', query: mention[1], rows: mentionRows(players, mention[1]) };
  return NONE;
}

/** Texte une fois la ligne choisie. */
export function applyRow(text: string, suggestions: Suggestions, row: SuggestionRow): string {
  switch (suggestions.mode) {
    case 'commands':
      return row.fill;
    case 'args': {
      const more = suggestions.argIndex < suggestions.command.args.length - 1;
      return `${text.slice(0, text.length - suggestions.token.length)}${row.fill}${more ? ' ' : ''}`;
    }
    case 'mention':
      return `${text.slice(0, text.length - suggestions.query.length)}${row.fill} `;
    default:
      return text;
  }
}

/** Fin de la suggestion, affichée en gris derrière le texte saisi. */
export function ghostText(suggestions: Suggestions, row: SuggestionRow | undefined): string {
  switch (suggestions.mode) {
    case 'commands':
      return row?.key.startsWith(suggestions.query) ? row.key.slice(suggestions.query.length) : '';
    case 'args':
      if (!suggestions.token) return suggestions.command.args.slice(suggestions.argIndex).map((arg) => arg.label).join(' ');
      return row?.fill.startsWith(suggestions.token) ? row.fill.slice(suggestions.token.length) : '';
    case 'mention':
      return row?.key.toLowerCase().startsWith(suggestions.query.toLowerCase()) ? row.key.slice(suggestions.query.length) : '';
    default:
      return '';
  }
}

/** Découpe un message autour des mentions ; `self` : la mention vise le joueur. */
export function mentionParts(text: string, selfName?: string): { text: string; mention: boolean; self: boolean }[] {
  if (!text.includes('@')) return [{ text, mention: false, self: false }];
  // Un nom peut contenir des espaces : celui du joueur est cherché en premier
  const own = selfName ? `@${selfName.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}(?![\\p{L}\\p{N}_])|` : '';
  const self = selfName ? `@${selfName}`.toLowerCase() : null;
  return text
    .split(new RegExp(`(${own}@\\S+)`, 'giu'))
    .filter(Boolean)
    .map((part) => ({ text: part, mention: part.startsWith('@'), self: part.toLowerCase() === self }));
}

/** Sépare un nom d'auteur en titre, label du crew et nom coloré. */
export function splitAuthor(author: string, name?: string): { title: string; crew: string; name: string } {
  if (!name || !author.endsWith(name)) return { title: '', crew: '', name: author };
  const prefix = author.slice(0, author.length - name.length).trimEnd();
  const crew = prefix.match(/\[\w+\]$/)?.[0] ?? '';
  return { title: prefix.slice(0, prefix.length - crew.length).trim(), crew, name };
}
