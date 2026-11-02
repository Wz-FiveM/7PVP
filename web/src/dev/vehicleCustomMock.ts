import type { VehicleCustomPayload } from '../types/vehicleCustom';

/** Menu du mécanicien hors jeu (client/modules/vehicle/custom.lua, config/vehicle_custom.lua) */
export const mockVehicleCustom: VehicleCustomPayload = {
  open: true,
  label: 'Felon',
  props: {
    primary: 27, secondary: 0, pearl: 111, wheelColor: 156, tint: -1, plate: 0, wheelType: 0,
    neon: false, neonColor: '#ffffff', xenon: false, xenonColor: 255, turbo: false,
    mods: { '0': -1, '1': 1, '3': -1, '7': -1, '14': 2, '23': 4 },
  },
  options: {
    isCar: true,
    liveries: 0,
    performance: false,
    mods: [
      { id: '0', label: 'Aileron', tab: 'body', options: ['D\'origine', 'Aileron bas', 'Aileron carbone'] },
      { id: '1', label: 'Pare-chocs avant', tab: 'body', options: ['D\'origine', 'Lame avant', 'Lame carbone', 'Pare-chocs sport'] },
      { id: '3', label: 'Bas de caisse', tab: 'body', options: ['D\'origine', 'Jupes sport'] },
      { id: '7', label: 'Capot', tab: 'body', options: ['D\'origine', 'Capot carbone', 'Capot ventilé'] },
      { id: '14', label: 'Klaxon', tab: 'body', options: ['D\'origine', 'Klaxon de camion', 'Klaxon de police', 'Klaxon de clown'] },
      { id: '23', label: 'Jantes', tab: 'wheels', options: ['D\'origine', 'Inferno', 'Deep Five', 'Lozspeed', 'Diamond', 'Chrono'] },
    ],
  },
  palettes: {
    colors: [
      { id: 0, label: 'Noir', hex: '#0d1116' },
      { id: 12, label: 'Noir mat', hex: '#13181f' },
      { id: 4, label: 'Argent', hex: '#999da0' },
      { id: 111, label: 'Blanc', hex: '#f5f5ef' },
      { id: 27, label: 'Rouge', hex: '#c00e1a' },
      { id: 38, label: 'Orange', hex: '#f78616' },
      { id: 88, label: 'Jaune', hex: '#ffcf20' },
      { id: 53, label: 'Vert vif', hex: '#155c2d' },
      { id: 70, label: 'Bleu ultra', hex: '#0b9cf1' },
      { id: 145, label: 'Violet', hex: '#621276' },
      { id: 135, label: 'Rose vif', hex: '#f21f99' },
    ],
    neonColors: [
      { label: 'Blanc', hex: '#ffffff' },
      { label: 'Rouge', hex: '#ff0000' },
      { label: 'Cyan', hex: '#00e5ff' },
      { label: 'Rose', hex: '#ff1493' },
    ],
    xenonColors: [
      { id: 255, label: 'Blanc', hex: '#dfe9f0' },
      { id: 1, label: 'Bleu', hex: '#1f6fff' },
      { id: 8, label: 'Rouge', hex: '#ff2020' },
    ],
    tints: [
      { id: 0, label: 'Aucune' },
      { id: 3, label: 'Légères' },
      { id: 2, label: 'Foncées' },
      { id: 1, label: 'Noires' },
    ],
    plates: [
      { id: 0, label: 'Blanche' },
      { id: 1, label: 'Jaune et noire' },
    ],
    wheelTypes: [
      { id: 0, label: 'Sport' },
      { id: 1, label: 'Muscle' },
      { id: 4, label: 'Tout-terrain' },
    ],
  },
};
