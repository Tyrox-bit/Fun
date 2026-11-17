import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { W, H, SEGMENTS, CAPTIONS, CAPTION_END, POPUPS, FX } from './timeline.js';

// ---------------------------------------------------------------- utils
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const rnd = mulberry32(72);
const R = (a = 0, b = 1) => a + (b - a) * rnd();
const clamp = (x, a = 0, b = 1) => Math.max(a, Math.min(b, x));
const lerp = (a, b, u) => a + (b - a) * u;
const smooth = (u) => { u = clamp(u); return u * u * (3 - 2 * u); };
const easeOut = (u) => 1 - Math.pow(1 - clamp(u), 3);
const easeIn = (u) => Math.pow(clamp(u), 3);
const hash = (n) => { const s = Math.sin(n * 127.1 + 311.7) * 43758.5453; return s - Math.floor(s); };
const noise1 = (x) => { const i = Math.floor(x), f = x - i; const u = f * f * (3 - 2 * f); return lerp(hash(i), hash(i + 1), u) * 2 - 1; };
const V = (x, y, z) => new THREE.Vector3(x, y, z);

function canvasTex(w, h, draw, srgb = true) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  draw(c.getContext('2d'), w, h);
  const t = new THREE.CanvasTexture(c);
  if (srgb) t.colorSpace = THREE.SRGBColorSpace;
  t.anisotropy = 8;
  return t;
}
function textTex(text, w, h, bg, fg, font) {
  return canvasTex(w, h, (g) => {
    g.fillStyle = bg; g.fillRect(0, 0, w, h);
    g.fillStyle = fg; g.font = font; g.textAlign = 'center'; g.textBaseline = 'middle';
    g.fillText(text, w / 2, h / 2 + 4);
  });
}

// ---------------------------------------------------------------- renderer
const glCanvas = document.getElementById('gl');
const out = document.getElementById('out');
const ctx = out.getContext('2d');

const renderer = new THREE.WebGLRenderer({ canvas: glCanvas, antialias: false, preserveDrawingBuffer: true, powerPreference: 'high-performance' });
renderer.setPixelRatio(1);
renderer.setSize(W, H, false);
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.0;

const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(60, W / H, 0.1, 3000);
scene.add(camera);

const rt = new THREE.WebGLRenderTarget(W, H, { type: THREE.HalfFloatType, samples: 4 });
const composer = new EffectComposer(renderer, rt);
composer.addPass(new RenderPass(scene, camera));
const bloom = new UnrealBloomPass(new THREE.Vector2(W / 2, H / 2), 0.9, 0.55, 0.8);
composer.addPass(bloom);
composer.addPass(new OutputPass());

