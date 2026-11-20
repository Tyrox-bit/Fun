// Erzeugt die Platzhalter-Grafiken (SVG) in assets/img.
// Aufruf: node scripts/generate-images.js  – danach ggf. npm run images:png
const fs = require('fs');
const path = require('path');
const OUT = path.join(__dirname, '..', 'assets', 'img');
fs.mkdirSync(OUT, { recursive: true });

// Damast-Wellen: viele phasenverschobene Sinuslinien, abwechselnd hell/dunkel.
function damascusLines({ x0, x1, y0, y1, spacing = 7, seed = 1, amp = 1 }) {
  const lines = [];
  let i = 0;
  for (let base = y0 - 40; base < y1 + 40; base += spacing, i++) {
    let d = '';
    for (let x = x0; x <= x1; x += 8) {
      const y =
        base +
        amp * 9 * Math.sin(x * 0.018 + i * 0.35 + seed) +
        amp * 5 * Math.sin(x * 0.047 - i * 0.21 + seed * 2) +
        amp * 2.5 * Math.sin(x * 0.11 + i * 0.9);
      d += (d ? ' L' : 'M') + x.toFixed(1) + ',' + y.toFixed(1);
    }
    const light = i % 2 === 0;
    lines.push(
      `<path d="${d}" fill="none" stroke="${light ? '#e9edf2' : '#2f353c'}" stroke-opacity="${light ? 0.6 : 0.5}" stroke-width="${light ? 2.2 : 3}"/>`
    );
  }
  return lines.join('');
}

function knife({ id, blade, edge, handle, bolster, rivets, bounds, seed, glint = 0 }) {
  return `
  <defs>
    <clipPath id="${id}-clip"><path d="${blade}"/></clipPath>
    <linearGradient id="${id}-steel" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#7a838d"/><stop offset=".5" stop-color="#b4bcc5"/><stop offset="1" stop-color="#5c646d"/>
    </linearGradient>
    <linearGradient id="${id}-sheen" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset=".45" stop-color="#fff" stop-opacity="0"/>
      <stop offset=".7" stop-color="#fff" stop-opacity=".18"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="${id}-glint" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#fff" stop-opacity="0"/><stop offset=".5" stop-color="#fff" stop-opacity=".9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/>
    </linearGradient>
    <linearGradient id="${id}-handle" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#2b2520"/><stop offset=".5" stop-color="#14110f"/><stop offset="1" stop-color="#050404"/>
    </linearGradient>
    <linearGradient id="${id}-bolster" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#6b737c"/><stop offset=".5" stop-color="#e3e7ec"/><stop offset="1" stop-color="#5a6169"/>
    </linearGradient>
  </defs>
  <path d="${handle}" fill="url(#${id}-handle)" stroke="#000" stroke-width="2"/>
  ${rivets.map(([cx, cy]) => `<circle cx="${cx}" cy="${cy}" r="7" fill="url(#${id}-bolster)" stroke="#222"/>`).join('')}
  <path d="${blade}" fill="url(#${id}-steel)"/>
  <g clip-path="url(#${id}-clip)">
    ${damascusLines({ ...bounds, seed })}
    <path d="${edge}" fill="#f3f6f9" fill-opacity=".55"/>
    <rect x="${bounds.x0}" y="${bounds.y0 - 50}" width="${bounds.x1 - bounds.x0}" height="${bounds.y1 - bounds.y0 + 100}" fill="url(#${id}-sheen)"/>
    ${glint ? `<g opacity=".75">
      <rect x="-60" y="${bounds.y0 - 80}" width="70" height="${bounds.y1 - bounds.y0 + 160}" fill="url(#${id}-glint)" transform="skewX(-24)"/>
      <animateTransform attributeName="transform" type="translate" dur="5s" begin="${glint}s" repeatCount="indefinite"
        values="${bounds.x0 - 160} 0; ${bounds.x1 + 160} 0; ${bounds.x1 + 160} 0" keyTimes="0; .28; 1" calcMode="spline" keySplines=".6 0 .3 1; 0 0 1 1"/>
    </g>` : ''}
  </g>
  <path d="${blade}" fill="none" stroke="#2a2f35" stroke-width="2"/>
  <path d="${bolster}" fill="url(#${id}-bolster)" stroke="#2a2f35" stroke-width="2"/>`;
}

