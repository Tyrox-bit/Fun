// POST /api/checkout  { bundleId, attribution }  ->  { url }
// Erstellt eine Stripe-Checkout-Session. Zahlarten (Karte, PayPal, Apple Pay,
// Google Pay, Klarna …) werden im Stripe-Dashboard aktiviert – kein Code nötig.
const { send, readJson, clean } = require('../lib/http');
const shop = require('../lib/shop');

const ATTR_KEYS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid', 'ttclid', 'landing', 'referrer'];

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return send(res, 405, { error: 'Nur POST erlaubt.' });

  let body;
  try {
    body = await readJson(req);
  } catch {
    return send(res, 400, { error: 'Ungültige Anfrage.' });
  }

  const bundle = shop.getBundle(body.bundleId);
  if (!bundle) return send(res, 400, { error: 'Unbekanntes Angebot.' });

  const stripe = shop.getStripe();
  if (!stripe) {
    return send(res, 503, {
      error: 'Demo-Modus: Es ist noch kein Stripe-Schlüssel hinterlegt (STRIPE_SECRET_KEY).',
      demo: true,
    });
  }

  try {
    const stock = await shop.getStock({ fresh: true });
    if (stock.remainingSets < bundle.sets) {
      return send(res, 409, {
        error: stock.remainingSets === 0
          ? 'Leider ausverkauft.'
          : `Nur noch ${stock.remainingSets} Set(s) verfügbar – bitte kleineres Paket wählen.`,
        remainingSets: stock.remainingSets,
      });
    }

    const { config } = shop;
    const origin = shop.siteOrigin(req);
    const unitAmount = shop.priceFor(bundle);
    const shipping = shop.shippingFor(bundle);

    const attribution = {};
    const a = body.attribution && typeof body.attribution === 'object' ? body.attribution : {};
    for (const k of ATTR_KEYS) if (a[k]) attribution[k] = clean(a[k], 200);

    const metadata = {
      shop: 'kaspar',
      campaign: shop.isCampaignActive() ? config.campaign.id : 'regulaer',
      bundle: bundle.id,
      sets: String(bundle.sets),
      ...attribution,
    };

    const params = {
      mode: 'payment',
      locale: 'de',
      submit_type: 'pay',
      line_items: [
        {
          quantity: 1,
          price_data: {
            currency: config.pricing.currency,
            unit_amount: unitAmount,
            product_data: {
              name: `${config.product.fullName} · ${bundle.title}`,
              description: `${bundle.sets}× ${config.product.short}`,
              images: [`${origin}${config.product.image}`],
            },
          },
        },
      ],
      shipping_address_collection: { allowed_countries: config.shipping.countries },
      shipping_options: [
        {
          shipping_rate_data: {
            type: 'fixed_amount',
            display_name: shipping === 0 ? `${config.shipping.carrier} – kostenlos` : config.shipping.carrier,
            fixed_amount: { amount: shipping, currency: config.pricing.currency },
            delivery_estimate: {
              minimum: { unit: 'business_day', value: config.shipping.deliveryDaysMin },
              maximum: { unit: 'business_day', value: config.shipping.deliveryDaysMax },
            },
          },
        },
      ],
      // Rabattcodes (z. B. für Creator/Influencer) im Stripe-Dashboard anlegen.
      allow_promotion_codes: true,
      custom_fields: [
        {
          key: 'geschenk',
          label: { type: 'custom', custom: 'Geschenknachricht (optional)' },
          type: 'text',
          optional: true,
          text: { maximum_length: 200 },
        },
      ],
      custom_text: {
        submit: {
          message: `Mit Klick auf „Bezahlen“ bestellst du zahlungspflichtig. Es gelten unsere AGB und die Widerrufsbelehrung (${origin}/agb · ${origin}/widerrufsbelehrung).`,
        },
      },
      metadata,
      payment_intent_data: { metadata },
      // Reservierung verfällt nach 30 Minuten (Stripe-Minimum) – dann ist das Set wieder frei.
      expires_at: Math.floor(Date.now() / 1000) + 31 * 60,
      success_url: `${origin}/danke?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${origin}/?checkout=abgebrochen#angebot`,
    };

    // Optional: AGB-Häkchen direkt im Checkout (vorher AGB-URL in Stripe hinterlegen:
    // Einstellungen → Öffentliche Unternehmensdetails).
    if (process.env.STRIPE_REQUIRE_TOS === 'true') {
      params.consent_collection = { terms_of_service: 'required' };
    }
    // Optional: Stripe erstellt automatisch eine Rechnung (kostet extra Gebühr).
    if (process.env.STRIPE_INVOICE === 'true') {
      params.invoice_creation = { enabled: true };
    }

    const session = await stripe.checkout.sessions.create(params);
    shop.invalidateStock();
    return send(res, 200, { url: session.url });
  } catch (err) {
    console.error('[checkout]', err);
    return send(res, 500, { error: 'Checkout konnte nicht gestartet werden. Bitte versuch es gleich nochmal.' });
  }
};
