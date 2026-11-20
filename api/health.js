// GET /api/health – zeigt, ob alle Verbindungen auf dem Server eingerichtet sind.
// Gibt nur Ja/Nein zurück, niemals Schlüssel.
const { send } = require('../lib/http');
const shop = require('../lib/shop');
const { mailConfigured } = require('../lib/mail');

module.exports = async function handler(req, res) {
  const key = process.env.STRIPE_SECRET_KEY || '';
  return send(res, 200, {
    stripe: key ? (key.includes('_live_') ? 'live' : 'test') : false,
    webhook: Boolean(process.env.STRIPE_WEBHOOK_SECRET),
    mail: mailConfigured() && Boolean(process.env.SHOP_EMAIL),
    siteUrl: Boolean(process.env.SITE_URL),
    campaignActive: shop.isCampaignActive(),
  }, { 'Cache-Control': 'no-store' });
};
