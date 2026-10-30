/**
 * Fond de l'écran de chargement : une carte tactique générée (relief, courbes de niveau, quartiers,
 * carroyage). Toujours la même grâce au bruit déterministe, dessinée une seule fois sur un canvas
 * pour ne pas charger le processeur pendant que le jeu démarre.
 */

/** Repère de la carte, partagé avec les éléments posés dessus (TacticalMap) */
export const MAP_WIDTH = 1600;
export const MAP_HEIGHT = 900;

const CELL = 4;
const COLS = MAP_WIDTH / CELL + 1;
const ROWS = MAP_HEIGHT / CELL + 1;
const CONTOUR_STEP = 0.13;
const CONTOUR_COUNT = 12;
const GRID_STEP = 100;
const BLOCK_STEP = 9;
const BLOCK_ANGLE = -0.42;
/** Les autoroutes, tracées à la main sur les terres */
const HIGHWAYS = [
  'M905 0 C 985 150, 1035 280, 960 430 S 900 690, 1120 900',
  'M960 430 C 1120 330, 1290 450, 1600 385',
  'M1120 900 C 1220 740, 1340 640, 1600 690',
  'M1035 215 C 1200 150, 1330 60, 1400 0',
];

const hash = (x: number, y: number): number => {
  const value = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return value - Math.floor(value);
};

const smooth = (value: number): number => value * value * (3 - 2 * value);

const noise = (x: number, y: number): number => {
  const ix = Math.floor(x);
  const iy = Math.floor(y);
  const fx = smooth(x - ix);
  const fy = smooth(y - iy);
  const top = hash(ix, iy) * (1 - fx) + hash(ix + 1, iy) * fx;
  const bottom = hash(ix, iy + 1) * (1 - fx) + hash(ix + 1, iy + 1) * fx;
  return top * (1 - fy) + bottom * fy;
};

const fractal = (x: number, y: number): number => {
  let sum = 0;
  let amplitude = 0.5;
  let frequency = 1;
  for (let octave = 0; octave < 6; octave += 1) {
    sum += noise(x * frequency + octave * 17, y * frequency + octave * 31) * amplitude;
    amplitude *= 0.5;
    frequency *= 2.03;
  }
  return sum;
};

/** Altitude : la côte court en diagonale, la mer reste à gauche, sous les textes. */
const altitude = (x: number, y: number): number => {
  const inland = (x * 0.84 + y * 0.38 - 680) / 400;
  return inland + (fractal(x / 230, y / 230) - 0.5) * 1.9;
};

const buildHeights = (): Float32Array => {
  const heights = new Float32Array(COLS * ROWS);
  for (let row = 0; row < ROWS; row += 1) {
    for (let col = 0; col < COLS; col += 1) {
      heights[row * COLS + col] = altitude(col * CELL, row * CELL);
    }
  }
  return heights;
};

/** Teintes désaturées et ombrage venu du nord-ouest, comme une vue satellite de nuit. */
const paintRelief = (ctx: CanvasRenderingContext2D, heights: Float32Array): void => {
  const image = new ImageData(COLS, ROWS);
  for (let row = 0; row < ROWS; row += 1) {
    for (let col = 0; col < COLS; col += 1) {
      const index = row * COLS + col;
      const height = heights[index];
      const left = heights[row * COLS + Math.max(col - 1, 0)];
      const up = heights[Math.max(row - 1, 0) * COLS + col];
      const shade = (height - left + height - up) * 300;
      const pixel = index * 4;
      if (height < 0) {
        const depth = Math.min(-height / 0.5, 1);
        image.data[pixel] = 12 - 5 * depth;
        image.data[pixel + 1] = 19 - 9 * depth;
        image.data[pixel + 2] = 23 - 10 * depth;
      } else {
        const rise = Math.min(height / 1.5, 1);
        image.data[pixel] = 34 + 38 * rise + shade;
        image.data[pixel + 1] = 37 + 36 * rise + shade;
        image.data[pixel + 2] = 33 + 28 * rise + shade;
      }
      image.data[pixel + 3] = 255;
    }
  }
  const relief = document.createElement('canvas');
  relief.width = COLS;
  relief.height = ROWS;
  relief.getContext('2d')!.putImageData(image, 0, 0);
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = 'high';
  ctx.drawImage(relief, 0, 0, MAP_WIDTH, MAP_HEIGHT);
};

/** Segments d'une courbe de niveau dans une maille (carrés marchants). */
const traceContour = (ctx: CanvasRenderingContext2D, heights: Float32Array, level: number): void => {
  ctx.beginPath();
  for (let row = 0; row < ROWS - 1; row += 1) {
    for (let col = 0; col < COLS - 1; col += 1) {
      const a = heights[row * COLS + col] - level;
      const b = heights[row * COLS + col + 1] - level;
      const c = heights[(row + 1) * COLS + col + 1] - level;
      const d = heights[(row + 1) * COLS + col] - level;
      const points: [number, number][] = [];
      const x = col * CELL;
      const y = row * CELL;
      if (a < 0 !== b < 0) points.push([x + CELL * (a / (a - b)), y]);
      if (b < 0 !== c < 0) points.push([x + CELL, y + CELL * (b / (b - c))]);
      if (d < 0 !== c < 0) points.push([x + CELL * (d / (d - c)), y + CELL]);
      if (a < 0 !== d < 0) points.push([x, y + CELL * (a / (a - d))]);
      for (let index = 0; index + 1 < points.length; index += 2) {
        ctx.moveTo(points[index][0], points[index][1]);
        ctx.lineTo(points[index + 1][0], points[index + 1][1]);
      }
    }
  }
  ctx.stroke();
};

