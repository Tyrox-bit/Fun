// POST /api/stripe-webhook  (in Stripe: Entwickler → Webhooks → Endpunkt hinzufügen)
// Events: checkout.session.completed, checkout.session.async_payment_succeeded
// Schickt Bestellbestätigung an Kund:in + Info an dich (wenn Resend eingerichtet ist).
const { send, readRaw } = require('../lib/http');
const shop = require('../lib/shop');
const { sendMail, esc, euro } = require('../lib/mail');

function orderMails(s) {
  const { config } = shop;
  const bundle = shop.getBundle(s.metadata.bundle);
  const site = process.env.SITE_URL || config.brand.siteUrl;
  const name = (s.customer_details && s.customer_details.name) || '';
  const ship = (s.collected_information && s.collected_information.shipping_details) || s.shipping_details || {};
  const addr = ship.address || {};
  const gift = (s.custom_fields || []).find((f) => f.key === 'geschenk');
  const giftText = gift && gift.text && gift.text.value;
  const orderId = s.id.slice(-8).toUpperCase();

  const customerHtml = `
    <div style="font-family:Arial,sans-serif;max-width:560px;color:#111">
      <h2>Danke für deine Bestellung${name ? ', ' + esc(name.split(' ')[0]) : ''}!</h2>
      <p>Wir haben deine Bestellung <b>#${orderId}</b> erhalten und packen sie so schnell wie möglich.</p>
      <table cellpadding="6" style="border-collapse:collapse;width:100%">
        <tr><td>${esc(config.product.fullName)} – ${esc(bundle ? bundle.title : '')}</td>
            <td align="right">${euro(s.amount_subtotal)}</td></tr>
        <tr><td>Versand</td><td align="right">${euro((s.total_details && s.total_details.amount_shipping) || 0)}</td></tr>
        ${s.total_details && s.total_details.amount_discount ? `<tr><td>Rabatt</td><td align="right">−${euro(s.total_details.amount_discount)}</td></tr>` : ''}
        <tr><td><b>Gesamt (inkl. MwSt.)</b></td><td align="right"><b>${euro(s.amount_total)}</b></td></tr>
      </table>
      <p><b>Lieferadresse:</b><br>${esc(ship.name || name)}<br>${esc(addr.line1 || '')} ${esc(addr.line2 || '')}<br>${esc(addr.postal_code || '')} ${esc(addr.city || '')}</p>
      <p>Voraussichtliche Lieferzeit: ${config.shipping.deliveryDaysMin}–${config.shipping.deliveryDaysMax} Werktage.</p>
      <hr>
      <p style="font-size:13px;color:#444">
        Es gelten unsere AGB: <a href="${site}/agb">${site}/agb</a><br>
        Widerrufsbelehrung &amp; Muster-Widerrufsformular: <a href="${site}/widerrufsbelehrung">${site}/widerrufsbelehrung</a><br>
        Vertrag widerrufen: <a href="${site}/vertrag-widerrufen">${site}/vertrag-widerrufen</a>
      </p>
      <p style="font-size:12px;color:#666">${esc(config.legal.company)} · ${esc(config.legal.owner)} · ${esc(config.legal.street)} · ${esc(config.legal.zipCity)} · ${esc(config.legal.email)}</p>
    </div>`;

  const ownerHtml = `
    <div style="font-family:Arial,sans-serif">
      <h2>Neue Bestellung #${orderId} – ${esc(bundle ? bundle.title : s.metadata.bundle)}</h2>
      <p><b>${euro(s.amount_total)}</b> · ${esc(s.customer_details && s.customer_details.email)}</p>
      <p>${esc(ship.name || name)}<br>${esc(addr.line1 || '')} ${esc(addr.line2 || '')}<br>${esc(addr.postal_code || '')} ${esc(addr.city || '')}</p>
      ${giftText ? `<p><b>Geschenknachricht:</b> ${esc(giftText)}</p>` : ''}
      <p style="color:#666">Quelle: ${esc(s.metadata.utm_source || '–')} / ${esc(s.metadata.utm_campaign || '–')} / ${esc(s.metadata.utm_content || '–')}</p>
      <p><a href="https://dashboard.stripe.com/${s.livemode ? '' : 'test/'}checkout/sessions/${s.id}">In Stripe öffnen</a></p>
    </div>`;

  return { orderId, customerHtml, ownerHtml };
}

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return send(res, 405, { error: 'Nur POST.' });
  const stripe = shop.getStripe();
  const secret = process.env.STRIPE_WEBHOOK_SECRET;
  if (!stripe || !secret) return send(res, 503, { error: 'Webhook nicht konfiguriert.' });

  let event;
  try {
    const raw = await readRaw(req);
    event = stripe.webhooks.constructEvent(raw, req.headers['stripe-signature'], secret);
  } catch (err) {
    console.error('[webhook] Signatur ungültig:', err.message);
    return send(res, 400, { error: 'Ungültige Signatur.' });
  }

  const relevant = ['checkout.session.completed', 'checkout.session.async_payment_succeeded'];
  if (!relevant.includes(event.type)) return send(res, 200, { received: true });

  const s = event.data.object;
  if (!s.metadata || s.metadata.shop !== 'casper') return send(res, 200, { received: true });
  // Bei verzögerten Zahlarten (z. B. Überweisung) erst bei Zahlungseingang bestätigen.
  if (event.type === 'checkout.session.completed' && s.payment_status !== 'paid') {
    return send(res, 200, { received: true, waiting: true });
  }

  try {
    const { orderId, customerHtml, ownerHtml } = orderMails(s);
    const tasks = [];
    if (s.customer_details && s.customer_details.email) {
      tasks.push(sendMail({ to: s.customer_details.email, subject: `Deine Casper-Bestellung #${orderId}`, html: customerHtml }));
    }
    if (process.env.SHOP_EMAIL) {
      tasks.push(sendMail({ to: process.env.SHOP_EMAIL, subject: `🔥 Neue Bestellung #${orderId}`, html: ownerHtml }));
    }
    await Promise.all(tasks);
  } catch (err) {
    console.error('[webhook] Mail-Fehler:', err.message);
    // 500 -> Stripe versucht es später erneut.
    return send(res, 500, { error: 'Mail fehlgeschlagen.' });
  }
  return send(res, 200, { received: true });
};

// Rohdaten für die Signaturprüfung behalten.
module.exports.config = { api: { bodyParser: false } };