const fxPass = new ShaderPass({
  uniforms: {
    tDiffuse: { value: null }, uTime: { value: 0 }, uRGB: { value: 0 }, uBlur: { value: 0 }, uGlitch: { value: 0 },
    uVig: { value: 1.1 }, uGrain: { value: 0.05 }, uBright: { value: 1 }, uSat: { value: 1 }, uPunch: { value: 0 },
    uTint: { value: new THREE.Vector3(1, 1, 1) },
  },
  vertexShader: `varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
  fragmentShader: `
    uniform sampler2D tDiffuse; uniform float uTime,uRGB,uBlur,uGlitch,uVig,uGrain,uBright,uSat,uPunch; uniform vec3 uTint;
    varying vec2 vUv;
    float h(float n){ return fract(sin(n)*43758.5453); }
    vec3 samp(vec2 uv){
      float s = uRGB + 0.0015*length(uv-0.5);
      return vec3(texture2D(tDiffuse, uv+vec2(s,0.0)).r, texture2D(tDiffuse, uv).g, texture2D(tDiffuse, uv-vec2(s,0.0)).b);
    }
    void main(){
      vec2 uv = (vUv-0.5)/(1.0+uPunch)+0.5;
      if(uGlitch>0.0){
        float band = floor(uv.y*38.0);
        float r = h(band*13.1+floor(uTime*24.0));
        if(r>0.72) uv.x += (h(band+uTime)-0.5)*0.12*uGlitch;
      }
      vec3 col = vec3(0.0);
      if(uBlur>0.002){
        for(int i=0;i<14;i++){ float o=(float(i)/13.0-0.5)*uBlur; col+=samp(uv+vec2(o,0.0)); }
        col/=14.0;
      } else col = samp(uv);
      float l = dot(col, vec3(0.299,0.587,0.114));
      col = mix(vec3(l), col, uSat) * uBright * uTint;
      vec2 d = vUv-0.5; d.x *= 0.62;
      col *= 1.0 - uVig*smoothstep(0.18, 0.75, length(d));
      col += (h(vUv.x*911.0+vUv.y*3571.0+uTime*61.0)-0.5)*uGrain;
      gl_FragColor = vec4(col,1.0);
    }`,
});
composer.addPass(fxPass);

// ---------------------------------------------------------------- shared textures
const poolTex = canvasTex(128, 128, (g, w, h) => {
  const gr = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
  gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.35, 'rgba(255,255,255,0.45)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, w, h);
});
const beamTex = canvasTex(256, 128, (g, w, h) => {
  const gr = g.createLinearGradient(0, 0, w, 0);
  gr.addColorStop(0, 'rgba(255,255,255,0.9)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.beginPath(); g.moveTo(0, h * 0.4); g.lineTo(w, 0); g.lineTo(w, h); g.lineTo(0, h * 0.6); g.closePath(); g.fill();
});
const smokeTex = canvasTex(128, 128, (g, w, h) => {
  const gr = g.createRadialGradient(w / 2, h / 2, 0, w / 2, h / 2, w / 2);
  gr.addColorStop(0, 'rgba(255,255,255,0.55)'); gr.addColorStop(1, 'rgba(255,255,255,0)');
  g.fillStyle = gr; g.fillRect(0, 0, w, h);
});

// facade + window emissive textures (16 units wide x 32 units tall: 8 cols x 10 floors)
function facadeSet(base, frame, glass, seed, litProb, palette) {
  const r = mulberry32(seed);
  const cols = 8, rows = 10, cw = 64, ch = 102;
  const lit = [];
  for (let i = 0; i < cols * rows; i++) lit.push(r() < litProb ? palette[Math.floor(r() * palette.length)] : null);
  const map = canvasTex(512, 1024, (g) => {
    g.fillStyle = base; g.fillRect(0, 0, 512, 1024);
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      g.fillStyle = frame; g.fillRect(x * cw + 8, y * ch + 14, cw - 16, ch - 30);
      g.fillStyle = glass; g.fillRect(x * cw + 11, y * ch + 17, cw - 22, ch - 36);
    }
    g.fillStyle = 'rgba(0,0,0,0.25)'; for (let y = 0; y < rows; y++) g.fillRect(0, y * ch, 512, 6);
  });
  const emis = canvasTex(512, 1024, (g) => {
    g.fillStyle = '#000'; g.fillRect(0, 0, 512, 1024);
    for (let y = 0; y < rows; y++) for (let x = 0; x < cols; x++) {
      const c = lit[y * cols + x]; if (!c) continue;
      const gr = g.createLinearGradient(0, y * ch + 17, 0, y * ch + ch - 19);
      gr.addColorStop(0, c); gr.addColorStop(1, 'rgba(0,0,0,0.7)');
      g.fillStyle = gr; g.fillRect(x * cw + 11, y * ch + 17, cw - 22, ch - 36);
    }
  });
  map.wrapS = map.wrapT = emis.wrapS = emis.wrapT = THREE.RepeatWrapping;
  return { map, emis };
}
const warm = ['#ffcf8a', '#ffd9a0', '#ffe2b8', '#fff1d6', '#bcd4ff', '#ffc070', '#9fc0ff'];
const FACADES = [
  facadeSet('#3a3f48', '#262a31', '#1a2230', 11, 0.55, warm),
  facadeSet('#4a4038', '#2e2722', '#1d2028', 12, 0.5, warm),
  facadeSet('#2a3340', '#1c232c', '#13243a', 13, 0.6, warm),
  facadeSet('#55555a', '#333338', '#1b1f27', 14, 0.45, warm),
];
const candleTex = (() => {
  const r = mulberry32(99);
  const t = canvasTex(512, 1024, (g) => {
    g.fillStyle = '#000'; g.fillRect(0, 0, 512, 1024);
    for (let y = 0; y < 10; y++) for (let x = 0; x < 8; x++) {
      if (r() > 0.12) continue;
      const cx = x * 64 + 32, cy = y * 102 + 60;
      const gr = g.createRadialGradient(cx, cy, 0, cx, cy, 30);
      gr.addColorStop(0, 'rgba(255,170,70,1)'); gr.addColorStop(1, 'rgba(255,120,30,0)');
      g.fillStyle = gr; g.fillRect(x * 64 + 11, y * 102 + 17, 42, 66);
    }
  });
  t.wrapS = t.wrapT = THREE.RepeatWrapping; return t;
})();
const hospTex = facadeSet('#d9dde2', '#aab2bb', '#2a3a48', 21, 0.9, ['#e8f4ff', '#d6ecff', '#ffffff', '#cfe6ff']);

// ---------------------------------------------------------------- sky
const skyMat = new THREE.ShaderMaterial({
  side: THREE.BackSide, depthWrite: false, fog: false,
  uniforms: { top: { value: new THREE.Color() }, hor: { value: new THREE.Color() }, glow: { value: new THREE.Color('#ff8a3d') }, glowAmt: { value: 0 } },
  vertexShader: `varying vec3 vP; void main(){ vP = position; gl_Position = projectionMatrix*modelViewMatrix*vec4(position,1.0); }`,
  fragmentShader: `uniform vec3 top,hor,glow; uniform float glowAmt; varying vec3 vP;
    void main(){ float h = normalize(vP).y; vec3 c = mix(hor, top, smoothstep(-0.02, 0.45, h)); c += glow*glowAmt*exp(-max(h,0.0)*9.0); gl_FragColor = vec4(c,1.0); }`,
});
const sky = new THREE.Mesh(new THREE.SphereGeometry(1500, 32, 16), skyMat);
scene.add(sky);
const stars = (() => {
  const g = new THREE.BufferGeometry(); const p = [];
  for (let i = 0; i < 1600; i++) {
    const th = R(0, Math.PI * 2), y = R(0.08, 1); const r = Math.sqrt(1 - y * y);
    p.push(Math.cos(th) * r * 1400, y * 1400, Math.sin(th) * r * 1400);
  }
  g.setAttribute('position', new THREE.Float32BufferAttribute(p, 3));
  return new THREE.Points(g, new THREE.PointsMaterial({ color: 0xffffff, size: 2.2, sizeAttenuation: false, transparent: true, opacity: 0.85, fog: false }));
})();
scene.add(stars);
const moon = new THREE.Mesh(new THREE.SphereGeometry(28, 24, 16), new THREE.MeshBasicMaterial({ color: new THREE.Color(2.2, 2.2, 2.0), fog: false }));
moon.position.set(-500, 520, -900); scene.add(moon);

const hemi = new THREE.HemisphereLight(0x7f95d8, 0x1c1a24, 0.3); scene.add(hemi);
const sun = new THREE.DirectionalLight(0x99aadd, 0.4); sun.position.set(-300, 400, -200); scene.add(sun);
const fill = new THREE.DirectionalLight(0x5a78d0, 0); fill.position.set(320, 180, 420); scene.add(fill);
scene.fog = new THREE.FogExp2(0x000000, 0.003);

const PRESETS = {
  nightLit: { top: '#04060f', hor: '#1c1a33', glowAmt: 0.55, fog: '#16132a', fogD: 0.0032, hemi: 0.7, sun: 0.9, sunC: '#8899dd', fill: 0.6, stars: 0.5, moon: true, bg: null },
  nightDark: { top: '#02040c', hor: '#0e1630', glowAmt: 0.0, fog: '#0a1022', fogD: 0.0030, hemi: 1.3, sun: 1.9, sunC: '#7f9bff', fill: 1.6, stars: 1, moon: true, bg: null },
  morning: { top: '#5d6774', hor: '#b2b7bb', glowAmt: 0, fog: '#a3a9ae', fogD: 0.0042, hemi: 1.1, sun: 1.0, sunC: '#e8e6e0', stars: 0, moon: false, bg: null },
  xray: { bg: '#010409', hemi: 0.2, sun: 0.0, sunC: '#ffffff', fog: '#010409', fogD: 0.004 },
  indoor: { bg: '#000000', hemi: 0.06, sun: 0.0, sunC: '#ffffff', fog: '#000000', fogD: 0.02 },
};
function applyPreset(p) {
  if (p.bg) { scene.background = new THREE.Color(p.bg); sky.visible = false; stars.visible = false; moon.visible = false; }
  else {
    scene.background = null; sky.visible = true;
    skyMat.uniforms.top.value.set(p.top); skyMat.uniforms.hor.value.set(p.hor); skyMat.uniforms.glowAmt.value = p.glowAmt;
    stars.visible = p.stars > 0; stars.material.opacity = p.stars * 0.85; moon.visible = p.moon;
  }
  scene.fog.color.set(p.fog); scene.fog.density = p.fogD;
  hemi.intensity = p.hemi; sun.intensity = p.sun; sun.color.set(p.sunC); fill.intensity = p.fill || 0;
}

// ---------------------------------------------------------------- city
const city = new THREE.Group(); scene.add(city);
const PITCH = 50, NB = 6, HALF = 7;
const roadTex = canvasTex(1024, 1024, (g) => {
  const s = 1024 / 50, edge = HALF * s;
  g.fillStyle = '#1d1f24'; g.fillRect(0, 0, 1024, 1024);
  for (let i = 0; i < 9000; i++) { g.fillStyle = `rgba(255,255,255,${Math.random() * 0.03})`; g.fillRect(Math.random() * 1024, Math.random() * 1024, 2, 2); }
  g.fillStyle = '#3b3e45'; g.fillRect(edge, edge, 1024 - 2 * edge, 1024 - 2 * edge);
  g.fillStyle = '#2c2f35'; g.fillRect(edge + 3.5 * s, edge + 3.5 * s, 1024 - 2 * edge - 7 * s, 1024 - 2 * edge - 7 * s);
  g.strokeStyle = '#55585f'; g.lineWidth = 4; g.strokeRect(edge, edge, 1024 - 2 * edge, 1024 - 2 * edge);
  g.fillStyle = '#c9c4b5';
  for (let p = edge + 20; p < 1024 - edge - 20; p += 46) { g.fillRect(p, 0, 26, 4); g.fillRect(p, 1020, 26, 4); g.fillRect(0, p, 4, 26); g.fillRect(1020, p, 4, 26); }
  // crosswalks
  const zebra = (x, y, w, h, horiz) => { for (let k = 0; k < 7; k++) horiz ? g.fillRect(x + k * (w / 7), y, w / 14, h) : g.fillRect(x, y + k * (h / 7), w, h / 14); };
  zebra(edge + 6, 0, 2 * s * 1.2, edge - 6, true); zebra(edge + 6, 1024 - edge + 6, 2 * s * 1.2, edge - 6, true);
  zebra(0, edge + 6, edge - 6, 2 * s * 1.2, false); zebra(1024 - edge + 6, edge + 6, edge - 6, 2 * s * 1.2, false);
});
roadTex.wrapS = roadTex.wrapT = THREE.RepeatWrapping; roadTex.repeat.set(13, 13);
const groundMat = new THREE.MeshStandardMaterial({ map: roadTex, roughness: 0.92, metalness: 0.0 });
const ground = new THREE.Mesh(new THREE.PlaneGeometry(650, 650), groundMat);
ground.rotation.x = -Math.PI / 2; city.add(ground);
const outer = new THREE.Mesh(new THREE.PlaneGeometry(6000, 6000), new THREE.MeshStandardMaterial({ color: 0x15171b, roughness: 1 }));
outer.rotation.x = -Math.PI / 2; outer.position.y = -0.05; city.add(outer);

const roofMat = new THREE.MeshStandardMaterial({ color: 0x24262b, roughness: 0.9 });
const buildings = [];
const RESERVED = { '2,-1': 'tower', '-2,1': 'gas', '-2,-2': 'hosp' };
function addBuilding(cx, cz, w, d, h, opts = {}) {
  const geo = new THREE.BoxGeometry(w, h, d);
  const uv = geo.attributes.uv;
  const ou = Math.floor(R(0, 8)) / 8, ov = Math.floor(R(0, 10)) / 10;
  for (let f = 0; f < 6; f++) {
    if (f === 2 || f === 3) continue;
    const span = (f < 2) ? d : w;
    for (let k = 0; k < 4; k++) { const i = f * 4 + k; uv.setXY(i, uv.getX(i) * span / 16 + ou, uv.getY(i) * h / 32 + ov); }
  }
  const fs = opts.facade || FACADES[Math.floor(R(0, FACADES.length))];
  const mat = new THREE.MeshStandardMaterial({ map: fs.map, emissiveMap: fs.emis, emissive: new THREE.Color(1, 1, 1), emissiveIntensity: 1, roughness: 0.75, metalness: 0.1 });
  const mesh = new THREE.Mesh(geo, [mat, mat, roofMat, roofMat, mat, mat]);
  mesh.position.set(cx, h / 2, cz);
  city.add(mesh);
  const dist = Math.hypot(cx, cz);
  const b = { mesh, mat, base: fs.emis, off: 0.95 + dist / 420 + R(0, 0.12), candle: R() < 0.16, always: !!opts.always, seed: R(0, 100), intensity: opts.intensity || 1 };
  buildings.push(b);
  // rooftop details
  if (h > 25 && R() < 0.6) {
    const ac = new THREE.Mesh(new THREE.BoxGeometry(w * 0.3, 2, d * 0.3), roofMat);
    ac.position.set(cx + R(-w * 0.2, w * 0.2), h + 1, cz + R(-d * 0.2, d * 0.2)); city.add(ac);
  }
  return b;
}
for (let i = -NB; i <= NB; i++) for (let j = -NB; j <= NB; j++) {
  if (RESERVED[`${i},${j}`]) continue;
  const bx = i * PITCH, bz = j * PITCH;
  const dist = Math.hypot(bx, bz);
  const tall = 12 + 95 * Math.exp(-Math.pow(dist / 140, 2));
  const split = R();
  const lots = split < 0.25 ? [[0, 0, 34, 34]] : split < 0.55 ? [[-8.5, 0, 16, 34], [8.5, 0, 16, 34]] : [[-8.5, -8.5, 16, 16], [8.5, -8.5, 16, 16], [-8.5, 8.5, 16, 16], [8.5, 8.5, 16, 16]];
  for (const [ox, oz, w, d] of lots) {
    if (i === 0 && j === 0 && ox > 0 && oz > 0) continue; // elevator tower lot
    const h = Math.max(7, tall * R(0.45, 1.25));
    addBuilding(bx + ox, bz + oz, w - R(0, 2), d - R(0, 2), h);
  }
}

// street lamps (instanced)
const lampPos = [];
for (let k = -7; k <= 6; k++) {
  const line = 25 + k * PITCH;
  for (let b = -NB; b <= NB; b++) for (const off of [-12, 12]) for (const side of [-1, 1]) {
    lampPos.push({ x: line + side * 6.2, z: b * PITCH + off, dir: 'z', side });
    lampPos.push({ x: b * PITCH + off, z: line + side * 6.2, dir: 'x', side });
  }
}
const poleMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(0.25, 7, 0.25), new THREE.MeshStandardMaterial({ color: 0x2b2e33, roughness: 0.6, metalness: 0.5 }), lampPos.length);
const headMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(4, 3.2, 2.2), toneMapped: false });
const headMesh = new THREE.InstancedMesh(new THREE.BoxGeometry(1.1, 0.25, 0.55), headMat, lampPos.length);
const lpoolMat = new THREE.MeshBasicMaterial({ map: poolTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(0.9, 0.62, 0.32) });
const lpoolMesh = new THREE.InstancedMesh(new THREE.PlaneGeometry(16, 16), lpoolMat, lampPos.length);
{
  const o = new THREE.Object3D();
  lampPos.forEach((l, i) => {
    l.off = 0.95 + Math.hypot(l.x, l.z) / 420 + R(0, 0.1);
    o.position.set(l.x, 3.5, l.z); o.rotation.set(0, 0, 0); o.updateMatrix(); poleMesh.setMatrixAt(i, o.matrix);
    const hx = l.dir === 'z' ? l.x - l.side * 0.8 : l.x, hz = l.dir === 'x' ? l.z - l.side * 0.8 : l.z;
    o.position.set(hx, 7, hz); o.rotation.set(0, l.dir === 'z' ? 0 : Math.PI / 2, 0); o.updateMatrix(); headMesh.setMatrixAt(i, o.matrix);
    o.position.set(hx, 0.06, hz); o.rotation.set(-Math.PI / 2, 0, 0); o.updateMatrix(); lpoolMesh.setMatrixAt(i, o.matrix);
    headMesh.setColorAt(i, new THREE.Color(1, 1, 1)); lpoolMesh.setColorAt(i, new THREE.Color(1, 1, 1));
  });
  city.add(poleMesh, headMesh, lpoolMesh);
}

// moving cars (instanced)
const CAR_COLORS = [0xb8bcc2, 0x1d2228, 0x8a1c1c, 0x24406e, 0xdedede, 0x3d4a3a, 0x5a5f66, 0x1a1a1a, 0x9c7a3c];
const movers = [];
const EXCL = new Set(['x25', 'z25', 'z175', 'x-25']);
for (let k = -7; k <= 6; k++) {
  const line = 25 + k * PITCH;
  for (const axis of ['x', 'z']) {
    const key = axis === 'x' ? `z${line}` : `x${line}`;
    if (EXCL.has(key)) continue;
    for (const dir of [1, -1]) {
      const n = Math.floor(R(2, 5));
      for (let c = 0; c < n; c++) movers.push({ axis, line, dir, lane: dir * 3, off: R(0, 650), speed: R(9, 15), col: CAR_COLORS[Math.floor(R(0, CAR_COLORS.length))], keep: R() });
    }
  }
}
const carBody = new THREE.InstancedMesh(new THREE.BoxGeometry(4.3, 1.0, 1.9), new THREE.MeshStandardMaterial({ roughness: 0.35, metalness: 0.6 }), movers.length);
const carCab = new THREE.InstancedMesh(new THREE.BoxGeometry(2.3, 0.8, 1.7), new THREE.MeshStandardMaterial({ color: 0x0b0e12, roughness: 0.15, metalness: 0.8 }), movers.length);
const headL = new THREE.InstancedMesh(new THREE.BoxGeometry(0.1, 0.22, 0.45), new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 6, 5.2), toneMapped: false }), movers.length * 2);
const tailL = new THREE.InstancedMesh(new THREE.BoxGeometry(0.1, 0.2, 0.45), new THREE.MeshBasicMaterial({ color: new THREE.Color(5, 0.2, 0.15), toneMapped: false }), movers.length * 2);
const beamMat = new THREE.MeshBasicMaterial({ map: beamTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(0.75, 0.72, 0.6) });
const beams = new THREE.InstancedMesh(new THREE.PlaneGeometry(14, 6), beamMat, movers.length);
movers.forEach((m, i) => carBody.setColorAt(i, new THREE.Color(m.col)));
city.add(carBody, carCab, headL, tailL, beams);
const _o = new THREE.Object3D(), _q = new THREE.Quaternion(), _v = new THREE.Vector3();
function placePart(mesh, i, base, yaw, lx, ly, lz, rx = 0, s = 1) {
  _v.set(lx, ly, lz).applyAxisAngle(V(0, 1, 0), yaw).add(base);
  _o.position.copy(_v); _o.rotation.set(rx, yaw, 0, 'YXZ'); _o.scale.setScalar(s); _o.updateMatrix(); mesh.setMatrixAt(i, _o.matrix);
}
function updateMovers(tau, frac, lightsOn) {
  movers.forEach((m, i) => {
    const s = m.keep < frac ? 1 : 0;
    let a = ((m.off + m.speed * tau * m.dir) % 650 + 650) % 650 - 325;
    const base = m.axis === 'x' ? V(a, 0, m.line + m.lane) : V(m.line + m.lane, 0, a);
    const yaw = m.axis === 'x' ? (m.dir > 0 ? 0 : Math.PI) : (m.dir > 0 ? -Math.PI / 2 : Math.PI / 2);
    placePart(carBody, i, base, yaw, 0, 0.75, 0, 0, s);
    placePart(carCab, i, base, yaw, -0.3, 1.6, 0, 0, s);
    const ls = s * (lightsOn ? 1 : 0);
    placePart(headL, i * 2, base, yaw, 2.16, 0.85, 0.62, 0, ls); placePart(headL, i * 2 + 1, base, yaw, 2.16, 0.85, -0.62, 0, ls);
    placePart(tailL, i * 2, base, yaw, -2.16, 0.9, 0.62, 0, ls); placePart(tailL, i * 2 + 1, base, yaw, -2.16, 0.9, -0.62, 0, ls);
    _v.set(9.2, 0.07, 0).applyAxisAngle(V(0, 1, 0), yaw).add(base);
    _o.position.copy(_v); _o.rotation.set(-Math.PI / 2, 0, yaw, 'YXZ'); _o.rotation.set(-Math.PI / 2, 0, 0); _o.rotateZ(yaw); _o.scale.setScalar(ls); _o.updateMatrix(); beams.setMatrixAt(i, _o.matrix);
  });
  for (const m of [carBody, carCab, headL, tailL, beams]) m.instanceMatrix.needsUpdate = true;
}

// static car builder
function makeCar(color, opts = {}) {
  const g = new THREE.Group();
  const body = new THREE.Mesh(new THREE.BoxGeometry(opts.len || 4.3, 1.0, 1.9), new THREE.MeshStandardMaterial({ color, roughness: 0.35, metalness: 0.6 }));
  body.position.y = 0.75; g.add(body);
  const cab = new THREE.Mesh(new THREE.BoxGeometry(2.3, 0.8, 1.7), new THREE.MeshStandardMaterial({ color: 0x0b0e12, roughness: 0.1, metalness: 0.8 }));
  cab.position.set(-0.3, 1.6, 0); g.add(cab);
  const wheelG = new THREE.CylinderGeometry(0.38, 0.38, 0.3, 14); const wheelM = new THREE.MeshStandardMaterial({ color: 0x0a0a0a, roughness: 0.9 });
  for (const [x, z] of [[1.4, 0.95], [1.4, -0.95], [-1.4, 0.95], [-1.4, -0.95]]) { const w = new THREE.Mesh(wheelG, wheelM); w.rotation.x = Math.PI / 2; w.position.set(x, 0.38, z); g.add(w); }
  const hlM = new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 6, 5.2), toneMapped: false });
  const tlM = new THREE.MeshBasicMaterial({ color: new THREE.Color(5, 0.2, 0.15), toneMapped: false });
  const hzM = new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 2.6, 0.2), toneMapped: false });
  const L = (opts.len || 4.3) / 2 + 0.01;
  for (const z of [0.62, -0.62]) {
    const h = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.22, 0.45), hlM); h.position.set(L, 0.85, z); g.add(h);
    const tl = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.2, 0.45), tlM); tl.position.set(-L, 0.9, z); g.add(tl);
    const hz1 = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.14, 0.18), hzM); hz1.position.set(L, 0.72, z * 1.35); g.add(hz1);
    const hz2 = new THREE.Mesh(new THREE.BoxGeometry(0.14, 0.14, 0.18), hzM); hz2.position.set(-L, 0.72, z * 1.35); g.add(hz2);
  }
  const beam = new THREE.Mesh(new THREE.PlaneGeometry(14, 6), beamMat); beam.rotation.x = -Math.PI / 2; beam.position.set(L + 7, 0.07, 0); g.add(beam);
  g.userData = { hlM, tlM, hzM, beam };
  return g;
}
function setCarLights(car, on, hazard) {
  car.userData.hlM.color.setRGB(6 * on, 6 * on, 5.2 * on);
  car.userData.tlM.color.setRGB(5 * on, 0.2 * on, 0.15 * on);
  car.userData.beam.visible = on > 0;
  car.userData.hzM.color.setRGB(6 * hazard, 2.6 * hazard, 0.2 * hazard);
}

// people
function makePerson(color) {
  const g = new THREE.Group();
  const m = new THREE.MeshStandardMaterial({ color, roughness: 0.8 });
  const body = new THREE.Mesh(new THREE.CapsuleGeometry(0.27, 0.85, 4, 10), m); body.position.y = 0.95; g.add(body);
  const head = new THREE.Mesh(new THREE.SphereGeometry(0.19, 12, 10), new THREE.MeshStandardMaterial({ color: 0xc89a7a, roughness: 0.7 })); head.position.y = 1.67; g.add(head);
  const lightM = new THREE.MeshBasicMaterial({ color: new THREE.Color(8, 8, 8), toneMapped: false });
  const phone = new THREE.Mesh(new THREE.SphereGeometry(0.07, 8, 6), lightM); phone.position.set(0.35, 1.3, 0); g.add(phone);
  const cone = new THREE.Mesh(new THREE.ConeGeometry(1.3, 5, 20, 1, true), new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.05, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  cone.geometry.translate(0, -2.5, 0); cone.position.copy(phone.position); cone.rotation.z = Math.PI / 2 - 0.42; g.add(cone);
  const pool = new THREE.Mesh(new THREE.PlaneGeometry(3.2, 3.2), new THREE.MeshBasicMaterial({ map: poolTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(1, 1, 1) }));
  pool.rotation.x = -Math.PI / 2; pool.position.set(3.4, 0.06, 0); g.add(pool);
  g.userData = { phone, cone, pool };
  return g;
}
function setFlash(p, on) { p.userData.phone.visible = on; p.userData.cone.visible = on; p.userData.pool.visible = on; }

// ---------------------------------------------------------------- set: intersection A (25,25)
const setA = new THREE.Group(); city.add(setA);
const tlights = [];
function makeTrafficLight(x, z, yaw) {
  const g = new THREE.Group(); g.position.set(x, 0, z); g.rotation.y = yaw;
  const pm = new THREE.MeshStandardMaterial({ color: 0x30343a, metalness: 0.6, roughness: 0.5 });
  const pole = new THREE.Mesh(new THREE.CylinderGeometry(0.14, 0.16, 5.2, 10), pm); pole.position.y = 2.6; g.add(pole);
  const box = new THREE.Mesh(new THREE.BoxGeometry(0.55, 1.6, 0.45), new THREE.MeshStandardMaterial({ color: 0x15171a, roughness: 0.6 })); box.position.set(0, 5.4, 0); g.add(box);
  const lamps = [];
  [[5.9, 0xff2a1a], [5.4, 0xffb000], [4.9, 0x22ff66]].forEach(([y, c], i) => {
    const m = new THREE.MeshBasicMaterial({ color: new THREE.Color(c).multiplyScalar(0.05), toneMapped: false });
    const l = new THREE.Mesh(new THREE.CircleGeometry(0.17, 16), m); l.position.set(0, y, 0.231); g.add(l);
    const hood = new THREE.Mesh(new THREE.BoxGeometry(0.42, 0.06, 0.18), box.material); hood.position.set(0, y + 0.2, 0.31); g.add(hood);
    lamps.push({ m, c: new THREE.Color(c) });
  });
  g.userData.lamps = lamps;
  return g;
}
for (const [x, z, yaw] of [[34, 34, Math.PI / 4], [16, 34, -Math.PI / 4], [16, 16, -3 * Math.PI / 4], [34, 16, 3 * Math.PI / 4]]) {
  const tl = makeTrafficLight(x, z, yaw); setA.add(tl); tlights.push(tl);
}
// elevator tower
const elevTower = addBuilding(9, 9, 16, 16, 72, {});
const shaft = new THREE.Mesh(new THREE.BoxGeometry(3.2, 72, 2.8), new THREE.MeshStandardMaterial({ color: 0x88aacc, transparent: true, opacity: 0.16, roughness: 0.05, metalness: 0.9, depthWrite: false }));
shaft.position.set(9, 36, 18.4); setA.add(shaft);
const shaftEdges = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(3.2, 72, 2.8)), new THREE.LineBasicMaterial({ color: 0xa8c4dc }));
shaftEdges.position.copy(shaft.position); setA.add(shaftEdges);
for (let y = 0; y < 72; y += 3.2) { const rail = new THREE.Mesh(new THREE.BoxGeometry(3.25, 0.12, 2.85), new THREE.MeshStandardMaterial({ color: 0x3a434c })); rail.position.set(9, y, 18.4); setA.add(rail); }
const cabinMat = new THREE.MeshStandardMaterial({ color: 0x1a2028, emissive: new THREE.Color(1, 0.1, 0.05), emissiveIntensity: 0, roughness: 0.2, metalness: 0.6, transparent: true, opacity: 0.55 });
const cabin = new THREE.Mesh(new THREE.BoxGeometry(2.6, 3.0, 2.2), cabinMat); cabin.position.set(9, 30, 18.4); setA.add(cabin);
const cabinLight = new THREE.Mesh(new THREE.BoxGeometry(2.0, 0.08, 1.6), new THREE.MeshBasicMaterial({ color: new THREE.Color(0, 0, 0), toneMapped: false }));
setA.add(cabinLight);
const cabinPeople = [];
for (const dx of [-0.5, 0.5]) { const p = makePerson(0x222233); p.scale.setScalar(0.95); p.rotation.y = -Math.PI / 2; setA.add(p); cabinPeople.push({ p, dx }); }
// stopped cars on the intersection
const carA1 = makeCar(0xd8d8d8); carA1.position.set(22.2, 0, 31); carA1.rotation.y = Math.PI / 2 + 0.25; setA.add(carA1);
const carA2 = makeCar(0x8a1c1c); carA2.position.set(28.5, 0, 25.6); carA2.rotation.y = Math.PI - 0.15; setA.add(carA2);
const carA3 = makeCar(0x24406e); carA3.position.set(28, 0, 6); carA3.rotation.y = Math.PI / 2 + 0.1; setA.add(carA3);
const carA4 = makeCar(0x1d2228); carA4.position.set(22, 0, 46); carA4.rotation.y = Math.PI / 2; setA.add(carA4);
const carA5 = makeCar(0x9c7a3c); carA5.position.set(22, 0, 54); carA5.rotation.y = Math.PI / 2; setA.add(carA5);
const carsA = [carA1, carA2, carA3, carA4, carA5];
const spotA = [];
for (const c of [carA1, carA2, carA3]) {
  const sp = new THREE.SpotLight(0xfff1d8, 220, 60, 0.42, 0.55, 1.5); sp.position.set(2.3, 0.9, 0); sp.target.position.set(12, -0.3, 0);
  c.add(sp); c.add(sp.target); spotA.push(sp);
}

// people on sidewalk of block (1,0) facing west edge x~31..33
const peopleA = [];
const pCols = [0x1f2a3a, 0x3a2a24, 0x262626, 0x4b4f58, 0x2e3b2a, 0x5a2a2a];
for (let i = 0; i < 11; i++) {
  const p = makePerson(pCols[i % pCols.length]);
  p.position.set(32.5 + R(-0.6, 1.4), 0, 1 + i * 1.9 + R(-0.4, 0.4));
  p.rotation.y = Math.PI + R(-0.9, 0.9);
  p.userData.on = 7.9 + R(0, 0.9) + (i % 3) * 0.12;
  setA.add(p); peopleA.push(p);
}
for (let i = 0; i < 7; i++) {
  const p = makePerson(pCols[(i + 2) % pCols.length]);
  p.position.set(17.5 + R(-0.5, 1.2), 0, 2 + i * 2.1 + R(-0.4, 0.4)); p.rotation.y = R(-1, 1);
  p.userData.on = 7.95 + R(0, 1.0); setA.add(p); peopleA.push(p);
}

// ---------------------------------------------------------------- set: cell tower (100,-50)
const setT = new THREE.Group(); setT.position.set(100, 0, -50); city.add(setT);
{
  const lot = new THREE.Mesh(new THREE.PlaneGeometry(34, 34), new THREE.MeshStandardMaterial({ color: 0x2a2b26, roughness: 1 }));
  lot.rotation.x = -Math.PI / 2; lot.position.y = 0.03; setT.add(lot);
  const steel = new THREE.MeshStandardMaterial({ color: 0x8b9096, metalness: 0.8, roughness: 0.4 });
  const strut = (a, b, r) => {
    const d = new THREE.Vector3().subVectors(b, a); const m = new THREE.Mesh(new THREE.CylinderGeometry(r, r, d.length(), 6), steel);
    m.position.copy(a).add(b).multiplyScalar(0.5); m.quaternion.setFromUnitVectors(V(0, 1, 0), d.normalize()); setT.add(m);
  };
  const Ht = 48, levels = 9; const w = (y) => lerp(3.4, 0.9, y / Ht);
  const corner = (y, k) => { const s = w(y); const c = [[s, s], [-s, s], [-s, -s], [s, -s]][k]; return V(c[0], y, c[1]); };
  for (let k = 0; k < 4; k++) strut(corner(0, k), corner(Ht, k), 0.16);
  for (let l = 0; l < levels; l++) {
    const y0 = l * Ht / levels, y1 = (l + 1) * Ht / levels;
    for (let k = 0; k < 4; k++) { const k2 = (k + 1) % 4; strut(corner(y0, k), corner(y1, k2), 0.06); strut(corner(y0, k2), corner(y1, k), 0.06); strut(corner(y1, k), corner(y1, k2), 0.06); }
  }
  const panelM = new THREE.MeshStandardMaterial({ color: 0xd8dade, roughness: 0.5 });
  for (let k = 0; k < 3; k++) for (const yy of [42, 46]) {
    const a = k * Math.PI * 2 / 3; const p = new THREE.Mesh(new THREE.BoxGeometry(0.5, 2.4, 0.9), panelM);
    p.position.set(Math.cos(a) * 1.9, yy, Math.sin(a) * 1.9); p.rotation.y = -a; setT.add(p);
  }
  const dish = new THREE.Mesh(new THREE.CylinderGeometry(0.9, 0.9, 0.4, 20), panelM); dish.rotation.z = Math.PI / 2; dish.position.set(1.6, 36, 0); setT.add(dish);
  const cab = new THREE.Mesh(new THREE.BoxGeometry(3, 2.2, 1.6), new THREE.MeshStandardMaterial({ color: 0x9aa0a6, roughness: 0.6 })); cab.position.set(-6, 1.1, 4); setT.add(cab);
  const fenceM = new THREE.MeshStandardMaterial({ color: 0x55595e, metalness: 0.6, roughness: 0.5, wireframe: true });
  for (const [x, z, ry] of [[0, 10, 0], [0, -10, 0], [10, 0, Math.PI / 2], [-10, 0, Math.PI / 2]]) {
    const f = new THREE.Mesh(new THREE.PlaneGeometry(20, 2.2, 20, 3), fenceM); f.position.set(x, 1.1, z); f.rotation.y = ry; setT.add(f);
  }
}
const towerRed = new THREE.Mesh(new THREE.SphereGeometry(0.35, 12, 10), new THREE.MeshBasicMaterial({ color: new THREE.Color(0, 0, 0), toneMapped: false }));
towerRed.position.set(0, 48.6, 0); setT.add(towerRed);
const towerRed2 = towerRed.clone(); towerRed2.material = towerRed.material; towerRed2.position.set(0, 30, 2.2); setT.add(towerRed2);
const cabLed = new THREE.Mesh(new THREE.BoxGeometry(0.2, 0.2, 0.05), new THREE.MeshBasicMaterial({ color: new THREE.Color(0, 0, 0), toneMapped: false }));
cabLed.position.set(-5.3, 1.7, 4.81); setT.add(cabLed);

// ---------------------------------------------------------------- set: gas station (-100,50)
const setG = new THREE.Group(); setG.position.set(-100, 0, 50); city.add(setG);
const gasPeople = [];
{
  const slab = new THREE.Mesh(new THREE.BoxGeometry(36, 0.1, 36), new THREE.MeshStandardMaterial({ color: 0x6d6e6c, roughness: 0.9 })); slab.position.y = 0.05; setG.add(slab);
  const white = new THREE.MeshStandardMaterial({ color: 0xe9ebee, roughness: 0.5 });
  const canopy = new THREE.Mesh(new THREE.BoxGeometry(24, 1.0, 15), white); canopy.position.set(0, 6.2, -4); setG.add(canopy);
  const stripe = new THREE.Mesh(new THREE.BoxGeometry(24.1, 0.35, 15.1), new THREE.MeshStandardMaterial({ color: 0x1f5fa8, roughness: 0.4 })); stripe.position.set(0, 6.1, -4); setG.add(stripe);
  const under = new THREE.Mesh(new THREE.PlaneGeometry(23, 14), new THREE.MeshStandardMaterial({ color: 0x3a3c40 })); under.rotation.x = Math.PI / 2; under.position.set(0, 5.69, -4); setG.add(under);
  for (const [x, z] of [[-6, -9], [6, -9], [-6, 1], [6, 1]]) { const c = new THREE.Mesh(new THREE.BoxGeometry(0.5, 5.7, 0.5), white); c.position.set(x, 2.85, z); setG.add(c); }
  const pumpM = new THREE.MeshStandardMaterial({ color: 0xd9dcdf, roughness: 0.5 });
  const screenM = new THREE.MeshStandardMaterial({ color: 0x0b0d10, roughness: 0.2 });
  for (const x of [-5, 5]) {
    const island = new THREE.Mesh(new THREE.BoxGeometry(1.4, 0.25, 9), new THREE.MeshStandardMaterial({ color: 0x8c8e90 })); island.position.set(x, 0.2, -4); setG.add(island);
    for (const z of [-6.5, -1.5]) {
      const p = new THREE.Mesh(new THREE.BoxGeometry(0.9, 2.1, 1.3), pumpM); p.position.set(x, 1.35, z); setG.add(p);
      for (const s of [-1, 1]) { const sc = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.55), screenM); sc.position.set(x + s * 0.46, 1.8, z); sc.rotation.y = s * Math.PI / 2; setG.add(sc); }
      const hose = new THREE.Mesh(new THREE.TorusGeometry(0.4, 0.05, 6, 16, Math.PI), new THREE.MeshStandardMaterial({ color: 0x111111 })); hose.position.set(x + 0.5, 1.2, z); hose.rotation.y = Math.PI / 2; setG.add(hose);
    }
  }
  const shop = new THREE.Mesh(new THREE.BoxGeometry(20, 5, 9), new THREE.MeshStandardMaterial({ color: 0xcfd2d6, roughness: 0.7 })); shop.position.set(0, 2.5, 11.5); setG.add(shop);
  const glass = new THREE.Mesh(new THREE.PlaneGeometry(12, 3.2), new THREE.MeshStandardMaterial({ color: 0x0d1418, roughness: 0.05, metalness: 0.9 })); glass.position.set(-2, 1.9, 6.99); glass.rotation.y = Math.PI; setG.add(glass);
  const sign = new THREE.Mesh(new THREE.PlaneGeometry(10, 1.4), new THREE.MeshStandardMaterial({ map: textTex('TANKSTELLE', 1024, 144, '#1f5fa8', '#ffffff', '900 96px Montserrat'), roughness: 0.5 }));
  sign.position.set(-2, 4.3, 6.98); sign.rotation.y = Math.PI; setG.add(sign);
  // ATM
  const atm = new THREE.Mesh(new THREE.BoxGeometry(1.0, 1.8, 0.5), new THREE.MeshStandardMaterial({ color: 0x5b6670, metalness: 0.5, roughness: 0.4 })); atm.position.set(7, 0.95, 6.75); setG.add(atm);
  const atmScr = new THREE.Mesh(new THREE.PlaneGeometry(0.55, 0.42), new THREE.MeshStandardMaterial({ color: 0x050607, roughness: 0.1 })); atmScr.position.set(7, 1.35, 6.49); atmScr.rotation.y = Math.PI; atmScr.rotation.x = 0.2; setG.add(atmScr);
  const atmLbl = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.22), new THREE.MeshStandardMaterial({ map: textTex('GELDAUTOMAT', 512, 128, '#c62828', '#ffffff', '900 62px Montserrat') })); atmLbl.position.set(7, 1.78, 6.49); atmLbl.rotation.y = Math.PI; setG.add(atmLbl);
  // price pylon
  const py = new THREE.Mesh(new THREE.BoxGeometry(2.2, 9, 0.6), new THREE.MeshStandardMaterial({ color: 0x1f5fa8 })); py.position.set(15, 4.5, -16); setG.add(py);
  const pr = new THREE.Mesh(new THREE.PlaneGeometry(2.0, 3.6), new THREE.MeshStandardMaterial({ map: canvasTex(256, 460, (g) => { g.fillStyle = '#0a0a0a'; g.fillRect(0, 0, 256, 460); g.fillStyle = '#333'; g.font = '900 64px Montserrat'; g.textAlign = 'center'; ['--,--', '--,--', '--,--'].forEach((s, i) => g.fillText(s, 128, 110 + i * 130)); }) }));
  pr.position.set(15, 5.5, -15.69); setG.add(pr);
  // cars at pumps
  for (const [x, z] of [[-3.3, -6.5], [3.3, -6.5], [-3.3, -1.5], [6.7, -1.5]]) { const c = makeCar(CAR_COLORS[Math.floor(R(0, 9))]); c.position.set(x, 0.1, z); c.rotation.y = Math.PI / 2; setG.add(c); setCarLights(c, 0, 0); }
  // queues on road z=25 -> local z=-25
  for (let i = 0; i < 16; i++) { const c = makeCar(CAR_COLORS[Math.floor(R(0, 9))]); c.position.set(-9 - i * 5.6, 0, -28); c.rotation.y = 0; setG.add(c); setCarLights(c, 0, 0); }
  for (let i = 0; i < 12; i++) { const c = makeCar(CAR_COLORS[Math.floor(R(0, 9))]); c.position.set(8 + i * 5.6, 0, -22); c.rotation.y = Math.PI; setG.add(c); setCarLights(c, 0, 0); }
  for (let i = 0; i < 12; i++) { const p = makePerson(pCols[i % 6]); p.position.set(R(-12, 12), 0.1, R(-12, 4)); if (i > 7) p.position.set(-12 - i * 3, 0, -31); p.rotation.y = R(0, 6); setFlash(p, false); setG.add(p); gasPeople.push(p); }
  const can = new THREE.Mesh(new THREE.BoxGeometry(0.5, 0.6, 0.25), new THREE.MeshStandardMaterial({ color: 0xc81e1e })); can.position.set(-9.6, 0.3, -30.5); setG.add(can);
}

// ---------------------------------------------------------------- set: hospital (-100,-100)
const setH = new THREE.Group(); setH.position.set(-100, 0, -100); city.add(setH);
const hospital = addBuilding(-102, -104, 30, 20, 24, { facade: hospTex, always: true, intensity: 1.4 });
const smoke = [];
const ambuBlue = [];
{
  const lot = new THREE.Mesh(new THREE.PlaneGeometry(36, 36), new THREE.MeshStandardMaterial({ color: 0x34363a, roughness: 1 })); lot.rotation.x = -Math.PI / 2; lot.position.y = 0.03; setH.add(lot);
  const crossM = new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 0.35, 0.3), toneMapped: false });
  const frame = new THREE.Mesh(new THREE.BoxGeometry(7, 7, 0.5), new THREE.MeshStandardMaterial({ color: 0xeeeeee })); frame.position.set(-2, 28.5, 3); setH.add(frame);
  const c1 = new THREE.Mesh(new THREE.BoxGeometry(5.2, 1.6, 0.2), crossM); c1.position.set(-2, 28.5, 3.3); setH.add(c1);
  const c2 = new THREE.Mesh(new THREE.BoxGeometry(1.6, 5.2, 0.2), crossM); c2.position.set(-2, 28.5, 3.3); setH.add(c2);
  const na = new THREE.Mesh(new THREE.PlaneGeometry(10, 1.6), new THREE.MeshBasicMaterial({ map: textTex('NOTAUFNAHME', 1024, 164, '#b71c1c', '#ffffff', '900 110px Montserrat'), color: new THREE.Color(2.2, 2.2, 2.2), toneMapped: false }));
  na.position.set(-2, 4.2, 6.05); setH.add(na);
  // generator container east side
  const gen = new THREE.Mesh(new THREE.BoxGeometry(2.8, 2.7, 6.5), new THREE.MeshStandardMaterial({ color: 0x2f6b3a, roughness: 0.6, metalness: 0.3 })); gen.position.set(16, 1.35, -8); setH.add(gen);
  const genLbl = new THREE.Mesh(new THREE.PlaneGeometry(4.2, 0.9), new THREE.MeshStandardMaterial({ map: textTex('NOTSTROM', 512, 110, '#f2c200', '#111111', '900 76px Montserrat') })); genLbl.position.set(14.59, 2.0, -8); genLbl.rotation.y = -Math.PI / 2; setH.add(genLbl);
  const pipe = new THREE.Mesh(new THREE.CylinderGeometry(0.18, 0.18, 2, 10), new THREE.MeshStandardMaterial({ color: 0x333333, metalness: 0.8 })); pipe.position.set(16.5, 3.6, -10.5); setH.add(pipe);
  const tank = new THREE.Mesh(new THREE.CylinderGeometry(1.1, 1.1, 4.5, 20), new THREE.MeshStandardMaterial({ color: 0xb5b9bd, metalness: 0.6, roughness: 0.4 })); tank.rotation.x = Math.PI / 2; tank.position.set(16, 1.1, -1.2); setH.add(tank);
  const tankLbl = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 0.6), new THREE.MeshStandardMaterial({ map: textTex('DIESEL', 512, 128, '#111111', '#f2c200', '900 90px Montserrat') })); tankLbl.position.set(14.88, 1.3, -1.2); tankLbl.rotation.y = -Math.PI / 2; setH.add(tankLbl);
  const genLamp = new THREE.Mesh(new THREE.BoxGeometry(0.25, 0.25, 0.1), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.3, 5, 0.6), toneMapped: false })); genLamp.position.set(14.55, 2.6, -6); setH.add(genLamp);
  const spill = new THREE.Mesh(new THREE.PlaneGeometry(16, 16), new THREE.MeshBasicMaterial({ map: poolTex, transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(0.55, 0.62, 0.7) }));
  spill.rotation.x = -Math.PI / 2; spill.position.set(-2, 0.07, 10); setH.add(spill);
  for (let i = 0; i < 26; i++) {
    const s = new THREE.Mesh(new THREE.PlaneGeometry(1, 1), new THREE.MeshBasicMaterial({ map: smokeTex, transparent: true, depthWrite: false, color: 0x8e9196, opacity: 0.5 }));
    s.userData = { ph: i / 26, dx: R(-0.6, 0.6), dz: R(-0.6, 0.6) }; setH.add(s); smoke.push(s);
  }
  const amb = makeCar(0xf3f3f3, { len: 6 }); amb.scale.set(1, 1.35, 1.15); amb.position.set(-6, 0, 11); amb.rotation.y = Math.PI; setH.add(amb); setCarLights(amb, 0.6, 0);
  const stripeM = new THREE.Mesh(new THREE.BoxGeometry(6.02, 0.25, 1.92), new THREE.MeshStandardMaterial({ color: 0xd52b1e })); stripeM.position.set(0, 0.95, 0); amb.add(stripeM);
  for (const x of [-1.2, 1.2]) { const b = new THREE.Mesh(new THREE.BoxGeometry(0.4, 0.2, 0.5), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.2, 0.6, 6), toneMapped: false })); b.position.set(x, 1.38, 0); amb.add(b); ambuBlue.push(b); }
}

// ---------------------------------------------------------------- set: truck (road z=175)
const setK = new THREE.Group(); city.add(setK);
const truck = new THREE.Group(); truck.position.set(-37, 0, 172); setK.add(truck);
const truckHaz = [];
{
  const cabM = new THREE.MeshStandardMaterial({ color: 0xe8e8e8, roughness: 0.4, metalness: 0.3 });
  const cab = new THREE.Mesh(new THREE.BoxGeometry(2.6, 3.2, 2.6), cabM); cab.position.set(0, 2.1, 0); truck.add(cab);
  const wind = new THREE.Mesh(new THREE.PlaneGeometry(2.3, 1.2), new THREE.MeshStandardMaterial({ color: 0x0a0d12, roughness: 0.05, metalness: 0.9 })); wind.position.set(1.31, 2.8, 0); wind.rotation.y = Math.PI / 2; truck.add(wind);
  const trailer = new THREE.Mesh(new THREE.BoxGeometry(13, 3.8, 2.6), new THREE.MeshStandardMaterial({ color: 0x9aa3ab, roughness: 0.6 })); trailer.position.set(-8, 2.6, 0); truck.add(trailer);
  const lbl = new THREE.Mesh(new THREE.PlaneGeometry(9, 1.3), new THREE.MeshStandardMaterial({ map: textTex('LEBENSMITTEL', 1024, 150, '#9aa3ab', '#20262c', '900 100px Montserrat') })); lbl.position.set(-8, 2.8, 1.31); truck.add(lbl);
  const tankF = new THREE.Mesh(new THREE.CylinderGeometry(0.45, 0.45, 1.6, 16), new THREE.MeshStandardMaterial({ color: 0xc0c4c8, metalness: 0.9, roughness: 0.25 })); tankF.rotation.z = Math.PI / 2; tankF.position.set(-1.9, 0.75, 1.15); truck.add(tankF);
  const wg = new THREE.CylinderGeometry(0.5, 0.5, 0.4, 16), wm = new THREE.MeshStandardMaterial({ color: 0x0a0a0a });
  for (const x of [0.2, -5.5, -12, -13.2]) for (const z of [1.2, -1.2]) { const w = new THREE.Mesh(wg, wm); w.rotation.x = Math.PI / 2; w.position.set(x, 0.5, z); truck.add(w); }
  const hl = new THREE.MeshBasicMaterial({ color: new THREE.Color(6, 6, 5), toneMapped: false });
  for (const z of [0.9, -0.9]) { const h = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.3, 0.5), hl); h.position.set(1.31, 1.0, z); truck.add(h); }
  const hz = new THREE.MeshBasicMaterial({ color: new THREE.Color(0, 0, 0), toneMapped: false }); truckHaz.push(hz);
  for (const [x, z] of [[1.32, 1.2], [1.32, -1.2], [-14.51, 1.1], [-14.51, -1.1]]) { const h = new THREE.Mesh(new THREE.BoxGeometry(0.1, 0.25, 0.25), hz); h.position.set(x, 1.0, z); truck.add(h); }
  const beam = new THREE.Mesh(new THREE.PlaneGeometry(18, 8), beamMat); beam.rotation.x = -Math.PI / 2; beam.position.set(10.3, 0.07, 0); truck.add(beam);
  for (const [x, z, yaw] of [[-16, 166, -Math.PI / 4], [-34, 184, 3 * Math.PI / 4], [-16, 184, Math.PI / 4]]) setK.add(makeTrafficLight(x, z, yaw));
  // litter
  for (let i = 0; i < 30; i++) { const p = new THREE.Mesh(new THREE.PlaneGeometry(0.3, 0.4), new THREE.MeshStandardMaterial({ color: 0xbfbfbf, side: THREE.DoubleSide })); p.rotation.set(-Math.PI / 2, 0, R(0, 6)); p.position.set(R(-60, 10), 0.08, R(168, 182)); setK.add(p); }
}

// ---------------------------------------------------------------- set: x-ray tower (-2000,0,0)
const setX = new THREE.Group(); setX.position.set(-2000, 0, 0); scene.add(setX);
const FLOORS = 22, FH = 3.2, TW = 16;
const xFloors = [];
let waterCol, pumpFan, pumpMat, scanPlane;
{
  const cyan = new THREE.Color(0.25, 1.6, 2.2);
  const grid = new THREE.GridHelper(400, 80, 0x1f7e9b, 0x0c3442); setX.add(grid);
  const shell = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(TW, FLOORS * FH, TW)), new THREE.LineBasicMaterial({ color: cyan, toneMapped: false }));
  shell.position.y = FLOORS * FH / 2; setX.add(shell);
  const glassX = new THREE.Mesh(new THREE.BoxGeometry(TW, FLOORS * FH, TW), new THREE.MeshBasicMaterial({ color: 0x0b4a66, transparent: true, opacity: 0.1, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  glassX.position.y = FLOORS * FH / 2; setX.add(glassX);
  // window grid lines on facade
  const wl = [];
  for (let f = 0; f <= FLOORS; f++) { const y = f * FH; wl.push(-TW / 2, y, TW / 2, TW / 2, y, TW / 2, -TW / 2, y, -TW / 2, TW / 2, y, -TW / 2, TW / 2, y, -TW / 2, TW / 2, y, TW / 2, -TW / 2, y, -TW / 2, -TW / 2, y, TW / 2); }
  const wg = new THREE.BufferGeometry(); wg.setAttribute('position', new THREE.Float32BufferAttribute(wl, 3));
  setX.add(new THREE.LineSegments(wg, new THREE.LineBasicMaterial({ color: new THREE.Color(0.1, 0.6, 0.85), toneMapped: false, transparent: true, opacity: 0.6 })));
  const pipeOuter = new THREE.Mesh(new THREE.CylinderGeometry(0.8, 0.8, FLOORS * FH, 20, 1, true), new THREE.MeshBasicMaterial({ color: 0x3fc8ff, transparent: true, opacity: 0.2, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
  pipeOuter.position.y = FLOORS * FH / 2; setX.add(pipeOuter);
  waterCol = new THREE.Mesh(new THREE.CylinderGeometry(0.6, 0.6, 1, 20), new THREE.MeshBasicMaterial({ color: new THREE.Color(0.25, 1.2, 4.5), toneMapped: false }));
  waterCol.geometry.translate(0, 0.5, 0); setX.add(waterCol);
  for (let f = 0; f < FLOORS; f++) {
    const y = f * FH + 1.2;
    const m = new THREE.MeshBasicMaterial({ color: new THREE.Color(0.25, 1.2, 4.5), toneMapped: false });
    for (const side of [1, -1]) {
      const br = new THREE.Mesh(new THREE.CylinderGeometry(0.16, 0.16, 5.5, 8), m); br.rotation.z = Math.PI / 2; br.position.set(side * 3.3, y, 0); setX.add(br);
      const tap = new THREE.Mesh(new THREE.SphereGeometry(0.42, 12, 10), m); tap.position.set(side * 6.2, y, 0); setX.add(tap);
    }
    const slab = new THREE.Mesh(new THREE.PlaneGeometry(TW, TW), new THREE.MeshBasicMaterial({ color: 0x0b6d8f, transparent: true, opacity: 0.05, blending: THREE.AdditiveBlending, depthWrite: false, side: THREE.DoubleSide }));
    slab.rotation.x = -Math.PI / 2; slab.position.y = f * FH; setX.add(slab);
    xFloors.push({ m, y: f * FH });
  }
  pumpMat = new THREE.LineBasicMaterial({ color: cyan, toneMapped: false });
  const pump = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(3, 2, 2.4)), pumpMat); pump.position.set(0, 1, 4.5); setX.add(pump);
  pumpFan = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.CylinderGeometry(0.8, 0.8, 0.1, 6)), pumpMat); pumpFan.rotation.x = Math.PI / 2; pumpFan.position.set(0, 1, 5.75); setX.add(pumpFan);
  scanPlane = new THREE.Mesh(new THREE.PlaneGeometry(26, 26), new THREE.MeshBasicMaterial({ map: poolTex, color: new THREE.Color(0.3, 2, 3), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, toneMapped: false }));
  scanPlane.rotation.x = -Math.PI / 2; setX.add(scanPlane);
  const dustG = new THREE.BufferGeometry(); const dp = [];
  for (let i = 0; i < 500; i++) dp.push(R(-60, 60), R(0, 90), R(-60, 60));
  dustG.setAttribute('position', new THREE.Float32BufferAttribute(dp, 3));
  setX.add(new THREE.Points(dustG, new THREE.PointsMaterial({ color: 0x3fc8ff, size: 2, sizeAttenuation: false, transparent: true, opacity: 0.5 })));
}

// ---------------------------------------------------------------- set: supermarket (2000,0,0)
const setM = new THREE.Group(); setM.position.set(2000, 0, 0); scene.add(setM);
let flickTube, flickLight, exitSign;
{
  const tile = canvasTex(512, 512, (g) => { g.fillStyle = '#b9b6ad'; g.fillRect(0, 0, 512, 512); g.strokeStyle = '#8f8c84'; g.lineWidth = 4; for (let i = 0; i <= 512; i += 128) { g.beginPath(); g.moveTo(i, 0); g.lineTo(i, 512); g.stroke(); g.beginPath(); g.moveTo(0, i); g.lineTo(512, i); g.stroke(); } for (let i = 0; i < 1500; i++) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.08})`; g.fillRect(Math.random() * 512, Math.random() * 512, 3, 3); } });
  tile.wrapS = tile.wrapT = THREE.RepeatWrapping; tile.repeat.set(8, 8);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(36, 36), new THREE.MeshStandardMaterial({ map: tile, roughness: 0.35, metalness: 0.1 })); floor.rotation.x = -Math.PI / 2; setM.add(floor);
  const ceil = new THREE.Mesh(new THREE.PlaneGeometry(36, 36), new THREE.MeshStandardMaterial({ color: 0x55575a })); ceil.rotation.x = Math.PI / 2; ceil.position.y = 4.6; setM.add(ceil);
  const wallM = new THREE.MeshStandardMaterial({ color: 0xc9cbc7, roughness: 0.8 });
  for (const [x, z, ry] of [[0, -16, 0], [0, 16, Math.PI], [-16, 0, Math.PI / 2], [16, 0, -Math.PI / 2]]) { const w = new THREE.Mesh(new THREE.PlaneGeometry(36, 4.6), wallM); w.position.set(x, 2.3, z); w.rotation.y = ry; setM.add(w); }
  const shelfM = new THREE.MeshStandardMaterial({ color: 0xdedfe0, roughness: 0.5, metalness: 0.2 });
  const tagM = new THREE.MeshStandardMaterial({ color: 0xf2d33c, roughness: 0.5 });
  const prodCols = [0xd32f2f, 0x1976d2, 0xfbc02d, 0x388e3c, 0xf57c00, 0x7b1fa2, 0xeeeeee, 0x5d4037];
  for (const sx of [-7.5, -2.5, 2.5, 7.5]) {
    const back = new THREE.Mesh(new THREE.BoxGeometry(0.15, 2.4, 22), shelfM); back.position.set(sx, 1.2, -1); setM.add(back);
    for (const y of [0.15, 0.75, 1.35, 1.95, 2.45]) {
      const b = new THREE.Mesh(new THREE.BoxGeometry(1.1, 0.06, 22), shelfM); b.position.set(sx, y, -1); setM.add(b);
      for (const side of [-1, 1]) {
        const tg = new THREE.Mesh(new THREE.BoxGeometry(0.02, 0.06, 22), tagM); tg.position.set(sx + side * 0.56, y - 0.02, -1); setM.add(tg);
        for (let z = -11.5; z < 9.5; z += 0.45) if (rnd() < 0.06 && y < 2.4) {
          const p = new THREE.Mesh(new THREE.BoxGeometry(0.3, R(0.2, 0.45), 0.3), new THREE.MeshStandardMaterial({ color: prodCols[Math.floor(R(0, 8))], roughness: 0.6 }));
          p.position.set(sx + side * 0.3, y + 0.03 + p.geometry.parameters.height / 2, z); p.rotation.y = R(-0.3, 0.3); setM.add(p);
        }
      }
    }
  }
  for (let i = 0; i < 14; i++) { const p = new THREE.Mesh(new THREE.BoxGeometry(0.3, 0.25, 0.3), new THREE.MeshStandardMaterial({ color: prodCols[i % 8] })); p.position.set(R(-1.4, 1.4), 0.13, R(-10, 8)); p.rotation.set(R(0, 1.5), R(0, 6), 0); setM.add(p); }
  // fridge wall
  const fr = new THREE.Mesh(new THREE.BoxGeometry(30, 3, 1.2), new THREE.MeshStandardMaterial({ color: 0x2b2e33, roughness: 0.5 })); fr.position.set(0, 1.5, -15.3); setM.add(fr);
  for (let x = -14; x <= 14; x += 2) {
    const d = new THREE.Mesh(new THREE.PlaneGeometry(1.85, 2.6), new THREE.MeshStandardMaterial({ color: 0x0c1418, roughness: 0.05, metalness: 0.9, transparent: true, opacity: 0.85 })); d.position.set(x, 1.6, -14.65); setM.add(d);
    const h = new THREE.Mesh(new THREE.BoxGeometry(0.06, 0.8, 0.06), new THREE.MeshStandardMaterial({ color: 0xaaaaaa, metalness: 0.9 })); h.position.set(x + 0.8, 1.6, -14.6); setM.add(h);
    const fl = new THREE.Mesh(new THREE.BoxGeometry(1.95, 0.05, 0.05), new THREE.MeshStandardMaterial({ color: 0x777777 })); fl.position.set(x, 2.92, -14.6); setM.add(fl);
  }
  // ceiling tubes (off) + one flickering
  const tubeOff = new THREE.MeshStandardMaterial({ color: 0x8a8d90, roughness: 0.4 });
  for (let z = -12; z <= 12; z += 4) for (const x of [-5, 0, 5]) { const t = new THREE.Mesh(new THREE.BoxGeometry(0.35, 0.08, 2.8), tubeOff); t.position.set(x, 4.5, z); setM.add(t); }
  flickTube = new THREE.Mesh(new THREE.BoxGeometry(0.36, 0.09, 2.8), new THREE.MeshBasicMaterial({ color: new THREE.Color(0, 0, 0), toneMapped: false })); flickTube.position.set(0, 4.48, -8); setM.add(flickTube);
  flickLight = new THREE.PointLight(0xdfe8ff, 0, 30, 1.6); flickLight.position.set(0, 4.2, -8); setM.add(flickLight);
  exitSign = new THREE.Mesh(new THREE.PlaneGeometry(2.2, 0.6), new THREE.MeshBasicMaterial({ map: textTex('NOTAUSGANG', 512, 140, '#0f8a3a', '#ffffff', '900 72px Montserrat'), color: new THREE.Color(2.5, 2.5, 2.5), toneMapped: false }));
  exitSign.position.set(9, 3.7, -14.62); setM.add(exitSign);
  const exitL = new THREE.PointLight(0x22ff77, 6, 14, 1.8); exitL.position.set(9, 3.4, -13.5); setM.add(exitL);
  // shopping cart
  const cart = new THREE.LineSegments(new THREE.EdgesGeometry(new THREE.BoxGeometry(1.4, 0.8, 0.8)), new THREE.LineBasicMaterial({ color: 0xbfc4c8 }));
  cart.position.set(0.6, 0.55, -3); cart.rotation.set(0, 0.6, 1.35); setM.add(cart);
}

