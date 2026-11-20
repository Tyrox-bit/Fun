// Selbsttest ohne echtes Stripe-Konto: npm run check
// Simuliert Stripe und prüft Preise, Bestand, Ausverkauft-Fall und Webhook.
const assert = require('assert');
const path = require('path');
const { Readable } = require('stream');

const sessions = [];
const created = [];
const fakeStripe = () => ({
  checkout: {
    sessions: {
      list: ({ status }) => ({
        async *[Symbol.asyncIterator]() { for (const s of sessions) if (s.status === status) yield s; },
      }),
      create: async (params) => { created.push(params); return { url: 'https://checkout.stripe.com/c/pay/test' }; },
      retrieve: async (id) => sessions.find((s) => s.id === id),
    },
  },
  webhooks: {
    constructEvent: (raw, sig) => { if (sig !== 'ok') throw new Error('bad sig'); return JSON.parse(raw.toString()); },
  },
});
require.cache[require.resolve('stripe')] = { id: 'stripe', filename: 'stripe', loaded: true, exports: fakeStripe };
process.env.STRIPE_SECRET_KEY = 'sk_test_dummy';
process.env.STRIPE_WEBHOOK_SECRET = 'whsec_dummy';
process.env.SITE_URL = 'https://shop.test';

const root = path.join(__dirname, '..');
const shop = require(path.join(root, 'lib/shop'));
const checkout = require(path.join(root, 'api/checkout'));
const stock = require(path.join(root, 'api/stock'));
const webhook = require(path.join(root, 'api/stripe-webhook'));

function call(handler, { method = 'GET', body, headers = {}, url = '/' } = {}) {
  return new Promise((resolve) => {
    const req = Readable.from(body ? [Buffer.from(typeof body === 'string' ? body : JSON.stringify(body))] : []);
    Object.assign(req, { method, headers: { host: 'localhost', ...headers }, url });
    const res = {
      statusCode: 200, headers: {},
      setHeader(k, v) { this.headers[k] = v; },
      end(data) { resolve({ status: this.statusCode, body: data ? JSON.parse(data) : null }); },
    };
    handler(req, res);
  });
}

(async () => {
  const cfg = shop.config;
  const inSale = shop.isCampaignActive();
  console.log('Aktion aktiv:', inSale);

  // 1) Unbekanntes Paket
  let r = await call(checkout, { method: 'POST', body: { bundleId: 'hack', price: 1 } });
  assert.strictEqual(r.status, 400);

  // 2) Preis wird vom Server bestimmt (Browser-Preis wird ignoriert)
  r = await call(checkout, { method: 'POST', body: { bundleId: 'duo-2', price: 1, attribution: { utm_source: 'instagram', evil: 'x' } } });
  assert.strictEqual(r.status, 200);
  const p = created.at(-1);
  const b2 = cfg.bundles.find((b) => b.id === 'duo-2');
  assert.strictEqual(p.line_items[0].price_data.unit_amount, inSale ? b2.salePrice : b2.compareAtPrice);
  assert.strictEqual(p.shipping_options[0].shipping_rate_data.fixed_amount.amount, 0, '2 Sets = gratis Versand');
  assert.strictEqual(p.metadata.utm_source, 'instagram');
  assert.ok(!('evil' in p.metadata), 'unbekannte Felder werden verworfen');
  assert.deepStrictEqual(p.shipping_address_collection.allowed_countries, ['DE']);
  assert.ok(p.success_url.startsWith('https://shop.test/danke'));

  r = await call(checkout, { method: 'POST', body: { bundleId: 'duo-1' } });
  assert.strictEqual(created.at(-1).shipping_options[0].shipping_rate_data.fixed_amount.amount, cfg.shipping.price);
  console.log('✓ Preise & Versand serverseitig korrekt');

  // 3) Bestand: verkaufte + offene Checkouts werden abgezogen
  const t = Math.floor(Date.now() / 1000);
  for (let i = 0; i < 18; i++) sessions.push({ id: 'cs_test_' + i, status: 'complete', created: t, metadata: { shop: 'casper', sets: '2', bundle: 'duo-2' } });
  sessions.push({ id: 'cs_test_open', status: 'open', created: t, metadata: { shop: 'casper', sets: '3', bundle: 'duo-3' } });
  sessions.push({ id: 'cs_other', status: 'complete', created: t, metadata: {} }); // anderer Shop – ignorieren
  shop.invalidateStock();
  r = await call(stock);
  assert.strictEqual(r.body.soldSets, 36);
  assert.strictEqual(r.body.reservedSets, 3);
  assert.strictEqual(r.body.remainingSets, 1);
  console.log('✓ Bestand live berechnet: noch', r.body.remainingSets, 'Set');

  // 4) Überverkauf wird verhindert
  r = await call(checkout, { method: 'POST', body: { bundleId: 'duo-2' } });
  assert.strictEqual(r.status, 409);
  r = await call(checkout, { method: 'POST', body: { bundleId: 'duo-1' } });
  assert.strictEqual(r.status, 200);
  sessions.push({ id: 'cs_last', status: 'complete', created: t, metadata: { shop: 'casper', sets: '1' } });
  r = await call(checkout, { method: 'POST', body: { bundleId: 'duo-1' } });
  assert.strictEqual(r.status, 409);
  assert.match(r.body.error, /ausverkauft/i);
  console.log('✓ Überverkauf blockiert');

  // 5) Webhook: Signatur wird geprüft
  const evt = { type: 'checkout.session.completed', data: { object: {
    id: 'cs_test_abcdefgh12345678', livemode: false, payment_status: 'paid', amount_total: 17900, amount_subtotal: 17900,
    total_details: { amount_shipping: 0, amount_discount: 0 }, customer_details: { email: 'k@test.de', name: 'Kim Test' },
    collected_information: { shipping_details: { name: 'Kim Test', address: { line1: 'Weg 1', postal_code: '10115', city: 'Berlin' } } },
    custom_fields: [{ key: 'geschenk', text: { value: 'Frohe Weihnachten' } }],
    metadata: { shop: 'casper', bundle: 'duo-2', sets: '2' },
  } } };
  r = await call(webhook, { method: 'POST', body: evt, headers: { 'stripe-signature': 'falsch' } });
  assert.strictEqual(r.status, 400);
  r = await call(webhook, { method: 'POST', body: evt, headers: { 'stripe-signature': 'ok' } });
  assert.strictEqual(r.status, 200);
  console.log('✓ Webhook prüft Signatur und verarbeitet Bestellung');

  console.log('\nAlle Checks bestanden 🔥');
})().catch((e) => { console.error('✗', e); process.exit(1); });
