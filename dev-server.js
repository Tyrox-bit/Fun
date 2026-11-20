// Lokaler Testserver: node dev-server.js  →  http://localhost:3000
// Liefert die statischen Dateien aus und führt /api/* genauso aus wie Vercel.
// Ohne STRIPE_SECRET_KEY läuft alles im Demo-Modus (Bestand = voll, Checkout gesperrt).
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = __dirname;
const PORT = process.env.PORT || 3000;

// .env einlesen (ohne Zusatzpaket)
try {
  for (const line of fs.readFileSync(path.join(ROOT, '.env'), 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m && !process.env[m[1]]) process.env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
  }
} catch {}

const TYPES = {
  '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json',
  '.svg': 'image/svg+xml', '.png': 'image/png', '.jpg': 'image/jpeg', '.webp': 'image/webp',
  '.woff2': 'font/woff2', '.mp4': 'video/mp4', '.ico': 'image/x-icon',
};
const BLOCKED = /^\/(lib|scripts|node_modules|\.env|\.git|dev-server\.js|package)/;

http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://${req.headers.host}`);
  let p = decodeURIComponent(url.pathname);

  if (p.startsWith('/api/')) {
    const name = p.slice(5).replace(/[^a-z0-9-]/gi, '');
    const file = path.join(ROOT, 'api', `${name}.js`);
    if (!fs.existsSync(file)) { res.statusCode = 404; return res.end('Not found'); }
    try {
      return await require(file)(req, res);
    } catch (e) {
      console.error(e);
      res.statusCode = 500;
      return res.end('Serverfehler');
    }
  }

  if (BLOCKED.test(p)) { res.statusCode = 404; return res.end('Not found'); }
  if (p.endsWith('/')) p += 'index.html';
  let file = path.join(ROOT, path.normalize(p));
  if (!file.startsWith(ROOT)) { res.statusCode = 403; return res.end(); }
  if (!path.extname(file) && fs.existsSync(file + '.html')) file += '.html'; // cleanUrls wie bei Vercel

  fs.readFile(file, (err, data) => {
    if (err) { res.statusCode = 404; return res.end('Not found'); }
    res.setHeader('Content-Type', TYPES[path.extname(file)] || 'application/octet-stream');
    res.setHeader('Cache-Control', 'no-store');
    res.end(data);
  });
}).listen(PORT, () => {
  console.log(`\n  Casper läuft auf http://localhost:${PORT}`);
  console.log(process.env.STRIPE_SECRET_KEY ? '  Stripe: verbunden ✓' : '  Stripe: DEMO-MODUS (kein STRIPE_SECRET_KEY in .env)');
  console.log('');
});
