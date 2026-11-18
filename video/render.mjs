// Usage:
//   node render.mjs preview 0.5 5.6 12 ...   -> out/preview_<t>.png
//   node render.mjs video [start] [end]      -> out/video_noaudio.mp4 (or a segment)
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(ROOT, 'out');
fs.mkdirSync(OUT, { recursive: true });
const FPS = 30, DURATION = JSON.parse(fs.readFileSync(path.join(path.dirname(fileURLToPath(import.meta.url)), 'out/sync.json'), 'utf8')).duration;

const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.woff2': 'font/woff2', '.woff': 'font/woff', '.json': 'application/json' };
const server = http.createServer((req, res) => {
  const p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(ROOT) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) { res.writeHead(404); return res.end(); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});
await new Promise((r) => server.listen(0, '127.0.0.1', r));
const port = server.address().port;

const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
const page = await browser.newPage({ viewport: { width: 1080, height: 1920 } });
page.on('console', (m) => { if (m.type() === 'error' || m.type() === 'warning') console.log('[page]', m.text()); });
page.on('pageerror', (e) => console.log('[pageerror]', e.message));
await page.goto(`http://127.0.0.1:${port}/src/index.html`);
await page.waitForFunction(() => window.ready !== undefined, null, { timeout: 60000 });
await page.evaluate(() => window.ready);

const mode = process.argv[2] || 'preview';
if (mode === 'preview') {
  const times = process.argv.slice(3).map(Number);
  for (const t of times) {
    const t0 = Date.now();
    const url = await page.evaluate((tt) => window.renderFrame(tt, 'png'), t);
    fs.writeFileSync(path.join(OUT, `preview_${t.toFixed(2)}.png`), Buffer.from(url.split(',')[1], 'base64'));
    console.log(`t=${t} ${Date.now() - t0}ms`);
  }
} else {
  const start = Number(process.argv[3] ?? 0), end = Number(process.argv[4] ?? DURATION);
  const name = process.argv[5] || 'video_noaudio.mp4';
  const f0 = Math.round(start * FPS), f1 = Math.round(end * FPS);
  const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-c:v', 'mjpeg', '-i', '-',
    '-c:v', 'libx264', '-preset', 'medium', '-crf', '17', '-pix_fmt', 'yuv420p', '-r', String(FPS), path.join(OUT, name)], { stdio: ['pipe', 'inherit', 'inherit'] });
  const T0 = Date.now();
  for (let f = f0; f < f1; f++) {
    const url = await page.evaluate((tt) => window.renderFrame(tt, 'jpeg'), f / FPS);
    const buf = Buffer.from(url.split(',')[1], 'base64');
    if (!ff.stdin.write(buf)) await new Promise((r) => ff.stdin.once('drain', r));
    if ((f - f0) % 30 === 0) {
      const el = (Date.now() - T0) / 1000, done = f - f0 + 1;
      console.log(`frame ${f}/${f1} (${(el / done).toFixed(2)}s/f, eta ${((f1 - f) * el / done / 60).toFixed(1)} min)`);
    }
  }
  ff.stdin.end();
  await new Promise((r) => ff.on('close', r));
  console.log('done', name);
}
await browser.close();
server.close();