// ---------------------------------------------------------------- set: door hallway (2000,0,300)
const setD = new THREE.Group(); setD.position.set(2000, 0, 300); scene.add(setD);
let doorPanel, crackMat, feet = [];
{
  const wood = canvasTex(512, 512, (g) => { g.fillStyle = '#6b4a2f'; g.fillRect(0, 0, 512, 512); for (let i = 0; i < 8; i++) { g.fillStyle = i % 2 ? '#5d3f27' : '#6f4d31'; g.fillRect(i * 64, 0, 62, 512); } for (let i = 0; i < 400; i++) { g.fillStyle = `rgba(0,0,0,${Math.random() * 0.12})`; g.fillRect(Math.random() * 512, Math.random() * 512, 2, 40); } });
  wood.wrapS = wood.wrapT = THREE.RepeatWrapping; wood.repeat.set(2, 6);
  const floor = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 14), new THREE.MeshStandardMaterial({ map: wood, roughness: 0.55 })); floor.rotation.x = -Math.PI / 2; floor.position.set(0, 0, -3); setD.add(floor);
  const wallM = new THREE.MeshStandardMaterial({ color: 0xbdb5a6, roughness: 0.9 });
  for (const s of [-1, 1]) { const w = new THREE.Mesh(new THREE.PlaneGeometry(14, 2.8), wallM); w.position.set(s * 1.3, 1.4, -3); w.rotation.y = -s * Math.PI / 2; setD.add(w); }
  const ceil = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 14), wallM); ceil.rotation.x = Math.PI / 2; ceil.position.set(0, 2.8, -3); setD.add(ceil);
  const endW = new THREE.Mesh(new THREE.PlaneGeometry(2.6, 2.8), wallM); endW.position.set(0, 1.4, -10.0); setD.add(endW);
  const frameM = new THREE.MeshStandardMaterial({ color: 0xe8e4dc, roughness: 0.6 });
  for (const [x, y, w, h] of [[-0.56, 1.06, 0.1, 2.12], [0.56, 1.06, 0.1, 2.12], [0, 2.16, 1.22, 0.1]]) { const f = new THREE.Mesh(new THREE.BoxGeometry(w, h, 0.12), frameM); f.position.set(x, y, -9.95); setD.add(f); }
  doorPanel = new THREE.Group(); doorPanel.position.set(0, 0, -9.97); setD.add(doorPanel);
  const dm = new THREE.MeshStandardMaterial({ color: 0x4a2f1c, roughness: 0.55 });
  const dp = new THREE.Mesh(new THREE.BoxGeometry(1.0, 2.08, 0.05), dm); dp.position.y = 1.07; doorPanel.add(dp);
  for (const [y, h] of [[1.55, 0.75], [0.6, 0.85]]) { const ins = new THREE.Mesh(new THREE.BoxGeometry(0.72, h, 0.02), new THREE.MeshStandardMaterial({ color: 0x3e2717, roughness: 0.6 })); ins.position.set(0, y, 0.035); doorPanel.add(ins); }
  const handle = new THREE.Mesh(new THREE.BoxGeometry(0.16, 0.035, 0.06), new THREE.MeshStandardMaterial({ color: 0xc9c9c9, metalness: 0.95, roughness: 0.2 })); handle.position.set(0.36, 1.02, 0.07); doorPanel.add(handle);
  const peep = new THREE.Mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.03, 12), handle.material); peep.rotation.x = Math.PI / 2; peep.position.set(0, 1.55, 0.04); doorPanel.add(peep);
  const num = new THREE.Mesh(new THREE.PlaneGeometry(0.16, 0.1), new THREE.MeshStandardMaterial({ map: textTex('72', 128, 80, '#4a2f1c', '#d4af37', '900 60px Montserrat'), metalness: 0.6, roughness: 0.3 })); num.position.set(0, 1.85, 0.03); doorPanel.add(num);
  const mat = new THREE.Mesh(new THREE.PlaneGeometry(0.9, 0.55), new THREE.MeshStandardMaterial({ color: 0x2a2420, roughness: 1 })); mat.rotation.x = -Math.PI / 2; mat.position.set(0, 0.005, -9.5); setD.add(mat);
  crackMat = new THREE.MeshBasicMaterial({ map: canvasTex(256, 128, (g, w, h) => { const gr = g.createLinearGradient(0, 0, 0, h); gr.addColorStop(0, 'rgba(255,220,160,1)'); gr.addColorStop(1, 'rgba(255,200,120,0)'); g.fillStyle = gr; g.fillRect(0, 0, w, h); }), transparent: true, blending: THREE.AdditiveBlending, depthWrite: false, color: new THREE.Color(0, 0, 0), toneMapped: false });
  const crack = new THREE.Mesh(new THREE.PlaneGeometry(1.0, 0.7), crackMat); crack.rotation.x = -Math.PI / 2; crack.position.set(0, 0.008, -9.62); setD.add(crack);
  const gap = new THREE.Mesh(new THREE.BoxGeometry(1.0, 0.012, 0.02), crackMat); gap.position.set(0, 0.012, -9.96); setD.add(gap);
  for (const x of [-0.17, 0.15]) { const f = new THREE.Mesh(new THREE.PlaneGeometry(0.14, 0.75), new THREE.MeshBasicMaterial({ color: 0x000000, transparent: true, opacity: 0.85, depthWrite: false })); f.rotation.x = -Math.PI / 2; f.position.set(x, 0.01, -9.62); setD.add(f); feet.push(f); }
  const pic = new THREE.Mesh(new THREE.BoxGeometry(0.04, 0.5, 0.7), new THREE.MeshStandardMaterial({ color: 0x222222 })); pic.position.set(-1.27, 1.6, -5); setD.add(pic);
}
const flash = new THREE.SpotLight(0xf3f6ff, 0, 40, 0.55, 0.65, 1.4); camera.add(flash); flash.position.set(0.25, -0.2, 0); flash.target.position.set(0, -0.3, -5); camera.add(flash.target);
const hallAmb = new THREE.PointLight(0x5566aa, 0, 10, 2); setD.add(hallAmb); hallAmb.position.set(0, 2.5, -2);

