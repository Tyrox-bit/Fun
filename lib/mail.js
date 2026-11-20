// E-Mail-Versand über Resend (https://resend.com) – optional.
// Ohne RESEND_API_KEY werden Mails nur ins Log geschrieben.

function mailConfigured() {
  return Boolean(process.env.RESEND_API_KEY && process.env.MAIL_FROM);
}

async function sendMail({ to, subject, html, text, replyTo }) {
  if (!mailConfigured()) {
    console.log('[mail:nicht konfiguriert]', { to, subject });
    return { skipped: true };
  }
  const res = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.RESEND_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: process.env.MAIL_FROM,
      to: Array.isArray(to) ? to : [to],
      subject,
      html,
      text,
      reply_to: replyTo || process.env.SHOP_EMAIL || undefined,
    }),
  });
  if (!res.ok) {
    const body = await res.text();
    throw new Error(`Mailversand fehlgeschlagen (${res.status}): ${body}`);
  }
  return res.json();
}

function esc(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
}

function euro(cents) {
  return (cents / 100).toLocaleString('de-DE', { style: 'currency', currency: 'EUR' });
}

module.exports = { mailConfigured, sendMail, esc, euro };
