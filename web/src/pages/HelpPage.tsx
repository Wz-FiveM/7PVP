import { Panel, PanelHeader } from '../components/ui/Panel';
import './pages.css';

const CONTROLS: [string, string][] = [
  ['F2', 'Ouvrir / fermer le menu'],
  ['1 – 7', 'Raccourcis : sortir une arme ou utiliser un soin'],
  ['E', 'Ramasser un sac de butin'],
  ['ÉCHAP', 'Fermer le menu'],
];

const ZONES: { type: 'safe' | 'pve' | 'pvp'; title: string; text: string }[] = [
  { type: 'safe', title: 'Safe', text: 'Tir désactivé, invincibilité, boutique et points de réapparition.' },
  { type: 'pve', title: 'PvE', text: 'PNJ hostiles qui lâchent du butin. Le PvP reste actif.' },
  { type: 'pvp', title: 'PvP', text: 'Tout le reste de la carte : combat libre entre joueurs.' },
];

const RULES: string[] = [
  'À ta mort, tout le contenu de ton sac tombe au sol et peut être ramassé par n\'importe qui.',
  'Le conteneur protégé est conservé à la mort, mais il est petit : choisis bien.',
  'L\'argent est un objet : protège-le ou dépense-le à la boutique.',
  'Chaque conteneur a une limite de poids. Les munitions sont partagées par calibre.',
];

export function HelpPage() {
  return (
    <div className="help">
      <Panel>
        <PanelHeader title="Contrôles" />
        <ul className="help__list">
          {CONTROLS.map(([key, action]) => (
            <li key={key}>
              <kbd className="keycap help__key">[{key}]</kbd>
              {action}
            </li>
          ))}
        </ul>
      </Panel>

      <Panel>
        <PanelHeader title="Zones" />
        <ul className="help__list">
          {ZONES.map((zone) => (
            <li key={zone.type}>
              <span className={`chip cut-s zone-${zone.type} help__chip`}>{zone.title}</span>
              {zone.text}
            </li>
          ))}
        </ul>
      </Panel>

      <Panel className="help__rules">
        <PanelHeader title="Règles" />
        <ul className="help__list">
          {RULES.map((rule, i) => (
            <li key={rule}>
              <span className="mono help__index">{String(i + 1).padStart(2, '0')}</span>
              {rule}
            </li>
          ))}
        </ul>
      </Panel>
    </div>
  );
}
