export const formatMoney = (value: number): string => `$${value.toLocaleString('fr-FR')}`;

/** Points boutique, ex : « 1 200 » ou « 1 200 PB » avec l'abréviation */
export const formatPoints = (value: number, short?: string): string =>
  short ? `${value.toLocaleString('fr-FR')} ${short}` : value.toLocaleString('fr-FR');

export const formatKd = (kills: number, deaths: number): string =>
  deaths > 0 ? (kills / deaths).toFixed(2) : kills.toString();

export const formatWeight = (kg: number): string =>
  `${Number.isInteger(kg) ? kg : kg.toFixed(1)}KG`;