// ---------------------------------------------------------------- camera paths
const K = (t, p, l, f = 60) => ({ t, p, l, f });
const CAMS = {
  minute: [K(0, [40.5, 2.0, 43], [33, 5.3, 34.5], 58), K(0.65, [39, 2.3, 41], [33.3, 5.5, 34.6], 52), K(1.25, [38, 3.2, 41], [14, 25, 20], 56), K(2.6, [36, 4.5, 39.5], [10, 29.5, 18.5], 46),
    K(2.9, [42, 2.0, 31], [32, 1.4, 12], 58), K(4.3, [44, 2.8, 27], [32, 1.3, 7], 58), K(6.4, [50, 10, 33], [29, 0.5, 5], 60)],
  tower: [K(0, [112, 1.8, -35], [100, 30, -50], 72), K(2.1, [88, 10, -32], [100, 42, -50], 62), K(2.8, [89, 40, -40], [100, 47, -50], 52),
    K(3.75, [72, 58, -14], [100, 26, -50], 60), K(5.85, [42, 82, 30], [100, 8, -50], 62), K(8.5, [18, 104, 82], [100, 0, -40], 64)],
  gas: [K(0, [-58, 72, 2], [-100, 0, 45], 60), K(0.65, [-72, 42, 12], [-100, 2, 45], 58), K(2.55, [-87, 4.5, 33], [-100, 2.2, 45], 60), K(3.25, [-91, 3.2, 39], [-101, 2, 47], 56),
    K(4.05, [-88.5, 2.8, 48.5], [-93, 2.3, 57], 52), K(5.45, [-90.2, 2.3, 51.5], [-93, 2.1, 57], 46), K(6.25, [-95, 16, 40], [-112, 0, 24], 60), K(9, [-62, 58, 4], [-132, 0, 24], 62)],
  water: [K(0, [-1956, 8, 44], [-2000, 22, 0], 58), K(1.45, [-1966, 52, 42], [-2000, 58, 0], 56), K(3.0, [-1956, 34, 34], [-2000, 36, 0], 58), K(3.95, [-1976, 10, 30], [-2000, 8, 0], 58), K(7.0, [-2042, 22, 44], [-2000, 22, 0], 60)],
  hosp: [K(0, [-75, 115, -250], [-100, 6, -100], 46), K(0.65, [-75, 95, -215], [-100, 8, -100], 48), K(1.5, [-75, 48, -165], [-92, 5, -104], 52), K(2.35, [-75, 12, -124], [-84, 2.5, -107], 56), K(3.1, [-76, 6, -118], [-84, 2.2, -108], 54), K(4.1, [-77, 4.5, -114], [-85, 2.4, -107], 52)],
  truck: [K(0, [-9, 1.5, 167], [-37, 2.6, 174], 54), K(0.85, [-7, 4.0, 160], [-16.5, 5.4, 166.5], 50), K(1.55, [-24, 2.0, 184], [-44, 2.5, 174], 58), K(2.7, [-31, 1.7, 177.6], [-39, 1.1, 173.6], 52), K(3.9, [-31.5, 1.5, 176.6], [-39, 0.9, 173.4], 46)],
  market: [K(0, [2000, 1.7, 14], [2000, 1.5, -10], 62), K(0.65, [2000, 1.7, 9], [2000, 1.3, -10], 60), K(1.65, [2000, 1.7, 2], [1993, 1.5, -14], 58), K(2.6, [1999.5, 1.7, -2], [1992, 1.4, -15], 56)],
  door: [K(0, [2000, 1.65, 297.5], [2000, 1.45, 290], 56), K(2.0, [2000, 1.62, 295.2], [2000, 1.35, 290], 54), K(4.9, [2000, 1.6, 293.6], [2000, 1.25, 290], 50)],
};
function catmull(p0, p1, p2, p3, u) { const u2 = u * u, u3 = u2 * u; return 0.5 * ((2 * p1) + (-p0 + p2) * u + (2 * p0 - 5 * p1 + 4 * p2 - p3) * u2 + (-p0 + 3 * p1 - 3 * p2 + p3) * u3); }
function keyCam(keys, lt) {
  const n = keys.length;
  if (lt <= keys[0].t) return keys[0];
  if (lt >= keys[n - 1].t) return keys[n - 1];
  let i = 0; while (i < n - 2 && lt >= keys[i + 1].t) i++;
  const u = (lt - keys[i].t) / (keys[i + 1].t - keys[i].t);
  const k0 = keys[Math.max(0, i - 1)], k1 = keys[i], k2 = keys[i + 1], k3 = keys[Math.min(n - 1, i + 2)];
  const c = (a) => [0, 1, 2].map((j) => catmull(k0[a][j], k1[a][j], k2[a][j], k3[a][j], u));
  return { p: c('p'), l: c('l'), f: catmull(k0.f, k1.f, k2.f, k3.f, u) };
}
function hookCam(lt) {
  return { p: [-120 + 12 * lt, 140 - 7 * lt, 220 - 16 * lt], l: [6 + 2.5 * lt, 4, -4 - 3 * lt], f: 62 - lt * 1.2 };
}
function outroCam(lt) {
  const a = 0.55 + lt * 0.035;
  return { p: [Math.sin(a) * 270, 165 + lt * 4, Math.cos(a) * 270], l: [0, 0, 0], f: 58 };
}

