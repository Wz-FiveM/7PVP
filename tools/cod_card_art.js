#!/usr/bin/env node
// Dessins des cartes de joueur du mode Call of Duty : écrit web/public/cod/banners/<id>.svg et
// web/public/cod/emblems/<id>.svg. La liste (nom, rang requis) est dans config/cod_player_cards.lua.
//
//   node tools/cod_card_art.js
//
// Le tirage au sort est fixe : relancer le script redonne les mêmes dessins.
const fs = require('fs');
const path = require('path');

const OUT = path.resolve(__dirname, '..', 'web', 'public', 'cod');
const W = 400;
const H = 80;

/** Générateur à graine (mulberry32) */
const seeded = (seed) => () => {
  seed = (seed + 0x6d2b79f5) | 0;
  let value = Math.imul(seed ^ (seed >>> 15), 1 | seed);
  value = (value + Math.imul(value ^ (value >>> 7), 61 | value)) ^ value;
  return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
};
const between = (rand, min, max) => min + rand() * (max - min);
const pick = (rand, list) => list[Math.floor(rand() * list.length)];
const fix = (value) => Math.round(value * 10) / 10;
const times = (count, build) => Array.from({ length: count }, (_, index) => build(index)).join('');

const gradient = (id, stops, vertical = true) =>
  `<linearGradient id="${id}" x1="0" y1="0" x2="${vertical ? 0 : 1}" y2="${vertical ? 1 : 0}">${stops
    .map(([offset, color]) => `<stop offset="${offset}" stop-color="${color}"/>`)
    .join('')}</linearGradient>`;
const rect = (fill, extra = '') => `<rect width="${W}" height="${H}" fill="${fill}" ${extra}/>`;
const banner = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${W} ${H}" preserveAspectRatio="xMidYMid slice">${body}</svg>`;

