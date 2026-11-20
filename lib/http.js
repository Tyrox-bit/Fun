// Kleine Helfer, die sowohl auf Vercel als auch im lokalen Dev-Server funktionieren.

function send(res, status, data, headers = {}) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  for (const [k, v] of Object.entries(headers)) res.setHeader(k, v);
  res.end(JSON.stringify(data));
}

function readRaw(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function readJson(req) {
  // Vercel parst JSON-Bodies bereits selbst.
  if (req.body && typeof req.body === 'object' && !Buffer.isBuffer(req.body)) return req.body;
  if (typeof req.body === 'string') return JSON.parse(req.body || '{}');
  const raw = await readRaw(req);
  if (!raw.length) return {};
  return JSON.parse(raw.toString('utf8'));
}

function clean(value, max = 100) {
  if (value === undefined || value === null) return '';
  return String(value).replace(/[\u0000-\u001f]/g, '').trim().slice(0, max);
}

module.exports = { send, readRaw, readJson, clean };
