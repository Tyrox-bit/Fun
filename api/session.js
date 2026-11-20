// GET /api/session?id=cs_... -> minimale Bestelldaten für die Danke-Seite
// (gibt bewusst nur Vorname, Paket und Betrag zurück – keine Adresse/E-Mail).
const { send } = require('../lib/http');
const shop = require('../lib/shop');
const { describeItems } = require('../lib/catalog');

module.exports = async function handler(req, res) {
  const url = new URL(req.url, 'http://localhost');
  const id = url.searchParams.get('id') || '';
  if (!/^cs_(test|live)_[A-Za-z0-9]+$/.test(id)) return send(res, 400, { error: 'Ungültige Session.' });

  const stripe = shop.getStripe();
  if (!stripe) return send(res, 503, { error: 'Demo-Modus.' });

  try {
    const s = await stripe.checkout.sessions.retrieve(id);
    if (!s.metadata || s.metadata.shop !== 'kaspar') return send(res, 404, { error: 'Nicht gefunden.' });
    const bundle = shop.getBundle(s.metadata.bundle);
    const fullName = (s.customer_details && s.customer_details.name) || '';
    const isShop = s.metadata.kind === 'shop';
    return send(res, 200, {
      status: s.status,
      paymentStatus: s.payment_status,
      orderId: s.id.slice(-8).toUpperCase(),
      firstName: fullName.split(' ')[0] || '',
      bundleId: isShop ? 'warenkorb' : s.metadata.bundle,
      bundleTitle: isShop ? '' : bundle ? bundle.title : '',
      title: isShop ? describeItems(s.metadata.items) : `${bundle ? bundle.title : ''} · Damast-Duo`,
      sets: parseInt(s.metadata.sets, 10) || 1,
      amountTotal: s.amount_total,
      currency: s.currency,
    }, { 'Cache-Control': 'no-store' });
  } catch (err) {
    console.error('[session]', err.message);
    return send(res, 404, { error: 'Nicht gefunden.' });
  }
};
