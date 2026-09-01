// Генератор иконки приложения: пишет PNG без внешних зависимостей.
const fs = require('fs');
const zlib = require('zlib');

const SIZE = Number(process.argv[3] || 1024);
const OUT = process.argv[2];

// --- PNG ---------------------------------------------------------------
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
    t[n] = c;
  }
  return t;
})();

function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length);
  const body = Buffer.concat([Buffer.from(type, 'ascii'), data]);
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(body));
  return Buffer.concat([len, body, crc]);
}

function writePNG(path, width, height, rgb) {
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;      // бит на канал
  ihdr[9] = 2;      // truecolor RGB
  const raw = Buffer.alloc(height * (width * 3 + 1));
  for (let y = 0; y < height; y++) {
    const rowStart = y * (width * 3 + 1);
    raw[rowStart] = 0;                       // фильтр None
    rgb.copy(raw, rowStart + 1, y * width * 3, (y + 1) * width * 3);
  }
  fs.writeFileSync(path, Buffer.concat([
    Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]),
    chunk('IHDR', ihdr),
    chunk('IDAT', zlib.deflateSync(raw, { level: 9 })),
    chunk('IEND', Buffer.alloc(0)),
  ]));
}

// --- Геометрия ---------------------------------------------------------
const clamp01 = v => (v < 0 ? 0 : v > 1 ? 1 : v);
const mix = (a, b, t) => a + (b - a) * t;
const smooth = t => { const x = clamp01(t); return x * x * (3 - 2 * x); };

// Знаковое расстояние до скруглённого прямоугольника.
function sdRoundRect(px, py, cx, cy, hw, hh, r) {
  const qx = Math.abs(px - cx) - (hw - r);
  const qy = Math.abs(py - cy) - (hh - r);
  const ax = Math.max(qx, 0), ay = Math.max(qy, 0);
  return Math.sqrt(ax * ax + ay * ay) + Math.min(Math.max(qx, qy), 0) - r;
}

const S = SIZE / 1024;                 // масштаб от эталонных 1024
const coverage = d => clamp01(0.5 - d / S);   // сглаживание шириной в пиксель

// --- Палитра -----------------------------------------------------------
const G_TOP    = [0x7E, 0x9B, 0xFF];   // светлый верх
const G_MID    = [0x4A, 0x5A, 0xE0];
const G_BOTTOM = [0x2C, 0x22, 0x86];   // фиолетовая глубина
const CARD     = [0xFC, 0xFC, 0xFF];
const HEADER   = [0x33, 0x3F, 0xC0];
const CELL     = [0x4A, 0x5A, 0xE0];
const ACCENT   = [0xFF, 0x9F, 0x2E];

const CARD_CX = 512 * S, CARD_CY = 556 * S;
const CARD_HW = 302 * S, CARD_HH = 264 * S, CARD_R = 66 * S;
const HEADER_BOTTOM = CARD_CY - CARD_HH + 100 * S;

const buf = Buffer.alloc(SIZE * SIZE * 3);

for (let y = 0; y < SIZE; y++) {
  for (let x = 0; x < SIZE; x++) {
    const px = x + 0.5, py = y + 0.5;
    const u = px / SIZE, v = py / SIZE;

    // Диагональный градиент в три остановки — плоская заливка выглядит мёртво.
    const t = clamp01(v * 0.78 + u * 0.22);
    let r, g, b;
    if (t < 0.5) {
      const k = t / 0.5;
      r = mix(G_TOP[0], G_MID[0], k); g = mix(G_TOP[1], G_MID[1], k); b = mix(G_TOP[2], G_MID[2], k);
    } else {
      const k = (t - 0.5) / 0.5;
      r = mix(G_MID[0], G_BOTTOM[0], k); g = mix(G_MID[1], G_BOTTOM[1], k); b = mix(G_MID[2], G_BOTTOM[2], k);
    }

    // Мягкая подсветка сверху слева — даёт объём.
    const glow = Math.pow(1 - clamp01(Math.hypot(u - 0.3, v - 0.18) / 0.75), 2.4) * 0.30;
    r = mix(r, 255, glow); g = mix(g, 255, glow); b = mix(b, 255, glow);

    // Тень под карточкой: тот же силуэт, сдвинутый вниз и размытый.
    const shadow = 1 - smooth((sdRoundRect(px, py + 26 * S, CARD_CX, CARD_CY, CARD_HW, CARD_HH, CARD_R) / S + 34) / 46);
    if (shadow > 0) {
      const k = shadow * 0.34;
      r = mix(r, 0x14, k); g = mix(g, 0x10, k); b = mix(b, 0x3A, k);
    }

    // Корпус карточки.
    const card = coverage(sdRoundRect(px, py, CARD_CX, CARD_CY, CARD_HW, CARD_HH, CARD_R));
    if (card > 0) {
      r = mix(r, CARD[0], card); g = mix(g, CARD[1], card); b = mix(b, CARD[2], card);
    }

    // Шапка карточки.
    const header = card * clamp01((HEADER_BOTTOM - py) / S + 0.5);
    if (header > 0) {
      r = mix(r, HEADER[0], header); g = mix(g, HEADER[1], header); b = mix(b, HEADER[2], header);
    }

    // Два кольца-переплёта.
    for (const ringX of [416 * S, 608 * S]) {
      const ring = coverage(
        Math.abs(sdRoundRect(px, py, ringX, CARD_CY - CARD_HH - 4 * S, 18 * S, 60 * S, 18 * S)) - 9 * S
      );
      if (ring > 0) {
        r = mix(r, 255, ring); g = mix(g, 255, ring); b = mix(b, 255, ring);
      }
    }

    // Сетка занятий: три ряда, один слот выделен акцентом.
    for (let row = 0; row < 3; row++) {
      for (let col = 0; col < 3; col++) {
        const cx = (400 + col * 112) * S;
        const cy = (600 + row * 104) * S;
        const isAccent = row === 1 && col === 2;
        const cell = coverage(sdRoundRect(px, py, cx, cy, 38 * S, 29 * S, 14 * S));
        if (cell > 0) {
          const color = isAccent ? ACCENT : CELL;
          const alpha = isAccent ? cell : cell * 0.20;
          r = mix(r, color[0], alpha); g = mix(g, color[1], alpha); b = mix(b, color[2], alpha);
        }
      }
    }

    const i = (y * SIZE + x) * 3;
    buf[i] = Math.round(clamp01(r / 255) * 255);
    buf[i + 1] = Math.round(clamp01(g / 255) * 255);
    buf[i + 2] = Math.round(clamp01(b / 255) * 255);
  }
}

writePNG(OUT, SIZE, SIZE, buf);
console.log('Записано: ' + OUT + ' (' + SIZE + 'x' + SIZE + ', ' + fs.statSync(OUT).size + ' байт)');
