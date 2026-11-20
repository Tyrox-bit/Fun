// Gemeinsame Server-Logik: Konfiguration, Preise, Lagerbestand.
const config = require('../shop.config.json');

let stripeClient = null;
function getStripe() {
  const key = process.env.STRIPE_SECRET_KEY;
  if (!key) return null; // Demo-Modus ohne Stripe
  if (!stripeClient) stripeClient = require('stripe')(key);
  return stripeClient;
}

function isCampaignActive(now = new Date()) {
  const start = new Date(config.campaign.start);
  const end = new Date(config.campaign.end);
  return now >= start && now <= end;
}

function getBundle(id) {
  return config.bundles.find((b) => b.id === id) || null;
}

// Der Preis wird IMMER hier auf dem Server bestimmt – nie aus dem Browser übernommen.
function priceFor(bundle, now = new Date()) {
  return isCampaignActive(now) ? bundle.salePrice : bundle.compareAtPrice;
}

function shippingFor(bundle) {
  const s = config.shipping;
  return bundle.sets >= s.freeFromSets ? 0 : s.price;
}

// ---------------------------------------------------------------------------
// Lagerbestand: wird live aus Stripe berechnet (keine Datenbank nötig).
// Gezählt werden abgeschlossene + gerade offene Checkouts (= reserviert),
// damit bei 40 Sets nichts überverkauft wird.
// ---------------------------------------------------------------------------
const cache = { at: 0, value: null };
const CACHE_MS = 20 * 1000;

async function sumSets(stripe, status, since) {
  let sets = 0;
  let lastOrderAt = 0;
  const params = { status, limit: 100, created: { gte: since } };
  for await (const s of stripe.checkout.sessions.list(params)) {
    if (!s.metadata || s.metadata.shop !== 'casper') continue;
    sets += parseInt(s.metadata.sets, 10) || 0;
    if (status === 'complete' && s.created > lastOrderAt) lastOrderAt = s.created;
  }
  return { sets, lastOrderAt };
}

async function getStock({ fresh = false } = {}) {
  const total = config.stock.totalSets;
  const stripe = getStripe();
  if (!stripe) {
    return { totalSets: total, soldSets: 0, reservedSets: 0, remainingSets: total, lastOrderAt: null, demo: true };
  }
  if (!fresh && cache.value && Date.now() - cache.at < CACHE_MS) return cache.value;

  const since = Math.floor(new Date(config.stock.countFrom).getTime() / 1000);
  const [done, open] = await Promise.all([
    sumSets(stripe, 'complete', since),
    sumSets(stripe, 'open', since),
  ]);
  const value = {
    totalSets: total,
    soldSets: done.sets,
    reservedSets: open.sets,
    remainingSets: Math.max(0, total - done.sets - open.sets),
    lastOrderAt: done.lastOrderAt ? done.lastOrderAt * 1000 : null,
    demo: false,
  };
  cache.value = value;
  cache.at = Date.now();
  return value;
}

function invalidateStock() {
  cache.at = 0;
}

function siteOrigin(req) {
  if (process.env.SITE_URL) return process.env.SITE_URL.replace(/\/$/, '');
  const proto = req.headers['x-forwarded-proto'] || 'http';
  const host = req.headers['x-forwarded-host'] || req.headers.host;
  return `${proto}://${host}`;
}

module.exports = {
  config,
  getStripe,
  isCampaignActive,
  getBundle,
  priceFor,
  shippingFor,
  getStock,
  invalidateStock,
  siteOrigin,
};