// ---------------------------------------------------------------- per-frame state
function segAt(t) { for (let i = SEGMENTS.length - 1; i >= 0; i--) if (t >= SEGMENTS[i].start) return SEGMENTS[i]; return SEGMENTS[0]; }
function fxAmount(t, type) {
  let s = 0;
  for (const f of FX) if (f.type === type && t >= f.t && t < f.t + f.d) { const p = (t - f.t) / f.d; s += f.a * Math.pow(1 - p, 2); }
  return s;
}
function whipAmount(t) {
  let off = 0, blur = 0;
  for (const f of FX) if (f.type === 'whip') {
    if (t >= f.t - 0.15 && t < f.t) { const p = (t - (f.t - 0.15)) / 0.15; off += -easeIn(p) * 0.55; blur += easeIn(p) * 0.09; }
    if (t >= f.t && t < f.t + 0.22) { const p = (t - f.t) / 0.22; off += (1 - easeOut(p)) * 0.55; blur += (1 - easeOut(p)) * 0.09; }
  }
  return { off, blur };
}
function flashAt(t) {
  let a = 0, c = [1, 1, 1];
  for (const f of FX) if (f.type === 'flash' && t >= f.t && t < f.t + f.d) { const p = (t - f.t) / f.d; const v = f.a * (1 - p); if (v > a) { a = v; c = f.c; } }
  return { a, c };
}

