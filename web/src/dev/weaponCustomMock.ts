import type { WeaponCustomPayload } from '../types/weaponCustom';

const tints = [
  { id: 0, label: 'D\'origine', hex: '#2a2d30' },
  { id: 1, label: 'Vert', hex: '#3f7d3a' },
  { id: 2, label: 'Or', hex: '#d4af37' },
  { id: 3, label: 'Rose', hex: '#d65c93' },
  { id: 4, label: 'Armée', hex: '#6b6a3a' },
  { id: 5, label: 'Police', hex: '#2f4f8f' },
  { id: 6, label: 'Orange', hex: '#d9772b' },
  { id: 7, label: 'Platine', hex: '#cfd4d8' },
];

/** Menu du customiseur hors jeu (client/modules/inventory/weapon_custom.lua, config/weapon_custom.lua) */
export const mockWeaponCustom: WeaponCustomPayload = {
  open: true,
  weapons: [
    {
      name: 'weapon_carbinerifle', label: 'Carabine', tint: 2, finish: 'COMPONENT_CARBINERIFLE_VARMOD_LUXE', tints,
      finishes: [{ component: 'COMPONENT_CARBINERIFLE_VARMOD_LUXE', label: 'Luxe' }],
      attachments: ['att_extclip', 'att_scope', 'att_suppressor'],
    },
    {
      name: 'weapon_assaultrifle_mk2', label: 'Fusil d\'assaut Mk II', tint: 0, finish: false,
      tints: [
        { id: 0, label: 'Noir classique', hex: '#1d1f21' },
        { id: 9, label: 'Rouge contrasté', hex: '#a0241f' },
        { id: 13, label: 'Rose vif', hex: '#f21f99' },
        { id: 23, label: 'Or métal', hex: '#d4af37' },
        { id: 29, label: 'Bleu métal', hex: '#1c5fb8' },
      ],
      finishes: [
        { component: 'COMPONENT_ASSAULTRIFLE_MK2_CAMO', label: 'Numérique' },
        { component: 'COMPONENT_ASSAULTRIFLE_MK2_CAMO_04', label: 'Têtes de mort' },
      ],
      attachments: ['att_extclip', 'att_flashlight', 'att_grip', 'att_scope', 'att_suppressor'],
    },
    { name: 'weapon_pistol', label: 'Pistolet', tint: 0, finish: false, tints, finishes: [], attachments: ['att_suppressor'] },
    {
      name: 'weapon_knuckle', label: 'Poing américain', tint: 0, finish: false, tints: [],
      finishes: [
        { component: 'COMPONENT_KNUCKLE_VARMOD_BALLAS', label: 'Ballas' },
        { component: 'COMPONENT_KNUCKLE_VARMOD_DIAMOND', label: 'Diamant' },
      ],
      attachments: [],
    },
  ],
};
