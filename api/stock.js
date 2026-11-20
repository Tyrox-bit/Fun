// GET /api/stock -> echter Lagerbestand + Zeitpunkt der letzten Bestellung
const { send } = require('../lib/http');
const shop = require('../lib/shop');

module.exports = async function handler(req, res) {
  try {
    const stock = await shop.getStock();
    return send(res, 200, { ...stock, campaignActive: shop.isCampaignActive(), serverTime: Date.now() }, {
      'Cache-Control': 'public, max-age=0, s-maxage=20, stale-while-revalidate=40',
    });
  } catch (err) {
    console.error('[stock]', err);
    return send(res, 500, { error: 'Bestand nicht verfügbar.' });
  }
};