function update(t) {
  const seg = segAt(t); const lt = t - seg.start;
  const isLoop = seg.id === 'loop';
  const tau = isLoop ? t - 60 : t;
  const cityVis = !['water', 'market', 'door'].includes(seg.id);
  city.visible = cityVis; setX.visible = seg.id === 'water'; setM.visible = seg.id === 'market'; setD.visible = seg.id === 'door';

  // presets
  let preset = 'nightDark';
  if (seg.id === 'hook' || isLoop) preset = 'nightLit';
  else if (seg.id === 'gas') preset = 'morning';
  else if (seg.id === 'water') preset = 'xray';
  else if (seg.id === 'market' || seg.id === 'door') preset = 'indoor';
  applyPreset(PRESETS[preset]);
  if (seg.id === 'hook') skyMat.uniforms.glowAmt.value = 0.55 * (1 - smooth((t - 0.95) / 1.2));
  if (seg.id === 'outro' && t > 58.35) skyMat.uniforms.glowAmt.value = 0.55 * hash(Math.floor(t * 20)) * smooth((t - 58.35) / 0.5);

  // building windows
  const night = preset === 'nightLit' || preset === 'nightDark';
  for (const b of buildings) {
    let I = 0, map = b.base;
    if (b.always) I = b.intensity * (seg.id === 'gas' ? 0.15 : 1);
    else if (isLoop) I = b.intensity;
    else if (seg.id === 'hook') {
      if (t < b.off - 0.18) I = 1;
      else if (t < b.off) I = hash(b.seed + Math.floor(t * 30)) > 0.45 ? 1 : 0.05;
      else I = 0;
    } else if (seg.id === 'outro' && t > 58.35) {
      I = hash(b.seed * 3 + Math.floor(t * 24)) < smooth((t - 58.35) / 0.5) ? 1 : 0;
    } else if (night && b.candle && t > 11) { map = candleTex; I = 0.75 + 0.25 * noise1(t * 6 + b.seed); }
    if (b.mat.emissiveMap !== map) b.mat.emissiveMap = map;
    b.mat.emissiveIntensity = I;
  }
  // street lamps
  const lampOn = (l) => isLoop || (seg.id === 'hook' && t < l.off) || (seg.id === 'outro' && t > 58.35 && hash(l.x * 0.13 + l.z + Math.floor(t * 24)) < smooth((t - 58.35) / 0.5));
  const cOn = new THREE.Color(1, 1, 1), cOff = new THREE.Color(0.02, 0.02, 0.02), cFl = new THREE.Color(0.4, 0.4, 0.4);
  lampPos.forEach((l, i) => {
    let c = lampOn(l) ? cOn : cOff;
    if (seg.id === 'hook' && t >= l.off - 0.15 && t < l.off) c = hash(i + Math.floor(t * 30)) > 0.5 ? cOn : cFl;
    headMesh.setColorAt(i, c); lpoolMesh.setColorAt(i, c.r > 0.5 ? cOn : new THREE.Color(0, 0, 0));
  });
  headMesh.instanceColor.needsUpdate = true; lpoolMesh.instanceColor.needsUpdate = true;
  groundMat.color.setScalar(preset === 'morning' ? 1.0 : 0.8);

  // moving cars
  const frac = { hook: 1, minute: 0.9, tower: 0.55, gas: 0.35, hosp: 0.12, truck: 0.12, outro: 0.06, loop: 1 }[seg.id] ?? 0.3;
  updateMovers(tau, frac, preset !== 'morning');

  // intersection A
  for (const tl of tlights) {
    const st = Math.floor(((tau + 100) % 8) / 4);
    tl.userData.lamps.forEach((L, k) => {
      let on = 0;
      if (t < 0.95 || isLoop) on = (k === 0 && st === 0) || (k === 2 && st === 1) ? 1 : 0;
      if (seg.id === 'minute' && t > 5.28 && t < 5.5 && k === 0) on = hash(Math.floor(t * 40)) > 0.4 ? 0.8 : 0;
      L.m.color.copy(L.c).multiplyScalar(on > 0 ? 4 * on : 0.04);
    });
  }
  carsA.forEach((c, i) => setCarLights(c, 1, seg.id === 'minute' && Math.floor((t * 1.6 + i * 0.3)) % 2 === 0 ? 1 : 0));
  let cy = 30;
  if (seg.id === 'minute' && t >= 6.45) { const p = t - 6.45; cy = 30 - 0.55 * (1 - Math.exp(-p * 9)) + 0.12 * Math.sin(p * 30) * Math.exp(-p * 6); }
  cabin.position.y = cy; cabinLight.position.set(9, cy + 1.42, 18.4);
  cabinPeople.forEach(({ p, dx }) => { p.position.set(9 + dx, cy - 1.5, 18.4); setFlash(p, t > 6.9); p.scale.setScalar(0.9); });
  let emerg = 0;
  if (t >= 6.45) emerg = t < 6.85 ? (hash(Math.floor(t * 30)) > 0.5 ? 1 : 0) : 0.85 + 0.15 * Math.sin(t * 9);
  cabinLight.material.color.setRGB(5 * emerg, 0.4 * emerg, 0.3 * emerg); cabinMat.emissiveIntensity = emerg * 0.12;
  peopleA.forEach((p) => setFlash(p, (seg.id === 'minute' && t >= p.userData.on) || ['tower', 'outro'].includes(seg.id)));

  // tower
  const blink = (tau % 1.4) < 0.5 ? 1 : 0;
  let redOn = t < 13.8 ? blink : 0;
  if (t >= 13.8 && t < 14.1) redOn = hash(Math.floor(t * 30)) > 0.5 ? 1 : 0;
  towerRed.material.color.setRGB(7 * redOn, 0.2 * redOn, 0.1 * redOn);
  let led = t < 13.1 ? [0.2, 5, 0.4] : t < 13.8 ? ((t * 4) % 1 < 0.5 ? [6, 1.5, 0] : [0, 0, 0]) : [0, 0, 0];
  cabLed.material.color.setRGB(...led);

  // hospital
  smoke.forEach((s) => {
    const { ph, dx, dz } = s.userData; const p = (tau * 0.35 + ph) % 1;
    s.position.set(16.5 + dx * p * 3 + p * 2, 4.6 + p * 14, -10.5 + dz * p * 3);
    s.scale.setScalar(1 + p * 6); s.material.opacity = 0.42 * (1 - p) * smooth(p * 6); s.quaternion.copy(camera.quaternion);
  });
  const bl = Math.floor(tau * 5) % 2;
  ambuBlue.forEach((b, i) => b.material.color.setRGB(0.2 * ((bl + i) % 2) * 3, 0.6 * ((bl + i) % 2) * 3, 6 * ((bl + i) % 2)));
  truckHaz.forEach((m) => m.color.setRGB(...(Math.floor(tau * 1.6) % 2 ? [6, 2.6, 0.2] : [0, 0, 0])));

  // x-ray tower
  if (seg.id === 'water') {
    let level = FLOORS * FH;
    if (t > 29.7) level = lerp(FLOORS * FH, 3.6 * FH, smooth((t - 29.7) / 1.8)) + 0.3 * Math.sin(t * 7) * smooth((t - 31.3) / 0.3) * Math.exp(-(t - 31.3));
    waterCol.scale.y = Math.max(0.01, level);
    xFloors.forEach((f) => { const wet = f.y + 1.2 < level; f.m.color.setRGB(...(wet ? [0.25, 1.2, 4.5] : [4.5, 0.25, 0.2])); });
    const stopped = t > 29.95;
    pumpFan.rotation.y = stopped ? 1.2 + 0.3 * (1 - Math.exp(-(t - 29.95) * 3)) : t * 14;
    pumpMat.color.setRGB(...(stopped ? [4.5, 0.3, 0.2] : [0.25, 1.6, 2.2]));
    const sp = (t - 28.6) / 1.1; scanPlane.visible = sp > 0 && sp < 1; scanPlane.position.y = sp * FLOORS * FH;
  }

  // market
  if (seg.id === 'market') {
    const fl = hash(Math.floor(t * 18)) > 0.35 ? (0.6 + 0.4 * hash(Math.floor(t * 40) + 3)) : 0.05;
    flickTube.material.color.setScalar(4 * fl); flickLight.intensity = 26 * fl;
  }
  // door
  let crack = 0;
  if (seg.id === 'door') {
    crack = t < 49.35 ? 0.9 + 0.1 * noise1(t * 10) : Math.max(0, 1 - (t - 49.35) * 6) * 0.9;
    feet[0].position.x = -0.17 + 0.03 * noise1(t * 1.3); feet[1].position.x = 0.15 + 0.03 * noise1(t * 1.3 + 9);
    feet.forEach((f) => f.visible = t < 49.4);
    let kn = 0; for (const k of [46.4, 46.72, 47.04]) if (t >= k && t < k + 0.12) kn = (1 - (t - k) / 0.12);
    doorPanel.position.z = -9.97 + kn * 0.012 * Math.sin(t * 300);
    hallAmb.intensity = 0.4;
  }
  crackMat.color.setRGB(2.4 * crack, 1.9 * crack, 1.3 * crack);
  flash.intensity = (seg.id === 'market') ? 28 : (seg.id === 'door' ? 13 : 0);
  flash.angle = seg.id === 'door' ? 0.6 : 0.5;

  // ---- camera
  let cam;
  if (seg.id === 'hook') cam = hookCam(lt);
  else if (isLoop) cam = hookCam(t - 60);
  else if (seg.id === 'outro') cam = outroCam(lt);
  else cam = keyCam(CAMS[seg.id], lt);
  camera.position.set(...cam.p); camera.fov = cam.f; camera.updateProjectionMatrix();
  camera.lookAt(...cam.l);
  // handheld + shake
  const hand = ['minute', 'truck', 'market', 'door', 'gas'].includes(seg.id) ? 1 : 0.35;
  const sh = fxAmount(t, 'shake');
  const amp = 0.004 * hand + 0.035 * sh;
  camera.rotateX(noise1(t * 1.7 + 3) * amp + noise1(t * 31) * 0.02 * sh);
  camera.rotateY(noise1(t * 1.3 + 7) * amp + noise1(t * 29 + 4) * 0.02 * sh);
  camera.rotateZ(noise1(t * 0.9 + 11) * amp * 0.6 + noise1(t * 27 + 2) * 0.015 * sh);
  const w = whipAmount(t); camera.rotateY(w.off);

  // ---- post fx
  const u = fxPass.uniforms;
  u.uTime.value = t; u.uBlur.value = w.blur;
  const g = fxAmount(t, 'glitch'); u.uGlitch.value = g; u.uRGB.value = 0.0006 + g * 0.012 + w.blur * 0.05;
  u.uPunch.value = fxAmount(t, 'punch');
  let bright = 1, sat = 1, vig = 1.05;
  if (seg.id === 'outro') { bright = lerp(1, 0.55, smooth((t - 51) / 1.5)); sat = 0.55; if (t > 58.35) { bright = 1; sat = 1; } }
  if (seg.id === 'door') { vig = 1.35; bright = 1.0; }
  if (seg.id === 'gas') sat = 0.78;
  if (['minute', 'truck', 'hosp'].includes(seg.id)) bright = 1.4;
  if (seg.id === 'tower') bright = 1.2;
  if (seg.id === 'door' && t > 49.4) bright = lerp(1.0, 0.35, smooth((t - 49.4) / 1.4));
  u.uBright.value = bright; u.uSat.value = sat; u.uVig.value = vig;
  u.uTint.value.set(...(seg.id === 'gas' ? [0.95, 1.0, 1.05] : seg.id === 'door' ? [1.05, 0.97, 0.9] : [1, 1, 1]));
  bloom.strength = seg.id === 'water' ? 1.2 : seg.id === 'gas' ? 0.35 : (seg.id === 'door' || seg.id === 'market') ? 0.5 : 0.95;
  bloom.threshold = seg.id === 'gas' ? 0.95 : 0.78;
}