const paintContours = (ctx: CanvasRenderingContext2D, heights: Float32Array): void => {
  ctx.lineCap = 'round';
  for (let index = 1; index <= CONTOUR_COUNT; index += 1) {
    const major = index % 4 === 0;
    ctx.strokeStyle = major ? 'rgba(242, 243, 240, 0.3)' : 'rgba(242, 243, 240, 0.12)';
    ctx.lineWidth = major ? 0.9 : 0.6;
    traceContour(ctx, heights, index * CONTOUR_STEP);
  }
  // Le trait de côte, avec un halo dans l'eau
  ctx.strokeStyle = 'rgba(242, 243, 240, 0.08)';
  ctx.lineWidth = 7;
  traceContour(ctx, heights, 0);
  ctx.strokeStyle = 'rgba(242, 243, 240, 0.55)';
  ctx.lineWidth = 1.1;
  traceContour(ctx, heights, 0);
};

/** Quartiers : des pâtés de maisons en grille inclinée sur les terres basses. */
const paintBlocks = (ctx: CanvasRenderingContext2D, heights: Float32Array): void => {
  const cos = Math.cos(BLOCK_ANGLE);
  const sin = Math.sin(BLOCK_ANGLE);
  const reach = Math.ceil(MAP_WIDTH / BLOCK_STEP);
  ctx.save();
  ctx.translate(MAP_WIDTH / 2, MAP_HEIGHT / 2);
  ctx.rotate(BLOCK_ANGLE);
  for (let j = -reach; j <= reach; j += 1) {
    for (let i = -reach; i <= reach; i += 1) {
      const localX = i * BLOCK_STEP;
      const localY = j * BLOCK_STEP;
      const x = MAP_WIDTH / 2 + localX * cos - localY * sin;
      const y = MAP_HEIGHT / 2 + localX * sin + localY * cos;
      if (x < 0 || y < 0 || x >= MAP_WIDTH || y >= MAP_HEIGHT) continue;
      const height = heights[Math.floor(y / CELL) * COLS + Math.floor(x / CELL)];
      if (height < 0.05 || height > 0.75) continue;
      // Les grandes avenues : une rangée et une colonne sur six restent vides
      if (((i % 6) + 6) % 6 === 0 || ((j % 6) + 6) % 6 === 0) continue;
      const density = noise(x / 150 + 40, y / 150 + 9);
      if (density < 0.45) continue;
      const roll = hash(i, j);
      if (roll > (density - 0.45) * 3.2) continue;
      ctx.fillStyle = `rgba(242, 243, 240, ${(0.05 + hash(i + 7, j) * 0.15).toFixed(3)})`;
      ctx.fillRect(localX, localY, 3 + hash(j, i) * 5, 3 + hash(i, j + 3) * 5);
    }
  }
  ctx.restore();
};

const paintHighways = (ctx: CanvasRenderingContext2D): void => {
  ctx.strokeStyle = 'rgba(242, 243, 240, 0.28)';
  ctx.lineWidth = 1.5;
  HIGHWAYS.forEach((highway) => ctx.stroke(new Path2D(highway)));
};

const paintGrid = (ctx: CanvasRenderingContext2D): void => {
  ctx.strokeStyle = 'rgba(242, 243, 240, 0.05)';
  ctx.lineWidth = 0.7;
  ctx.beginPath();
  for (let x = GRID_STEP; x < MAP_WIDTH; x += GRID_STEP) {
    ctx.moveTo(x, 0);
    ctx.lineTo(x, MAP_HEIGHT);
  }
  for (let y = GRID_STEP; y < MAP_HEIGHT; y += GRID_STEP) {
    ctx.moveTo(0, y);
    ctx.lineTo(MAP_WIDTH, y);
  }
  ctx.stroke();
  ctx.strokeStyle = 'rgba(242, 243, 240, 0.3)';
  ctx.beginPath();
  for (let x = GRID_STEP; x < MAP_WIDTH; x += GRID_STEP) {
    for (let y = GRID_STEP; y < MAP_HEIGHT; y += GRID_STEP) {
      ctx.moveTo(x - 4, y);
      ctx.lineTo(x + 4, y);
      ctx.moveTo(x, y - 4);
      ctx.lineTo(x, y + 4);
    }
  }
  ctx.stroke();
};

/** Dessine la carte à la résolution de l'écran (la caméra zoome un peu : on garde de la marge). */
export function drawTerrain(canvas: HTMLCanvasElement): void {
  const scale = Math.min(Math.max((window.innerWidth * 1.15) / MAP_WIDTH, 1), 2.6);
  canvas.width = Math.round(MAP_WIDTH * scale);
  canvas.height = Math.round(MAP_HEIGHT * scale);
  const ctx = canvas.getContext('2d');
  if (!ctx) return;
  ctx.scale(scale, scale);
  const heights = buildHeights();
  paintRelief(ctx, heights);
  paintBlocks(ctx, heights);
  paintHighways(ctx);
  paintContours(ctx, heights);
  paintGrid(ctx);
}
