// POST /api/checkout
//   Aktionsseite:  { bundleId, attribution }
//   Produktseiten: { items: [{ type: 'product'|'bundle', id, qty }], returnTo, attribution }
//   → { url }
// Erstellt eine Stripe-Checkout-Session. Zahlarten (Karte, PayPal, Apple Pay,
// Google Pay, Klarna …) werden im Stripe-Dashboard aktiviert – kein Code nötig.
const { send, readJson, clean } = require('../lib/http');
const shop = require('../lib/shop');
const catalog = require('../lib/catalog');

const ATTR_KEYS = ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'fbclid', 'ttclid', 'landing', 'referrer'];

module.exports = async function handler(req, res) {
  if (req.method !== 'POST') return send(res, 405, { error: 'Nur POST erlaubt.' });

  let body;
  try {
    body = await readJson(req);
  } catch {
    return send(res, 400, { error: 'Ungültige Anfrage.' });
  }

  // Zwei Wege: Aktionsseite (bundleId) oder Warenkorb der Produktseiten (items)
  const isCart = Array.isArray(body.items);
  const bundle = isCart ? null : shop.getBundle(body.bundleId);
  let cart = null;
  if (isCart) {
    cart = catalog.validateCart(body.items);
    if (cart.error) return send(res, 400, { error: cart.error });
  } else if (!bundle) {
    return send(res, 400, { error: 'Unbekanntes Angebot.' });
  }

  const stripe = shop.getStripe();
  if (!stripe) {
    return send(res, 503, {
      error: 'Demo-Modus: Es ist noch kein Stripe-Schlüssel hinterlegt (STRIPE_SECRET_KEY).',
      demo: true,
    });
  }

  try {
    const { config } = shop;
    const origin = shop.siteOrigin(req);

    const attribution = {};
    const a = body.attribution && typeof body.attribution === 'object' ? body.attribution : {};
    for (const k of ATTR_KEYS) if (a[k]) attribution[k] = clean(a[k], 200);

    let lineItems, shipping, metadata, cancelUrl;

    if (isCart) {
      // Bestand je Messer prüfen (nur wenn in der Config ein stock-Wert gesetzt ist)
      const limited = Object.keys(cart.units).filter((id) => Number.isInteger(catalog.getProduct(id).stock));
      if (limited.length) {
        const sold = await shop.getProductUnits({ fresh: true });
        for (const id of limited) {
          const p = catalog.getProduct(id);
          const left = Math.max(0, p.stock - (sold[id] || 0));
          if (cart.units[id] > left) {
            return send(res, 409, { error: left ? `${p.shortName}: nur noch ${left} Stück verfügbar.` : `${p.shortName} ist leider ausverkauft.` });
          }
        }
      }
      lineItems = cart.items.map((it) => {
        const ref = it.ref;
        const firstId = it.type === 'bundle' ? ref.items[0] : ref.id;
        return {
          quantity: it.qty,
          price_data: {
            currency: config.pricing.currency,
            unit_amount: it.unitAmount,
            product_data: {
              name: it.type === 'bundle' ? `KASPAR Bundle: ${ref.name}` : ref.name,
              description: it.type === 'bundle'
                ? ref.items.map((id) => catalog.getProduct(id).name).join(' + ') + ' – je mit Geschenkbox und Schutz-Noppen'
                : 'Mit KASPAR Geschenkbox und Schutz-Noppen',
              images: [`${origin}/assets/img/produkte/${firstId}/og.jpg`],
            },
          },
        };
      });
      shipping = catalog.shippingForKnives(cart.knives);
      metadata = { shop: 'kaspar', kind: 'shop', items: catalog.encodeItems(cart.items), knives: String(cart.knives), ...attribution };
      cancelUrl = `${origin}/produkte/${body.returnTo && catalog.getProduct(body.returnTo) ? body.returnTo : cart.items[0].type === 'product' ? cart.items[0].id : catalog.catalog.products[0].id}?checkout=abgebrochen`;
    } else {
      const stock = await shop.getStock({ fresh: true });
      if (stock.remainingSets < bundle.sets) {
        return send(res, 409, {
          error: stock.remainingSets === 0
            ? 'Leider ausverkauft.'
            : `Nur noch ${stock.remainingSets} Set(s) verfügbar – bitte kleineres Paket wählen.`,
          remainingSets: stock.remainingSets,
        });
      }
      shipping = shop.shippingFor(bundle);
      metadata = {
        shop: 'kaspar',
        campaign: shop.isCampaignActive() ? config.campaign.id : 'regulaer',
        bundle: bundle.id,
        sets: String(bundle.sets),
        ...attribution,
      };
      lineItems = [
        {
          quantity: 1,
          price_data: {
            currency: config.pricing.currency,
            unit_amount: shop.priceFor(bundle),
            product_data: {
              name: `${config.product.fullName} · ${bundle.title}`,
              description: `${bundle.sets}× ${config.product.short}`,
              images: [`${origin}${config.product.image}`],
            },
          },
        },
      ];
      cancelUrl = `${origin}/?checkout=abgebrochen#angebot`;
    }

    const params = {
      mode: 'payment',
      locale: 'de',
      submit_type: 'pay',
      line_items: lineItems,
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
      cancel_url: cancelUrl,
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