// ---------------------------------------------------------------- overlay (2D)
const YEL = '#ffd400', RED = '#ff3b30';
function rr(g, x, y, w, h, r) { g.beginPath(); g.moveTo(x + r, y); g.arcTo(x + w, y, x + w, y + h, r); g.arcTo(x + w, y + h, x, y + h, r); g.arcTo(x, y + h, x, y, r); g.arcTo(x, y, x + w, y, r); g.closePath(); }
function popScale(lt) {
  if (lt < 0) return 0;
  if (lt < 0.07) return lerp(0.5, 1.13, lt / 0.07);
  if (lt < 0.15) return lerp(1.13, 0.97, (lt - 0.07) / 0.08);
  if (lt < 0.22) return lerp(0.97, 1, (lt - 0.15) / 0.07);
  return 1;
}
function strokeText(g, text, x, y, fill, lw) {
  g.lineJoin = 'round'; g.miterLimit = 2;
  g.strokeStyle = 'rgba(0,0,0,0.55)'; g.lineWidth = lw + 10; g.strokeText(text, x + 4, y + 9);
  g.strokeStyle = '#000'; g.lineWidth = lw; g.strokeText(text, x, y);
  g.fillStyle = fill; g.fillText(text, x, y);
}
function drawHeader(g, t) {
  const seg = segAt(t);
  g.save();
  g.textAlign = 'center'; g.textBaseline = 'alphabetic';
  g.font = '400 112px Anton'; g.letterSpacing = '2px';
  strokeText(g, '72 STUNDEN', 540, 300, '#ffffff', 18);
  g.font = '400 92px Anton';
  const tw = g.measureText('OHNE STROM').width;
  g.save(); g.translate(540, 362); g.rotate(-0.025);
  g.fillStyle = 'rgba(0,0,0,0.5)'; rr(g, -tw / 2 - 30 + 6, -52 + 8, tw + 60, 112, 18); g.fill();
  g.fillStyle = '#e8141b'; rr(g, -tw / 2 - 30, -52, tw + 60, 112, 18); g.fill();
  g.fillStyle = '#fff'; g.fillText('OHNE STROM', 0, 42);
  g.restore();
  g.restore();
}
function fmt(sec) { sec = Math.max(0, Math.floor(sec)); const h = Math.floor(sec / 3600), m = Math.floor(sec / 60) % 60, s = sec % 60; return [h, m, s].map((v) => String(v).padStart(2, '0')).join(':'); }
function timerSeconds(t) {
  const seg = segAt(t);
  let first = seg; if (seg.cont) { const i = SEGMENTS.indexOf(seg); for (let k = i; k >= 0; k--) { if (!SEGMENTS[k].cont) { first = SEGMENTS[k]; break; } } }
  const base = first.hour * 3600 + (first.minute || 0) * 60;
  const lt = t - first.start;
  if (first.id === 'hook') return t - 0.95;
  const i = SEGMENTS.indexOf(first); const prev = SEGMENTS[i - 1];
  const prevVal = prev ? prev.hour * 3600 + (prev.minute || 0) * 60 + (prev.end - prev.start) : 0;
  if (lt < 0.5) return lerp(prevVal, base, easeOut(lt / 0.5));
  return base + (lt - 0.5) * 7;
}
function drawTimer(g, t) {
  const seg = segAt(t);
  if (t < 0.95 || seg.id === 'loop') return;
  let first = seg; if (seg.cont) { const i = SEGMENTS.indexOf(seg); for (let k = i; k >= 0; k--) if (!SEGMENTS[k].cont) { first = SEGMENTS[k]; break; } }
  const lt = t - first.start;
  const rolling = first.id !== 'hook' && lt < 0.55;
  let sc = popScale(t - 0.95);
  if (rolling) sc = 1 + 0.28 * Math.sin(Math.PI * clamp(lt / 0.55));
  const red = seg.id === 'outro' || seg.id === 'door';
  g.save(); g.translate(540, 548); g.scale(sc, sc);
  g.fillStyle = 'rgba(0,0,0,0.72)'; rr(g, -230, -46, 460, 92, 46); g.fill();
  g.lineWidth = 4; g.strokeStyle = rolling || (red && Math.floor(t * 2) % 2) ? '#ff3b30' : 'rgba(255,255,255,0.25)'; rr(g, -230, -46, 460, 92, 46); g.stroke();
  const dotOn = Math.floor(t * 2) % 2 === 0;
  g.fillStyle = dotOn ? '#ff3b30' : '#5a1512'; g.beginPath(); g.arc(-185, 0, 13, 0, Math.PI * 2); g.fill();
  const txt = fmt(timerSeconds(t));
  g.font = '800 58px Montserrat'; g.textBaseline = 'middle'; g.textAlign = 'center';
  const cw = 36; const x0 = -150 + 22;
  for (let i = 0; i < txt.length; i++) {
    const ch = txt[i]; const x = x0 + i * cw + (ch === ':' ? 0 : 0);
    g.fillStyle = rolling ? (i < 2 ? YEL : '#fff') : '#fff';
    if (rolling && ch !== ':') { g.globalAlpha = 0.35; g.fillText(ch, x + cw / 2, -14); g.fillText(ch, x + cw / 2, 14); g.globalAlpha = 1; }
    g.fillText(ch, x + cw / 2, 3);
  }
  g.font = '800 22px Montserrat'; g.fillStyle = 'rgba(255,255,255,0.75)'; g.textAlign = 'center';
  g.restore();
  g.save(); g.font = '800 26px Montserrat'; g.textAlign = 'center'; g.letterSpacing = '4px';
  g.fillStyle = 'rgba(255,255,255,0.85)'; g.shadowColor = '#000'; g.shadowBlur = 8;
  g.fillText('STROM WEG SEIT', 540, 474); g.restore();
}
function drawCaption(g, t) {
  if (t >= CAPTION_END) return;
  let idx = -1; for (let i = 0; i < CAPTIONS.length; i++) if (t >= CAPTIONS[i][0]) idx = i;
  if (idx < 0) return;
  const [st, text, o] = CAPTIONS[idx];
  const lt = t - st;
  const sc = popScale(lt + (st === 0 ? 0.3 : 0));
  let fs = o.hour ? 138 : 98;
  g.save();
  g.textAlign = 'left'; g.textBaseline = 'alphabetic'; g.letterSpacing = '1px';
  const words = text.split(' ');
  const setF = () => g.font = `900 ${fs}px Montserrat`;
  setF();
  const space = fs * 0.28;
  // wrap
  let lines;
  for (let tries = 0; tries < 6; tries++) {
    lines = [[]]; let lw = 0;
    for (const wd of words) {
      const ww = g.measureText(wd).width;
      if (lines[lines.length - 1].length && lw + space + ww > 940) { lines.push([]); lw = 0; }
      lines[lines.length - 1].push(wd); lw += (lw ? space : 0) + ww;
    }
    const maxW = Math.max(...lines.map((l) => l.reduce((a, w2, i) => a + g.measureText(w2).width + (i ? space : 0), 0)));
    if (maxW <= 960) break; fs *= 0.9; setF();
  }
  const lh = fs * 1.08;
  const cy = 1210 - (lines.length - 1) * lh / 2;
  g.translate(540, cy); g.scale(sc, sc); g.rotate(o.hour ? -0.03 : 0);
  lines.forEach((line, li) => {
    const widths = line.map((w2) => g.measureText(w2).width);
    const total = widths.reduce((a, b) => a + b, 0) + space * (line.length - 1);
    let x = -total / 2; const y = li * lh + fs * 0.36;
    line.forEach((wd, wi) => {
      let col = '#ffffff';
      if (o.hl && o.hl.includes(wd)) col = YEL;
      if (o.red && o.red.includes(wd)) col = RED;
      if (o.hour && wi === 1) col = YEL;
      strokeText(g, wd, x, y, col, fs * 0.17);
      x += widths[wi] + space;
    });
  });
  g.restore();
}
function drawX(g, p) {
  g.save(); g.strokeStyle = '#ff2a2a'; g.lineCap = 'round'; g.lineWidth = 30;
  g.shadowColor = 'rgba(0,0,0,0.5)'; g.shadowBlur = 10;
  const s = 120 * lerp(1.7, 1, easeOut(p * 3));
  const p1 = clamp(p * 6), p2 = clamp(p * 6 - 0.6);
  g.globalAlpha = clamp(p * 5);
  g.beginPath(); g.moveTo(-s, -s); g.lineTo(-s + 2 * s * p1, -s + 2 * s * p1); g.stroke();
  if (p2 > 0) { g.beginPath(); g.moveTo(s, -s); g.lineTo(s - 2 * s * p2, -s + 2 * s * p2); g.stroke(); }
  g.restore();
}
function drawPopups(g, t) {
  for (const P of POPUPS) {
    const lt = t - P.t; if (lt < 0 || lt > P.d) continue;
    const outP = clamp((lt - (P.d - 0.13)) / 0.13);
    let sc = popScale(lt) * (1 - easeIn(outP));
    const x = (P.x ?? 0.5) * W, y = (P.type === 'big' ? 0.45 : (P.y ?? 0.4)) * H;
    g.save(); g.translate(x, y + Math.sin(lt * 3) * 6);
    if (P.type === 'big') {
      g.scale(sc, sc); g.rotate(-0.04);
      g.textAlign = 'center'; g.textBaseline = 'alphabetic';
      g.font = '400 360px Anton';
      g.shadowColor = P.color; g.shadowBlur = 60;
      strokeText(g, P.text, 0, 125, P.color, 24);
      g.shadowBlur = 0;
      g.font = '900 88px Montserrat'; strokeText(g, P.sub, 0, 230, '#fff', 18);
    } else if (P.type === 'icon') {
      g.scale(sc, sc); g.rotate((Math.floor(P.t * 7) % 2 ? 1 : -1) * 0.06);
      g.fillStyle = 'rgba(0,0,0,0.35)'; rr(g, -118 + 8, -118 + 12, 236, 236, 48); g.fill();
      g.fillStyle = '#ffffff'; rr(g, -118, -118, 236, 236, 48); g.fill();
      g.font = '150px "Noto Color Emoji"'; g.textAlign = 'center'; g.textBaseline = 'middle'; g.fillText(P.e, 0, 10);
      if (P.x_out) { const xt = (P.xt ?? (P.t + 0.22)); if (t >= xt) drawX(g, (t - xt) / 0.5); }
    } else if (P.type === 'battery') {
      g.scale(sc, sc);
      const lvl = lerp(0.45, 0.04, clamp(lt / (P.d * 0.8)));
      g.fillStyle = 'rgba(0,0,0,0.6)'; rr(g, -170, -85, 340, 170, 30); g.fill();
      g.lineWidth = 14; g.strokeStyle = '#fff'; rr(g, -160, -75, 300, 150, 26); g.stroke();
      g.fillStyle = '#fff'; rr(g, 145, -32, 24, 64, 8); g.fill();
      const col = lvl > 0.25 ? '#ffb300' : '#ff2a2a';
      if (!(lvl < 0.1 && Math.floor(t * 8) % 2)) { g.fillStyle = col; rr(g, -146, -61, 272 * lvl / 0.45 * 0.45 + 4, 122, 14); g.fill(); }
      g.font = '900 54px Montserrat'; g.textAlign = 'center'; g.textBaseline = 'middle';
      strokeText(g, Math.round(lvl * 100) + '%', 0, 4, '#fff', 10);
    } else if (P.type === 'gauge') {
      g.scale(sc, sc);
      g.fillStyle = 'rgba(0,0,0,0.7)'; g.beginPath(); g.arc(0, 60, 190, Math.PI, 2 * Math.PI); g.lineTo(190, 100); g.lineTo(-190, 100); g.closePath(); g.fill();
      g.lineWidth = 22; g.lineCap = 'butt';
      g.strokeStyle = '#ff2a2a'; g.beginPath(); g.arc(0, 60, 150, Math.PI, Math.PI * 1.25); g.stroke();
      g.strokeStyle = '#ffffff'; g.beginPath(); g.arc(0, 60, 150, Math.PI * 1.27, Math.PI * 2); g.stroke();
      g.font = '900 46px Montserrat'; g.textAlign = 'center'; g.textBaseline = 'middle';
      g.fillStyle = '#ff2a2a'; g.fillText('E', -150, 100 - 8); g.fillStyle = '#fff'; g.fillText('F', 150, 100 - 8);
      const a = lerp(Math.PI * 1.9, Math.PI * 1.08, easeOut(lt / (P.d * 0.8))) + Math.sin(t * 40) * 0.01;
      g.strokeStyle = '#ffd400'; g.lineWidth = 12; g.lineCap = 'round';
      g.beginPath(); g.moveTo(0, 60); g.lineTo(Math.cos(a) * 130, 60 + Math.sin(a) * 130); g.stroke();
      g.fillStyle = '#ffd400'; g.beginPath(); g.arc(0, 60, 18, 0, Math.PI * 2); g.fill();
      g.font = '900 40px Montserrat'; strokeText(g, 'DIESEL', 0, 20, '#fff', 8);
    } else if (P.type === 'thermo') {
      g.scale(sc, sc);
      const p = easeOut(lt / (P.d * 0.85));
      g.fillStyle = 'rgba(0,0,0,0.6)'; rr(g, -60, -170, 120, 330, 60); g.fill();
      g.fillStyle = '#fff'; rr(g, -26, -150, 52, 230, 26); g.fill(); g.beginPath(); g.arc(0, 100, 50, 0, Math.PI * 2); g.fill();
      g.fillStyle = '#ff2a2a'; const hh = lerp(40, 205, p); rr(g, -16, 90 - hh, 32, hh + 10, 16); g.fill(); g.beginPath(); g.arc(0, 100, 38, 0, Math.PI * 2); g.fill();
      g.font = '900 64px Montserrat'; g.textAlign = 'left'; g.textBaseline = 'middle';
      strokeText(g, Math.round(lerp(4, 19, p)) + '°C', 80, -40, p > 0.6 ? '#ff2a2a' : '#fff', 12);
    }
    g.restore();
  }
}
function drawCTA(g, t) {
  if (t < 56.75 || t > 58.85) return;
  const lt = t - 56.75; const sc = popScale(lt);
  g.save(); g.translate(540, 1460); g.scale(sc, sc);
  g.font = '900 54px Montserrat'; g.textAlign = 'center'; g.textBaseline = 'middle';
  const txt = 'WIE LANGE HÄLTST DU DURCH?'; const tw = g.measureText(txt).width;
  g.fillStyle = '#ffd400'; rr(g, -tw / 2 - 36, -50, tw + 72, 100, 50); g.fill();
  g.fillStyle = '#111'; g.fillText(txt, 0, 4);
  g.font = '64px "Noto Color Emoji"'; g.fillText('👇', 0, 110 + Math.sin(t * 8) * 10);
  g.restore();
}