/** Tache de camouflage : polygone arrondi autour d'un point */
const blob = (rand, x, y, size, fill) => {
  const points = Array.from({ length: 9 }, (_, index) => {
    const angle = (index / 9) * Math.PI * 2;
    const radius = size * between(rand, 0.55, 1.15);
    return [x + Math.cos(angle) * radius * 1.5, y + Math.sin(angle) * radius];
  });
  const mid = (a, b) => [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
  const start = mid(points[8], points[0]);
  let d = `M${fix(start[0])} ${fix(start[1])}`;
  points.forEach((point, index) => {
    const end = mid(point, points[(index + 1) % 9]);
    d += `Q${fix(point[0])} ${fix(point[1])} ${fix(end[0])} ${fix(end[1])}`;
  });
  return `<path d="${d}Z" fill="${fill}"/>`;
};
const camo = (seed, base, colors, count, size) => {
  const rand = seeded(seed);
  return rect(base) + times(count, () => blob(rand, between(rand, -10, W + 10), between(rand, -5, H + 5), between(rand, size * 0.5, size), pick(rand, colors)));
};

/** Bâtiments ou collines : ligne de toits pleine jusqu'en bas */
const skylinePath = (rand, top, low, high, minWidth, maxWidth) => {
  let x = 0;
  let d = `M0 ${H}`;
  const roofs = [];
  while (x < W) {
    const width = between(rand, minWidth, maxWidth);
    const y = top + between(rand, low, high);
    d += `L${fix(x)} ${fix(y)}L${fix(x + width)} ${fix(y)}`;
    roofs.push({ x, y, width });
    x += width;
  }
  return { path: `${d}L${W} ${H}Z`, roofs };
};

const SKULL = 'M0-13c-8 0-13 5-13 12 0 4 2 7 5 9v5c0 1 1 2 2 2h12c1 0 2-1 2-2V8c3-2 5-5 5-9 0-7-5-12-13-12Zm-5 16a3.4 3.4 0 1 1 0-7 3.4 3.4 0 0 1 0 7Zm10 0a3.4 3.4 0 1 1 0-7 3.4 3.4 0 0 1 0 7ZM0 4l2 4h-4Z';
const HELI = 'M-26 0c0-3 6-6 14-6h6c6 0 9 3 12 5l26-2 3-5h3l-1 9-2 1-30 2c-3 3-8 4-14 4-10 0-17-3-17-8Zm-4-10h60v1.4h-60ZM-1-9h2v3h-2ZM-14 11h26v1.4h-26Z';
const JET = 'M-30 0-8-3 2-14h5L3-3l16-1 6-7h3l-2 10 2 2-3 1-6 0-16 2 2 9h-5L-8 3Z';

const BANNERS = {
  steel: () => {
    const rand = seeded(11);
    return banner(`<defs>${gradient('m', [[0, '#6b7178'], [0.45, '#3d4248'], [0.55, '#2c3035'], [1, '#4a4f55']])}</defs>${rect('url(#m)')}${times(70, () => {
      const y = fix(between(rand, 0, H));
      return `<rect x="${fix(between(rand, -40, W))}" y="${y}" width="${fix(between(rand, 60, 260))}" height="0.6" fill="#fff" opacity="${fix(between(rand, 0.03, 0.14))}"/>`;
    })}<path d="M250 0h60l-40 80h-60Z" fill="#fff" opacity=".05"/><path d="M0 8H400M0 72H400" stroke="#000" stroke-opacity=".5"/>${times(9, (i) => `<circle cx="${25 + i * 44}" cy="4" r="1.6" fill="#15171a"/><circle cx="${25 + i * 44}" cy="76" r="1.6" fill="#15171a"/>`)}${times(3, (i) => `<path d="M${322 + i * 18} 22l14 18-14 18h9l14-18-14-18Z" fill="#f28a2e" opacity=".85"/>`)}`);
  },
  woodland: () => banner(camo(21, '#4c5a35', ['#2c3a22', '#6d6a3f', '#1e241a', '#7a6b45'], 46, 22)),
  desert: () => banner(camo(22, '#b89a68', ['#94764a', '#d0b78a', '#7d6a4b', '#a58a5c'], 46, 22)),
  arctic: () => banner(camo(23, '#d7dde2', ['#a7b2bb', '#f2f5f7', '#7f8b95', '#bcc6ce'], 46, 20)),
  digital: () => {
    const rand = seeded(24);
    const colors = ['#2b2f34', '#4a5057', '#6d747b', '#8e959b'];
    let body = rect('#585e65');
    for (let x = 0; x < W; x += 8) {
      for (let y = 0; y < H; y += 8) {
        if (rand() < 0.62) body += `<rect x="${x}" y="${y}" width="8" height="8" fill="${pick(rand, colors)}"/>`;
      }
    }
    return banner(body);
  },
  carbon: () => banner(`<defs><pattern id="c" width="8" height="8" patternUnits="userSpaceOnUse"><rect width="8" height="8" fill="#111316"/><rect width="4" height="4" fill="#24282d"/><rect x="4" y="4" width="4" height="4" fill="#24282d"/><path d="M0 4h4M4 8h4" stroke="#3a3f45" stroke-width=".6"/></pattern>${gradient('s', [[0, '#fff'], [0.5, '#000'], [1, '#000']])}</defs>${rect('url(#c)')}${rect('url(#s)', 'opacity=".16"')}<path d="M0 62 400 18v8L0 70Z" fill="#e5484d" opacity=".9"/>`),
  hazard: () => {
    const rand = seeded(31);
    return banner(`${rect('#e8b70f')}${times(14, (i) => `<path d="M${i * 44 - 60} ${H}l50-${H}h22l-50 ${H}Z" fill="#17181a"/>`)}${times(60, () => `<rect x="${fix(between(rand, 0, W))}" y="${fix(between(rand, 0, H))}" width="${fix(between(rand, 2, 16))}" height="${fix(between(rand, 0.6, 2))}" fill="#000" opacity=".28"/>`)}<rect width="${W}" height="${H}" fill="none" stroke="#000" stroke-width="5" opacity=".5"/>`);
  },
  skyline: () => {
    const rand = seeded(41);
    const back = skylinePath(rand, 34, 0, 26, 14, 34);
    const front = skylinePath(rand, 44, 0, 28, 12, 30);
    const lights = times(120, () => {
      const roof = pick(rand, front.roofs);
      const x = fix(roof.x + between(rand, 2, Math.max(3, roof.width - 3)));
      const y = fix(between(rand, roof.y + 3, H - 3));
      return `<rect x="${x}" y="${y}" width="1.6" height="1.8" fill="#ffd27a" opacity="${fix(between(rand, 0.4, 1))}"/>`;
    });
    return banner(`<defs>${gradient('s', [[0, '#2b1447'], [0.4, '#a12d5b'], [0.72, '#f2823a'], [1, '#ffd27a']])}</defs>${rect('url(#s)')}<circle cx="290" cy="50" r="19" fill="#ffe2a0"/><path d="${back.path}" fill="#3e1b48"/><path d="${front.path}" fill="#150b1f"/>${lights}<path d="M84 0v62M78 12h12" stroke="#150b1f" stroke-width=".8" opacity=".6"/>`);
  },
  radar: () => {
    const rand = seeded(51);
    return banner(`<defs><radialGradient id="g" cx=".72" cy=".5" r=".6"><stop offset="0" stop-color="#0d5a33"/><stop offset="1" stop-color="#03130b"/></radialGradient></defs>${rect('url(#g)')}${times(20, (i) => `<path d="M${i * 20} 0v${H}" stroke="#2bf08a" stroke-opacity=".08"/>`)}${times(4, (i) => `<path d="M0 ${i * 20 + 10}h${W}" stroke="#2bf08a" stroke-opacity=".08"/>`)}${times(4, (i) => `<circle cx="288" cy="40" r="${18 + i * 22}" fill="none" stroke="#2bf08a" stroke-opacity=".38"/>`)}<path d="M288 40 400 6v70Z" fill="#2bf08a" opacity=".2"/><path d="M288 40 400 6" stroke="#9dffc9" stroke-width="1.4"/>${times(7, () => `<circle cx="${fix(between(rand, 225, 390))}" cy="${fix(between(rand, 8, 72))}" r="2" fill="#ff5a3c"/>`)}`);
  },
  million: () => {
    const rand = seeded(61);
    const bill = (x, y, shade) => `<g transform="translate(${x} ${y})"><rect width="386" height="74" fill="${shade}" stroke="#1e2b16" stroke-width="1"/></g>`;
    return banner(`${rect('#1a2413')}${bill(14, 6, '#5d6b45')}${bill(10, 3, '#6a7850')}<g transform="translate(4 1)"><rect width="386" height="76" fill="#8d9a6c"/><rect x="4" y="4" width="378" height="68" fill="none" stroke="#2f3f22" stroke-width="2.4"/><rect x="8" y="8" width="370" height="60" fill="none" stroke="#2f3f22" stroke-width=".8"/>${times(62, (i) => `<path d="M12 ${10 + i}H374" stroke="#2f3f22" stroke-opacity="${i % 2 ? 0.06 : 0.13}" stroke-width=".5"/>`)}${times(40, (i) => `<ellipse cx="193" cy="38" rx="${44 + i * 3.4}" ry="${26 + i * 1.5}" fill="none" stroke="#3b4d2c" stroke-opacity=".17" stroke-width=".6"/>`)}<ellipse cx="193" cy="38" rx="27" ry="28" fill="#d6dcb9" stroke="#2f3f22" stroke-width="2"/><ellipse cx="193" cy="38" rx="23" ry="24" fill="none" stroke="#2f3f22" stroke-width=".7"/><path d="M193 19c-6 0-10 4-10 10 0 3 1 6 3 8-5 2-11 6-12 14 5 6 12 9 19 9s14-3 19-9c-1-8-7-12-12-14 2-2 3-5 3-8 0-6-4-10-10-10Z" fill="#2f3f22"/>${times(30, () => `<rect x="${fix(between(rand, 160, 226))}" y="${fix(between(rand, 16, 62))}" width="${fix(between(rand, 3, 8))}" height=".5" fill="#d6dcb9" opacity=".4"/>`)}<g font-family="Georgia,serif" font-weight="700" fill="#22301a" text-anchor="middle"><text x="285" y="26" font-size="15" letter-spacing="1">1,000,000</text><text x="285" y="62" font-size="11" letter-spacing="3">ONE MILLION</text><text x="44" y="30" font-size="22">$1M</text><text x="44" y="64" font-size="22">$1M</text><text x="125" y="48" font-size="9" letter-spacing="1.4">SEVEN PVP</text><text x="360" y="44" font-size="20">$</text></g></g>`);
  },
  flames: () => {
    const rand = seeded(71);
    const tongues = (color, low, high, count) => {
      let d = `M0 ${H}`;
      for (let index = 0; index <= count; index += 1) {
        const x = (index / count) * W;
        const top = between(rand, low, high);
        d += `Q${fix(x - 6)} ${fix((top + H) / 2)} ${fix(x + between(rand, -6, 6))} ${fix(top)}Q${fix(x + 12)} ${fix((top + H) / 2)} ${fix(x + W / count)} ${fix(H - 8)}`;
      }
      return `<path d="${d}L${W} ${H}Z" fill="${color}"/>`;
    };
    return banner(`<defs>${gradient('g', [[0, '#0b0605'], [0.6, '#3a0f06'], [1, '#a32c0a']])}</defs>${rect('url(#g)')}${tongues('#b5330a', 2, 34, 18)}${tongues('#ef6c13', 22, 50, 22)}${tongues('#ffb52e', 44, 66, 26)}${times(40, () => `<circle cx="${fix(between(rand, 0, W))}" cy="${fix(between(rand, 0, 50))}" r="${fix(between(rand, 0.4, 1.3))}" fill="#ffd27a"/>`)}`);
  },
  thermal: () => {
    const rand = seeded(81);
    const figure = (x, y, scale) => `<g transform="translate(${x} ${y}) scale(${scale})" fill="#fff"><circle cy="-13" r="3.4"/><path d="M-5-9h10l1 12h-3l1 13h-3l-1-10-1 10h-3l1-13h-3Z"/></g>`;
    return banner(`${rect('#2b2d2e')}${times(16, () => `<rect x="${fix(between(rand, 0, W))}" y="${fix(between(rand, 0, H))}" width="${fix(between(rand, 20, 70))}" height="${fix(between(rand, 8, 26))}" fill="${pick(rand, ['#3b3d3e', '#1f2021', '#474a4b'])}" transform="rotate(${fix(between(rand, -8, 8))} 200 40)"/>`)}${figure(250, 46, 1)}${figure(278, 54, 1)}${figure(330, 42, 0.9)}${figure(120, 56, 0.9)}<g fill="none" stroke="#fff" stroke-width="1.2"><path d="M285 0v30M285 50v30M205 40h60M305 40h95"/><path d="M265 22h-8v8M305 22h8v8M265 58h-8v-8M305 58h8v-8"/></g><text x="8" y="14" font-family="monospace" font-size="9" fill="#fff" letter-spacing="1">WHT  HOT  105MM</text><text x="8" y="74" font-family="monospace" font-size="9" fill="#fff" letter-spacing="1">AGL 2400  ZOOM x4</text>`);
  },
  storm: () => {
    const rand = seeded(91);
    const bolt = (x, scale) => {
      let px = x;
      let py = 0;
      let d = `M${px} ${py}`;
      while (py < H) {
        px += between(rand, -12, 12) * scale;
        py += between(rand, 7, 15);
        d += `L${fix(px)} ${fix(py)}`;
      }
      return `<path d="${d}" fill="none" stroke="#6fa0ff" stroke-width="4" opacity=".35"/><path d="${d}" fill="none" stroke="#eaf1ff" stroke-width="1.3"/>`;
    };
    return banner(`<defs>${gradient('s', [[0, '#0c0f24'], [0.6, '#2a2358'], [1, '#55368a']])}</defs>${rect('url(#s)')}${times(40, () => blob(rand, between(rand, 0, W), between(rand, -4, 22), between(rand, 8, 20), pick(rand, ['#14173a', '#1d1f4d', '#2c2a60'])))}${bolt(90, 1)}${bolt(262, 1.2)}${bolt(345, 0.8)}`);
  },
  skulls: () => {
    const rand = seeded(101);
    return banner(`<defs>${gradient('g', [[0, '#191a1d'], [1, '#090a0b']])}</defs>${rect('url(#g)')}${times(9, (i) => times(3, (j) => {
      const x = i * 48 + (j % 2 ? 24 : 0) + 4;
      const y = j * 27 + 13;
      const bright = rand() < 0.12;
      return `<path transform="translate(${x} ${y}) scale(.72)" d="${SKULL}" fill="${bright ? '#e5484d' : '#54585e'}" fill-rule="evenodd" opacity="${bright ? 1 : fix(between(rand, 0.4, 0.85))}"/>`;
    }))}`);
  },
  circuit: () => {
    const rand = seeded(111);
    return banner(`${rect('#06241f')}${times(46, () => {
      let x = Math.round(between(rand, 0, W) / 8) * 8;
      let y = Math.round(between(rand, 0, H) / 8) * 8;
      let d = `M${x} ${y}`;
      times(4, () => {
        const step = Math.round(between(rand, 1, 4)) * 8;
        const dir = pick(rand, [[1, 0], [1, 1], [1, -1], [0, 1], [0, -1]]);
        x += dir[0] * step;
        y += dir[1] * step;
        d += `L${x} ${y}`;
        return '';
      });
      return `<path d="${d}" fill="none" stroke="#1fd6a8" stroke-width="1" opacity="${fix(between(rand, 0.35, 0.9))}"/><circle cx="${x}" cy="${y}" r="2" fill="#06241f" stroke="#7dffe0"/>`;
    })}<g transform="translate(290 22)"><rect width="56" height="36" fill="#0a0d0f" stroke="#7dffe0"/>${times(6, (i) => `<path d="M${6 + i * 9} -6v6M${6 + i * 9} 36v6" stroke="#7dffe0" stroke-width="1.6"/>`)}<text x="28" y="23" font-family="monospace" font-size="11" fill="#7dffe0" text-anchor="middle">7PVP</text></g>`);
  },
  squadron: () => {
    const rand = seeded(121);
    const plane = (x, y, scale) => `<path d="M0 0H${-x - 20}" transform="translate(${x} ${y})" stroke="#fff" stroke-width="${fix(scale * 1.6)}" opacity=".5"/><path transform="translate(${x} ${y}) scale(${scale})" d="${JET}" fill="#10171f"/>`;
    return banner(`<defs>${gradient('s', [[0, '#21547f'], [0.7, '#7fb6d6'], [1, '#d9e8ec']])}</defs>${rect('url(#s)')}${times(26, () => blob(rand, between(rand, 0, W), between(rand, 58, 86), between(rand, 7, 18), '#f5f8f9'))}${plane(340, 26, 0.8)}${plane(278, 44, 0.65)}${plane(225, 18, 0.55)}`);
  },
  scope: () => {
    const rand = seeded(131);
    return banner(`<defs><radialGradient id="v" cx=".6" cy=".5" r=".5" gradientTransform="translate(.24 0) scale(.6 1)"><stop offset=".62" stop-color="#000" stop-opacity="0"/><stop offset=".66" stop-color="#000"/></radialGradient>${gradient('l', [[0, '#7d97a0'], [0.55, '#b6b8a0'], [0.56, '#5f6b46'], [1, '#2f3a24']])}</defs>${rect('url(#l)')}${times(30, () => blob(rand, between(rand, 150, 340), between(rand, 46, 80), between(rand, 3, 8), '#2c3a24'))}<g transform="translate(240 40)"><path d="M-160 0H-6M6 0H160M0-40V-6M0 6V40" stroke="#000" stroke-width="1"/>${times(9, (i) => `<path d="M${-40 + i * 10} -2v4" stroke="#000" stroke-width=".8"/>`)}<circle r="1.2" fill="#e5484d"/></g>${rect('url(#v)')}`);
  },
  blood: () => {
    const rand = seeded(141);
    const splat = (x, y, size) => times(16, () => {
      const angle = between(rand, 0, Math.PI * 2);
      const distance = between(rand, 0, size) ** 1.4 / Math.sqrt(size);
      return `<ellipse cx="${fix(x + Math.cos(angle) * distance * 2.2)}" cy="${fix(y + Math.sin(angle) * distance)}" rx="${fix(between(rand, 0.6, size / 4))}" ry="${fix(between(rand, 0.6, size / 5))}" fill="#7f0d0d"/>`;
    }) + `<ellipse cx="${x}" cy="${y}" rx="${size * 0.8}" ry="${size * 0.5}" fill="#8e1010"/>`;
    return banner(`<defs>${gradient('g', [[0, '#201b1b'], [1, '#0f0c0c']])}</defs>${rect('url(#g)')}${splat(270, 34, 34)}${splat(355, 58, 18)}${splat(170, 62, 12)}${times(9, (i) => `<rect x="${236 + i * 13 + fix(between(rand, -3, 3))}" y="44" width="${fix(between(rand, 1.4, 3))}" height="${fix(between(rand, 12, 36))}" rx="1.4" fill="#7f0d0d"/>`)}`);
  },
  chopper: () => {
    const heli = (x, y, scale) => `<path transform="translate(${x} ${y}) scale(${scale})" d="${HELI}" fill="#180806"/>`;
    return banner(`<defs>${gradient('s', [[0, '#3b0a06'], [0.5, '#a5260c'], [0.85, '#ef7a1c'], [1, '#ffc15a']])}</defs>${rect('url(#s)')}<circle cx="282" cy="62" r="42" fill="#ffd27a" opacity=".92"/>${skylinePath(seeded(151), 64, 0, 13, 3, 10).path ? `<path d="${skylinePath(seeded(151), 64, 0, 13, 3, 10).path}" fill="#180806"/>` : ''}${heli(285, 30, 0.95)}${heli(205, 42, 0.62)}${heli(355, 20, 0.5)}${heli(150, 22, 0.36)}`);
  },
  nuke: () => banner(`<defs>${gradient('s', [[0, '#2c1007'], [0.6, '#a33b0c'], [1, '#f59d2a']])}<radialGradient id="c" cx=".5" cy=".5" r=".6"><stop offset="0" stop-color="#fff2b0"/><stop offset=".45" stop-color="#f5902a"/><stop offset="1" stop-color="#6b1f08"/></radialGradient></defs>${rect('url(#s)')}<ellipse cx="290" cy="76" rx="104" ry="9" fill="#fff2b0" opacity=".8"/><path d="M276 80c3-14 4-24 2-36h24c-2 12-1 22 2 36Z" fill="url(#c)"/><ellipse cx="290" cy="24" rx="46" ry="22" fill="url(#c)"/><ellipse cx="256" cy="28" rx="16" ry="11" fill="#c75c16"/><ellipse cx="324" cy="28" rx="16" ry="11" fill="#c75c16"/><ellipse cx="290" cy="46" rx="26" ry="5" fill="#ffd27a" opacity=".85"/><path d="M0 80V70l30-5 34 7 50-9 44 8 50-4v13Z" fill="#180906"/>`),
  gold: () => banner(`<defs>${gradient('g', [[0, '#6b4a10'], [0.3, '#f7dd7a'], [0.5, '#b98a1e'], [0.72, '#fff0a8'], [1, '#7d5812']], false)}${gradient('v', [[0, '#fff'], [0.5, '#000']])}</defs>${rect('url(#g)')}${rect('url(#v)', 'opacity=".2"')}<path d="M240 0h34l-40 80h-34ZM292 0h10l-40 80h-10Z" fill="#fff" opacity=".35"/><rect x="3" y="3" width="394" height="74" fill="none" stroke="#5b400c" stroke-width="2"/>`),
  legend: () => banner(`<defs>${gradient('g', [[0, '#1a1508'], [0.5, '#050403'], [1, '#1a1508']], false)}${gradient('o', [[0, '#fff0a8'], [0.5, '#d6a530'], [1, '#7d5812']])}</defs>${rect('url(#g)')}${times(24, (i) => `<path d="M285 40 ${fix(285 + Math.cos((i / 24) * Math.PI * 2) * 260)} ${fix(40 + Math.sin((i / 24) * Math.PI * 2) * 260)}" stroke="#d6a530" stroke-width="${i % 2 ? 0.5 : 1.6}" opacity=".3"/>`)}<g transform="translate(285 40)" fill="url(#o)">${times(9, (i) => `<ellipse rx="7" ry="3" transform="rotate(${-50 - i * 11}) translate(30 0) rotate(60)"/><ellipse rx="7" ry="3" transform="rotate(${50 + i * 11 + 180}) translate(-30 0) rotate(-60)"/>`)}<path d="M0-22 6.5-7 23-7 10 3l5 16L0 9l-15 10 5-16-13-10H-6.5Z"/></g><rect x="3" y="3" width="394" height="74" fill="none" stroke="url(#o)" stroke-width="1.6"/>`),
};

// ---------------------------------------------------------------------------
// Emblèmes (64 x 64)
// ---------------------------------------------------------------------------

const emblem = (body) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">${body}</svg>`;
const OUTLINE = 'stroke="#0a0b0c" stroke-width="2" stroke-linejoin="round"';
const shape = (d, fill, extra = '') => `<path d="${d}" fill="${fill}" ${OUTLINE} ${extra}/>`;

const EMBLEMS = {
  star: () => emblem(shape('M32 5 40 24 60 25 44 38 50 58 32 47 14 58 20 38 4 25 24 24Z', '#f2f3f0')),
  skull: () => emblem(`<g transform="translate(32 28) scale(1.9)"><path d="${SKULL}" fill="#f2f3f0" fill-rule="evenodd" stroke="#0a0b0c" stroke-width="1"/></g>`),
  crosshair: () => emblem(`<g fill="none" stroke="#0a0b0c" stroke-width="7"><circle cx="32" cy="32" r="20"/><path d="M32 4v18M32 42v18M4 32h18M42 32h18"/></g><g fill="none" stroke="#e5484d" stroke-width="3.6"><circle cx="32" cy="32" r="20"/><path d="M32 4v18M32 42v18M4 32h18M42 32h18"/></g><circle cx="32" cy="32" r="3.4" fill="#e5484d" stroke="#0a0b0c"/>`),
  shield: () => emblem(`${shape('M32 4 56 13V32C56 46 45 55 32 60 19 55 8 46 8 32V13Z', '#2c4a7a')}<path d="M32 4 56 13V32C56 46 45 55 32 60Z" fill="#fff" opacity=".12"/><path d="M18 30 32 40 46 30M18 20 32 30 46 20" fill="none" stroke="#f2f3f0" stroke-width="4.4"/>`),
  bolt: () => emblem(shape('M38 3 12 36H28L22 61 52 25H35Z', '#ffd23f')),
  spade: () => emblem(shape('M32 4C22 18 8 25 8 38 8 46 15 50 21 48 25 47 28 44 29 41 28 49 25 54 20 58H44C39 54 36 49 35 41 36 44 39 47 43 48 49 50 56 46 56 38 56 25 42 18 32 4Z', '#17181a', 'style="stroke:#f2f3f0"')),
  cherries: () => emblem(`<path d="M21 42C24 28 32 14 46 6 46 18 46 28 45 40" fill="none" stroke="#0a0b0c" stroke-width="6"/><path d="M21 42C24 28 32 14 46 6 46 18 46 28 45 40" fill="none" stroke="#2a6fd6" stroke-width="3.4"/><path d="M46 6C51 5 56 7 59 11 54 14 49 12 46 6Z" fill="#3fae4e" ${OUTLINE}/><circle cx="19" cy="46" r="14" fill="#e8141c" ${OUTLINE}/><circle cx="45" cy="46" r="14" fill="#e8141c" ${OUTLINE}/><circle cx="14" cy="41" r="3.4" fill="#fff" opacity=".7"/><circle cx="40" cy="41" r="3.4" fill="#fff" opacity=".7"/>`),
  heart: () => emblem(shape('M32 57C14 43 5 33 5 22 5 12 13 7 20 7 25 7 29 10 32 15 35 10 39 7 44 7 51 7 59 12 59 22 59 33 50 43 32 57Z', '#d81e2c')),
  flame: () => emblem(`${shape('M33 3C36 15 53 24 53 41 53 53 43 61 32 61 21 61 11 53 11 41 11 31 18 26 21 17 25 21 26 25 26 29 31 24 34 13 33 3Z', '#ef6c13')}<path d="M32 28C34 36 43 40 43 48 43 55 38 59 32 59 26 59 21 55 21 48 21 42 29 38 32 28Z" fill="#ffd23f"/>`),
  dice: () => emblem(`${shape('M6 22 30 12 44 34 20 46Z', '#f2f3f0')}${shape('M34 26 58 24 60 50 36 54Z', '#e5484d')}<g fill="#0a0b0c"><circle cx="18" cy="24" r="2.6"/><circle cx="25" cy="29" r="2.6"/><circle cx="32" cy="34" r="2.6"/></g><g fill="#f2f3f0"><circle cx="41" cy="32" r="2.4"/><circle cx="52" cy="31" r="2.4"/><circle cx="42" cy="47" r="2.4"/><circle cx="53" cy="46" r="2.4"/></g>`),
  grenade: () => emblem(`${shape('M20 26H44C50 32 52 39 50 47 48 56 41 60 32 60 23 60 16 56 14 47 12 39 14 32 20 26Z', '#4c5a35')}<path d="M16 38H48M15 48H49M26 27 24 60M38 27 40 60" stroke="#0a0b0c" stroke-width="1.8"/>${shape('M24 14H40V26H24Z', '#8a8f94')}${shape('M40 16 56 22 54 30 40 22Z', '#8a8f94')}<circle cx="19" cy="12" r="7" fill="none" stroke="#0a0b0c" stroke-width="5"/><circle cx="19" cy="12" r="7" fill="none" stroke="#d6a530" stroke-width="2.4"/>`),
  knives: () => emblem(`<g transform="rotate(45 32 32)">${shape('M28 2 C36 8 37 20 36 34H28Z', '#c9ced3')}${shape('M23 34H41V38H23ZM28 38H36V60H28Z', '#2b2f34')}</g><g transform="rotate(-45 32 32)">${shape('M36 2 C28 8 27 20 28 34H36Z', '#e6e9ec')}${shape('M23 34H41V38H23ZM28 38H36V60H28Z', '#7a2d1a')}</g>`),
  clover: () => emblem(`<path d="M32 36C34 46 37 53 44 60" fill="none" stroke="#0a0b0c" stroke-width="6"/><path d="M32 36C34 46 37 53 44 60" fill="none" stroke="#2e9e45" stroke-width="3"/>${shape('M32 32C20 34 8 28 11 16 14 7 26 8 32 32ZM32 32C30 20 36 6 48 8 58 11 56 26 32 32ZM32 32C44 30 56 36 53 47 50 56 38 54 32 32ZM32 32C34 44 28 58 16 54 7 51 10 38 32 32Z', '#2e9e45')}`),
  anchor: () => emblem(`<g fill="none" stroke-linecap="round"><g stroke="#0a0b0c" stroke-width="9"><circle cx="32" cy="12" r="6"/><path d="M32 18V57M18 28H46M8 38C10 50 20 57 32 57 44 57 54 50 56 38"/></g><g stroke="#5fd1e8" stroke-width="5"><circle cx="32" cy="12" r="6"/><path d="M32 18V57M18 28H46M8 38C10 50 20 57 32 57 44 57 54 50 56 38"/></g></g>${shape('M3 42 8 32 15 42ZM61 42 56 32 49 42Z', '#5fd1e8')}`),
  crown: () => emblem(`${shape('M6 18 19 32 32 8 45 32 58 18 53 52H11Z', '#f2c230')}<path d="M11 44H53" stroke="#0a0b0c" stroke-width="2"/><g stroke="#0a0b0c" stroke-width="1.4"><circle cx="20" cy="48" r="2.4" fill="#e5484d"/><circle cx="32" cy="48" r="2.4" fill="#5fd1e8"/><circle cx="44" cy="48" r="2.4" fill="#e5484d"/><circle cx="6" cy="16" r="3" fill="#fff"/><circle cx="32" cy="7" r="3" fill="#fff"/><circle cx="58" cy="16" r="3" fill="#fff"/></g>`),
  radiation: () => emblem(`<circle cx="32" cy="32" r="29" fill="#f2c230" ${OUTLINE}/><g fill="#17181a"><circle cx="32" cy="32" r="5"/><path d="M32 32 21 13A22 22 0 0 1 43 13ZM32 32 54 32A22 22 0 0 1 43 51ZM32 32 21 51A22 22 0 0 1 10 32Z"/></g><circle cx="32" cy="32" r="7.4" fill="none" stroke="#f2c230" stroke-width="2.4"/>`),
  wings: () => emblem(`${shape('M30 26C20 18 12 18 2 20 5 24 8 25 11 26 8 27 7 29 7 31 11 31 13 31 16 32 14 33 14 35 15 38 19 37 22 37 25 38 28 42 30 40 30 36Z', '#d7dde2')}${shape('M34 26C44 18 52 18 62 20 59 24 56 25 53 26 56 27 57 29 57 31 53 31 51 31 48 32 50 33 50 35 49 38 45 37 42 37 39 38 36 42 34 40 34 36Z', '#d7dde2')}${shape('M32 18 37 28 34 50 32 56 30 50 27 28Z', '#f28a2e')}`),
  eye: () => emblem(`${shape('M2 32C14 14 50 14 62 32 50 50 14 50 2 32Z', '#f2f3f0')}<circle cx="32" cy="32" r="15" fill="#c22" ${OUTLINE}/><circle cx="32" cy="32" r="7" fill="#0a0b0c"/><circle cx="28" cy="27" r="3" fill="#fff"/>`),
  dollar: () => emblem(`<circle cx="32" cy="32" r="28" fill="#2e9e45" ${OUTLINE}/><circle cx="32" cy="32" r="22" fill="none" stroke="#d7f5dd" stroke-width="1.6"/><text x="32" y="46" font-family="Georgia,serif" font-weight="700" font-size="38" text-anchor="middle" fill="#f2f3f0">$</text>`),
  eightball: () => emblem(`<circle cx="32" cy="32" r="28" fill="#17181a" stroke="#f2f3f0" stroke-width="2"/><circle cx="26" cy="26" r="13" fill="#f2f3f0"/><text x="26" y="33" font-family="Arial,sans-serif" font-weight="700" font-size="19" text-anchor="middle" fill="#17181a">8</text><path d="M43 12C50 17 54 25 54 32" stroke="#fff" stroke-width="3" fill="none" opacity=".5"/>`),
  moon: () => emblem(`${shape('M44 5C27 4 10 16 10 34 10 49 23 60 38 60 47 60 54 56 59 49 42 54 26 44 26 28 26 18 33 9 44 5Z', '#d7dde2')}${shape('M48 18 51 25 58 26 53 31 55 38 48 34 41 38 43 31 38 26 45 25Z', '#ffd23f')}`),
  pirate: () => emblem(`<g stroke-linecap="round"><path d="M10 40 54 58M54 40 10 58" stroke="#0a0b0c" stroke-width="9"/><path d="M10 40 54 58M54 40 10 58" stroke="#f2f3f0" stroke-width="5"/></g><g transform="translate(32 24) scale(1.55)"><path d="${SKULL}" fill="#f2f3f0" fill-rule="evenodd" stroke="#0a0b0c" stroke-width="1.2"/></g>`),
  diamond: () => emblem(`${shape('M16 8H48L60 24 32 58 4 24Z', '#5fd1e8')}<path d="M4 24H60M16 8 24 24 32 58 40 24 48 8M24 24 32 8 40 24" fill="none" stroke="#0a0b0c" stroke-width="1.6"/><path d="M16 8H32L24 24H4Z" fill="#fff" opacity=".45"/>`),
  helmet: () => emblem(`${shape('M8 42C8 22 18 8 32 8 46 8 56 22 56 42Z', '#4c5a35')}${shape('M3 40H61L58 49H6Z', '#39452a')}<path d="M16 40C16 28 22 16 32 12" fill="none" stroke="#fff" stroke-width="2" opacity=".2"/><path d="M26 50V56C26 58 38 58 38 56V50" fill="none" stroke="#0a0b0c" stroke-width="3"/><path d="M32 20 34 26H41L35.5 30 37.5 36 32 32 26.5 36 28.5 30 23 26H30Z" fill="#f2f3f0"/>`),
  swords: () => emblem(`<g transform="rotate(40 32 32)">${shape('M29 2H35L36 44H28Z', '#d7dde2')}${shape('M21 44H43V48H21ZM29 48H35V60H29Z', '#d6a530')}</g><g transform="rotate(-40 32 32)">${shape('M29 2H35L36 44H28Z', '#f2f3f0')}${shape('M21 44H43V48H21ZM29 48H35V60H29Z', '#d6a530')}</g>`),
  medal: () => emblem(`${shape('M14 2H28L34 26H24ZM50 2H36L30 26H40Z', '#b3272d')}<circle cx="32" cy="40" r="20" fill="#d6a530" ${OUTLINE}/><circle cx="32" cy="40" r="15" fill="none" stroke="#7d5812" stroke-width="1.6"/><path d="M32 28 35.5 36 44 36.5 37.5 42 39.5 50 32 45.5 24.5 50 26.5 42 20 36.5 28.5 36Z" fill="#fff0a8" stroke="#7d5812"/>`),
  king: () => emblem(`<g transform="translate(32 38) scale(1.6)"><path d="${SKULL}" fill="#f2f3f0" fill-rule="evenodd" stroke="#0a0b0c" stroke-width="1.2"/></g>${shape('M12 8 21 18 32 3 43 18 52 8 49 26H15Z', '#f2c230')}<g stroke="#0a0b0c"><circle cx="24" cy="22" r="2" fill="#e5484d"/><circle cx="32" cy="22" r="2" fill="#5fd1e8"/><circle cx="40" cy="22" r="2" fill="#e5484d"/></g>`),
};

// Insignes de Prestige : l'emblème sert aussi d'écusson de rang (RankBadge), la bannière reprend ses couleurs.
const PRESTIGE_COLORS = [
  { metal: '#b87333', light: '#eab283', dark: '#2e1c10' }, // bronze
  { metal: '#aeb7c0', light: '#f2f5f7', dark: '#23272c' }, // argent
  { metal: '#d9a227', light: '#ffe48f', dark: '#33260a' }, // or
  { metal: '#d8353b', light: '#ff9d92', dark: '#330d10' }, // rubis
  { metal: '#2f7fd6', light: '#a5d4ff', dark: '#0c2138' }, // saphir
  { metal: '#8a4fd8', light: '#d9bcff', dark: '#22103a' }, // améthyste
  { metal: '#22ad78', light: '#a8f6d6', dark: '#0a2d22' }, // émeraude
  { metal: '#ec7a1c', light: '#ffc98c', dark: '#361a06' }, // braise
  { metal: '#cfd6dd', light: '#ffffff', dark: '#0a0b0d' }, // platine
  { metal: '#f2b90f', light: '#fff3b0', dark: '#4a0b0b' }, // légende
];
const INSIGNIA_SHIELD = 'M32 4 55 13V33C55 46 45 55 32 60 19 55 9 46 9 33V13Z';
const INSIGNIA_HEXAGON = 'M32 3 57 17V47L32 61 7 47V17Z';
const INSIGNIA_WING_LEFT = 'M20 22C14 16 8 15 1 17 3 21 5 22 8 23 5 24 4 26 4 28 7 29 10 28 12 29 10 31 10 33 11 36 14 36 17 35 20 36Z';
const INSIGNIA_WING_RIGHT = 'M44 22C50 16 56 15 63 17 61 21 59 22 56 23 59 24 60 26 60 28 57 29 54 28 52 29 54 31 54 33 53 36 50 36 47 35 44 36Z';
const INSIGNIA_STAR = 'M0-11 3.2-3.4 11-3.4 4.8 1.4 7 9 0 4.4-7 9-4.8 1.4-11-3.4-3.2-3.4Z';
/** Étoile à `points` branches autour du centre de l'emblème */
const sunburst = (points, outer, inner) =>
  `M${Array.from({ length: points * 2 }, (_, index) => {
    const angle = (index / points) * Math.PI - Math.PI / 2;
    const radius = index % 2 ? inner : outer;
    return `${fix(32 + Math.cos(angle) * radius)} ${fix(32 + Math.sin(angle) * radius)}`;
  }).join('L')}Z`;
const insigniaChevrons = (count, top) =>
  times(count, (index) => `<path d="M19 ${top + index * 8} 32 ${top + 7 + index * 8} 45 ${top + index * 8}" fill="none" stroke="url(#metal)" stroke-width="4.6" stroke-linejoin="round"/>`);
const insigniaStar = (y, scale = 1) => `<path transform="translate(32 ${y}) scale(${scale})" d="${INSIGNIA_STAR}" fill="url(#metal)" ${OUTLINE}/>`;
const insigniaSkull = (y, scale) => `<g transform="translate(32 ${y}) scale(${scale})"><path d="${SKULL}" fill="url(#metal)" fill-rule="evenodd" stroke="#0a0b0c"/></g>`;
const insigniaFrame = (d) => `<path d="${d}" fill="url(#plate)" stroke="url(#metal)" stroke-width="3" stroke-linejoin="round"/>`;
const insigniaWings = `<path d="${INSIGNIA_WING_LEFT}" fill="url(#metal)" ${OUTLINE}/><path d="${INSIGNIA_WING_RIGHT}" fill="url(#metal)" ${OUTLINE}/>`;
const insigniaCrown = `<path d="M18 21 16 8 24 14 32 4 40 14 48 8 46 21Z" fill="url(#metal)" ${OUTLINE}/>`;

const INSIGNIA_BODIES = [
  () => insigniaFrame(INSIGNIA_SHIELD) + insigniaStar(21, 0.8) + insigniaChevrons(1, 36),
  () => insigniaFrame(INSIGNIA_SHIELD) + insigniaStar(19, 0.72) + insigniaChevrons(2, 31),
  () => insigniaFrame(INSIGNIA_SHIELD) + insigniaStar(17, 0.64) + insigniaChevrons(3, 27),
  () => insigniaFrame(INSIGNIA_HEXAGON) + insigniaStar(32, 1.7),
  () => insigniaFrame(INSIGNIA_HEXAGON) + insigniaStar(25, 1.2) + insigniaChevrons(2, 37),
  () => insigniaFrame(sunburst(8, 31, 22)) + insigniaStar(32, 1.45),
  () => insigniaWings + insigniaFrame(INSIGNIA_SHIELD.replace('M32 4 55 13V33', 'M32 8 47 14V33').replace('C55 46 45 55 32 60 19 55 9 46 9 33V13Z', 'C47 44 41 51 32 56 23 51 17 44 17 33V14Z')) + insigniaStar(30, 1.05),
  () => insigniaWings + insigniaFrame(INSIGNIA_SHIELD.replace('M32 4 55 13V33', 'M32 8 47 14V33').replace('C55 46 45 55 32 60 19 55 9 46 9 33V13Z', 'C47 44 41 51 32 56 23 51 17 44 17 33V14Z')) + insigniaSkull(30, 0.95),
  () => insigniaFrame(sunburst(12, 31, 24)) + insigniaSkull(32, 1.25),
  () => insigniaFrame(sunburst(16, 31, 25)) + insigniaSkull(37, 1.1) + insigniaCrown,
];
const insigniaDefs = ({ metal, light, dark }) =>
  `<defs>${gradient('metal', [[0, light], [0.55, metal], [1, metal]])}${gradient('plate', [[0, dark], [1, '#08090a']])}</defs>`;

PRESTIGE_COLORS.forEach((colors, index) => {
  const level = index + 1;
  const body = INSIGNIA_BODIES[index]();
  EMBLEMS[`prestige${level}`] = () => emblem(insigniaDefs(colors) + body);
  BANNERS[`prestige${level}`] = () => banner(
    `${insigniaDefs(colors)}${gradient('prestigeBack', [[0, colors.dark], [0.6, colors.dark], [1, colors.metal]], false)}${rect('url(#prestigeBack)')}`
    + times(14, (stripe) => `<path d="M${150 + stripe * 22} -10 ${176 + stripe * 22} 40 ${150 + stripe * 22} 90" fill="none" stroke="${colors.light}" stroke-width="5" opacity="${fix(0.03 + stripe * 0.012)}"/>`)
    + `<rect width="${W}" height="2" fill="${colors.light}" opacity=".6"/><rect y="${H - 2}" width="${W}" height="2" fill="${colors.light}" opacity=".6"/>`
    + `<g transform="translate(322 4) scale(1.13)">${body}</g>`,
  );
});

for (const [folder, art] of [['banners', BANNERS], ['emblems', EMBLEMS]]) {
  const dir = path.join(OUT, folder);
  fs.mkdirSync(dir, { recursive: true });
  for (const [id, draw] of Object.entries(art)) fs.writeFileSync(path.join(dir, `${id}.svg`), draw());
  console.log(`${folder} : ${Object.keys(art).length} dessins`);
}
