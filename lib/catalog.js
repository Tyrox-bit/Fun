// Katalog-Logik für die Produktseiten (Einzelmesser + Bundles + Warenkorb).
// Preise kommen ausschließlich aus shop.config.json – nie aus dem Browser.
const config = require('../shop.config.json');

const catalog = config.catalog || { products: [], bundles: [] };
const MAX_QTY = 10;
const MAX_ITEMS = 20;

function getProduct(id) {
  return catalog.products.find((p) => p.id === id) || null;
}
function getCatalogBundle(id) {
  return catalog.bundles.find((b) => b.id === id) || null;
}

// Bundle-Preis: eigener Preis, sonst Summe der Einzelpreise (kein erfundener Rabatt).
// null, wenn ein enthaltenes Messer noch keinen Preis hat.
function bundlePrice(bundle) {
  if (Number.isInteger(bundle.price)) return bundle.price;
  let sum = 0;
  for (const id of bundle.items) {
    const p = getProduct(id);
    if (!p || !Number.isInteger(p.price)) return null;
    sum += p.price;
  }
  return sum;
}

function itemPrice(item) {
  if (item.type === 'product') { const p = getProduct(item.id); return p && Number.isInteger(p.price) ? p.price : null; }
  if (item.type === 'bundle') { const b = getCatalogBundle(item.id); return b ? bundlePrice(b) : null; }
  return null;
}

// Prüft einen Warenkorb aus dem Browser und gibt saubere Positionen zurück.
function validateCart(raw) {
  if (!Array.isArray(raw) || !raw.length) return { error: 'Der Warenkorb ist leer.' };
  const merged = new Map();
  for (const r of raw) {
    const type = r && (r.type === 'bundle' ? 'bundle' : r.type === 'product' ? 'product' : null);
    const id = r && typeof r.id === 'string' ? r.id : '';
    const qty = Math.floor(Number(r && r.qty));
    if (!type || !id || !(qty >= 1)) return { error: 'Ungültige Position im Warenkorb.' };
    const ref = type === 'product' ? getProduct(id) : getCatalogBundle(id);
    if (!ref) return { error: 'Ein Artikel im Warenkorb existiert nicht mehr.' };
    const key = type + ':' + id;
    merged.set(key, { type, id, qty: Math.min(MAX_QTY, (merged.get(key)?.qty || 0) + qty), ref });
  }
  const items = [...merged.values()];
  let knives = 0;
  const units = {}; // Messer je Produkt (Bundles aufgelöst) – für Bestand
  for (const it of items) {
    const price = itemPrice(it);
    if (price === null) return { error: `Für „${it.ref.name}“ ist noch kein Preis hinterlegt.` };
    it.unitAmount = price;
    const ids = it.type === 'bundle' ? it.ref.items : [it.id];
    for (const pid of ids) { units[pid] = (units[pid] || 0) + it.qty; knives += it.qty; }
  }
  if (knives > MAX_ITEMS) return { error: `Maximal ${MAX_ITEMS} Messer pro Bestellung.` };
  return { items, knives, units };
}

function shippingForKnives(knives) {
  const from = catalog.freeShippingFromItems;
  return Number.isInteger(from) && knives >= from ? 0 : config.shipping.price;
}

// Kompakte Beschreibung für Stripe-Metadaten (max. 500 Zeichen): "p:chefmesser:1,b:komplett-set:1"
function encodeItems(items) {
  return items.map((i) => `${i.type === 'bundle' ? 'b' : 'p'}:${i.id}:${i.qty}`).join(',').slice(0, 500);
}
function decodeItems(str) {
  return String(str || '').split(',').filter(Boolean).map((s) => {
    const [t, id, q] = s.split(':');
    return { type: t === 'b' ? 'bundle' : 'product', id, qty: parseInt(q, 10) || 1 };
  });
}
// Lesbarer Text, z. B. für Mails und Danke-Seite
function describeItems(str) {
  return decodeItems(str).map((i) => {
    const ref = i.type === 'bundle' ? getCatalogBundle(i.id) : getProduct(i.id);
    return `${i.qty}× ${ref ? ref.name : i.id}`;
  }).join(', ');
}

module.exports = {
  catalog, getProduct, getCatalogBundle, bundlePrice, itemPrice,
  validateCart, shippingForKnives, encodeItems, decodeItems, describeItems,
};