function drawOverlay(t) {
  ctx.setTransform(1, 0, 0, 1, 0, 0);
  ctx.drawImage(glCanvas, 0, 0);
  // top & bottom gradients for readability
  let gr = ctx.createLinearGradient(0, 0, 0, 640); gr.addColorStop(0, 'rgba(0,0,0,0.55)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); ctx.fillStyle = gr; ctx.fillRect(0, 0, W, 640);
  gr = ctx.createLinearGradient(0, 1000, 0, 1500); gr.addColorStop(0, 'rgba(0,0,0,0)'); gr.addColorStop(0.5, 'rgba(0,0,0,0.25)'); gr.addColorStop(1, 'rgba(0,0,0,0)'); ctx.fillStyle = gr; ctx.fillRect(0, 1000, W, 500);
  drawHeader(ctx, t);
  drawTimer(ctx, t);
  drawPopups(ctx, t);
  drawCaption(ctx, t);
  drawCTA(ctx, t);
  const fl = flashAt(t);
  if (fl.a > 0) { ctx.fillStyle = `rgba(${fl.c.map((c) => Math.round(c * 255)).join(',')},${fl.a})`; ctx.fillRect(0, 0, W, H); }
}

window.renderFrame = (t, fmtOut = 'jpeg') => {
  update(t);
  composer.render();
  drawOverlay(t);
  return fmtOut === 'none' ? '' : out.toDataURL(fmtOut === 'png' ? 'image/png' : 'image/jpeg', 0.92);
};
window.ready = (async () => {
  await document.fonts.load('900 90px Montserrat'); await document.fonts.load('800 50px Montserrat'); await document.fonts.load('400 90px Anton');
  await document.fonts.load('100px "Noto Color Emoji"', '🚦');
  // warm up shader compile for every set
  for (const tt of [0.5, 5, 12, 22, 30, 37, 41, 44, 47, 53, 59.5]) { update(tt); composer.render(); }
  return true;
})();
