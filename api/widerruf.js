// POST /api/widerruf – elektronische Widerrufsfunktion ("Widerrufsbutton").
// Leitet die Erklärung an dich weiter und schickt der Kundin / dem Kunden sofort
// eine Eingangsbestätigung mit Datum und Uhrzeit.
const { send, readJson, clean } = require('../lib/http');
const shop = require('../lib/shop');
const { mailConfigured, sendMail, esc } = require('../lib/mail');

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return send(res, 405, { error: 'Nur POST.' });

  let b;
  try {
    b = await readJson(req);
  } catch {
    return send(res, 400, { error: 'Ungültige Anfrage.' });
  }
  if (b.website) return send(res, 200, { ok: true }); // Honeypot gegen Spam-Bots

  const name = clean(b.name, 120);
  const email = clean(b.email, 160);
  const orderRef = clean(b.orderRef, 60);
  const orderDate = clean(b.orderDate, 40);
  const note = clean(b.note, 1000);

  if (!name || !/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email) || !orderRef) {
    return send(res, 400, { error: 'Bitte Name, E-Mail und Bestellnummer angeben.' });
  }

  const { legal } = shop.config;
  if (!mailConfigured() || !process.env.SHOP_EMAIL) {
    return send(res, 503, {
      error: `Die Online-Funktion ist gerade nicht erreichbar. Bitte schick deinen Widerruf formlos per E-Mail an ${legal.email}.`,
    });
  }

  const received = new Date().toLocaleString('de-DE', { timeZone: 'Europe/Berlin', dateStyle: 'full', timeStyle: 'medium' });
  const details = `
    <p><b>Name:</b> ${esc(name)}<br><b>E-Mail:</b> ${esc(email)}<br>
    <b>Bestellnummer:</b> ${esc(orderRef)}<br><b>Bestellt/erhalten am:</b> ${esc(orderDate || '–')}</p>
    ${note ? `<p><b>Anmerkung:</b> ${esc(note)}</p>` : ''}`;

  try {
    await sendMail({
      to: process.env.SHOP_EMAIL,
      subject: `Widerruf eingegangen – Bestellung ${orderRef}`,
      html: `<div style="font-family:Arial,sans-serif"><h2>Widerruf eingegangen</h2><p>Eingang: ${received}</p>${details}</div>`,
      replyTo: email,
    });
    await sendMail({
      to: email,
      subject: `Eingangsbestätigung deines Widerrufs – Bestellung ${orderRef}`,
      html: `<div style="font-family:Arial,sans-serif;max-width:560px">
        <h2>Wir haben deinen Widerruf erhalten</h2>
        <p>Hiermit bestätigen wir den Eingang deiner Widerrufserklärung am <b>${received}</b>.</p>
        ${details}
        <p>Wir melden uns mit den nächsten Schritten zur Rücksendung. Die Rückzahlung erfolgt über das ursprüngliche Zahlungsmittel.</p>
        <p style="font-size:12px;color:#666">${esc(legal.company)} · ${esc(legal.owner)} · ${esc(legal.street)} · ${esc(legal.zipCity)} · ${esc(legal.email)}</p>
      </div>`,
    });
    return send(res, 200, { ok: true, received });
  } catch (err) {
    console.error('[widerruf]', err.message);
    return send(res, 500, { error: `Senden fehlgeschlagen. Bitte schick deinen Widerruf per E-Mail an ${legal.email}.` });
  }
};