// Kochmesser (Koordinaten im 1000×260 Raum)
const CHEF_OPTS = {
  id: 'chef',
  seed: 1.3,
  blade: 'M338,56 L760,60 C862,68 942,94 994,128 C902,190 780,214 600,217 L338,217 Z',
  edge: 'M338,196 L600,197 C770,194 890,170 975,136 L994,128 C902,190 780,214 600,217 L338,217 Z',
  handle: 'M40,104 C40,90 52,84 70,84 L310,90 L310,182 L70,188 C52,188 40,180 40,166 Z',
  bolster: 'M300,78 L346,72 L346,214 L300,196 Z',
  rivets: [[105, 136], [180, 136], [255, 136]],
  bounds: { x0: 330, x1: 1000, y0: 50, y1: 222 },
};
const CHEF = knife({ ...CHEF_OPTS, glint: 1.2 });

// Schälmesser
const PARING_OPTS = {
  id: 'par',
  seed: 4.1,
  blade: 'M338,96 L640,99 C716,103 770,113 812,128 C750,152 672,162 560,164 L338,164 Z',
  edge: 'M338,152 L560,153 C660,151 740,142 800,131 L812,128 C750,152 672,162 560,164 L338,164 Z',
  handle: 'M110,108 C110,99 118,95 130,95 L312,100 L312,160 L130,165 C118,165 110,160 110,151 Z',
  bolster: 'M302,92 L346,88 L346,166 L302,160 Z',
  rivets: [[165, 130], [240, 130]],
  bounds: { x0: 330, x1: 820, y0: 90, y1: 170 },
};
const PARING = knife({ ...PARING_OPTS, glint: 1.9 });

const svg = (vb, body, extra = '') =>
  `<svg xmlns="http://www.w3.org/2000/svg" viewBox="${vb}" ${extra}>${body}</svg>\n`;

fs.writeFileSync(path.join(OUT, 'knife-chef.svg'), svg('0 0 1020 260', CHEF, 'role="img" aria-label="Kochmesser (Platzhalter)"'));
fs.writeFileSync(path.join(OUT, 'knife-paring.svg'), svg('0 0 1020 260', PARING, 'role="img" aria-label="Schälmesser (Platzhalter)"'));

// Hero: beide Messer schräg übereinander, mit Glow
const HERO = `
  <defs>
    <radialGradient id="glow" cx=".55" cy=".5" r=".55">
      <stop offset="0" stop-color="#ff7a1a" stop-opacity=".35"/><stop offset=".55" stop-color="#ff7a1a" stop-opacity=".08"/><stop offset="1" stop-color="#ff7a1a" stop-opacity="0"/>
    </radialGradient>
    <filter id="shadow" x="-10%" y="-30%" width="120%" height="160%"><feDropShadow dx="0" dy="18" stdDeviation="16" flood-color="#000" flood-opacity=".7"/></filter>
  </defs>
  <rect width="1000" height="1000" fill="url(#glow)"/>
  <g filter="url(#shadow)" transform="translate(40,330) rotate(-28 500 130) scale(.95)">${CHEF}</g>
  <g filter="url(#shadow)" transform="translate(150,560) rotate(-28 500 130) scale(.82)">${PARING}</g>`;
fs.writeFileSync(path.join(OUT, 'hero.svg'), svg('0 0 1000 1000', HERO, 'role="img" aria-label="Kaspar Damast-Duo: Kochmesser und Schälmesser (Platzhalterbild)"'));

// Damast-Textur für Hintergründe
const TEX = `<rect width="800" height="400" fill="#0b0b0c"/>${damascusLines({ x0: 0, x1: 800, y0: 0, y1: 400, spacing: 9, seed: 2.2, amp: 1.6 })}`;
fs.writeFileSync(path.join(OUT, 'damascus.svg'), svg('0 0 800 400', TEX, 'preserveAspectRatio="xMidYMid slice"'));

// Logo-Platzhalter
const LOGO = `
  <g fill="currentColor">
    <path d="M24 8 L36 20 L36 52 L12 52 L12 20 Z"/>
    <text x="50" y="42" font-family="Anton, Impact, sans-serif" font-size="36" letter-spacing="6">KASPAR</text>
  </g>`;
fs.writeFileSync(path.join(OUT, 'logo.svg'), svg('0 0 250 60', LOGO, 'role="img" aria-label="Kaspar"'));

// Favicon
fs.writeFileSync(
  path.join(OUT, 'favicon.svg'),
  svg('0 0 64 64', '<rect width="64" height="64" rx="14" fill="#0b0b0c"/><path d="M32 8 L46 22 L46 56 L18 56 L18 22 Z" fill="#ff7a1a"/>')
);

console.log('SVGs erzeugt in', OUT);
