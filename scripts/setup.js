// npm run setup              → Einrichtungs-Assistent (Firmendaten, Stripe, E-Mail)
// npm run setup -- --testmail → nur Testmail verschicken (z. B. nach DNS-Freigabe)
// ---------------------------------------------------------------------------
// Erledigt automatisch:
//  • Firmendaten in shop.config.json (Impressum, AGB, Mails …)
//  • Stripe-Schlüssel prüfen, Zahlarten anzeigen & einschalten
//  • Stripe-Webhook für Bestellbestätigungen anlegen (+ Secret speichern)
//  • Resend-Mail-Domain anlegen und dir die DNS-Einträge anzeigen
//  • Testmail an dich
//  • .env schreiben – deren Inhalt kopierst du 1:1 nach Vercel
// ---------------------------------------------------------------------------
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const ROOT = path.join(__dirname, '..');
const ENV_FILE = path.join(ROOT, '.env');
const CONFIG_FILE = path.join(ROOT, 'shop.config.json');
const WEBHOOK_EVENTS = ['checkout.session.completed', 'checkout.session.async_payment_succeeded'];

// ---------------------------------------------------------------- Helfer
const c = { b: (s) => `\x1b[1m${s}\x1b[0m`, g: (s) => `\x1b[32m${s}\x1b[0m`, y: (s) => `\x1b[33m${s}\x1b[0m`, r: (s) => `\x1b[31m${s}\x1b[0m`, o: (s) => `\x1b[38;5;208m${s}\x1b[0m`, d: (s) => `\x1b[2m${s}\x1b[0m` };
const ok = (s) => console.log(c.g('  ✓ ') + s);
const warn = (s) => console.log(c.y('  ⚠ ') + s);
const fail = (s) => console.log(c.r('  ✗ ') + s);
const info = (s) => console.log(c.d('    ' + s));
const step = (n, s) => console.log('\n' + c.o(`━━ ${n} ━━ `) + c.b(s));

const rl = readline.createInterface({ input: process.stdin, output: process.stdout, terminal: process.stdin.isTTY });
let muted = false;
rl._writeToOutput = function (s) {
  if (muted && !/[\r\n]/.test(s)) rl.output.write('•'.repeat(s.length)); else rl.output.write(s);
};
const lines = [];
let waiting = null;
rl.on('line', (l) => { if (waiting) { const w = waiting; waiting = null; w(l); } else lines.push(l); });
function prompt(q) {
  process.stdout.write(q);
  return new Promise((res) => { if (lines.length) { const l = lines.shift(); if (!process.stdin.isTTY) process.stdout.write('\n'); res(l); } else waiting = res; });
}
const isTodo = (v) => !v || /^\[.*\]$/.test(String(v));
async function ask(q, def) {
  const d = isTodo(def) ? '' : def;
  const a = (await prompt(`  ${q}${d ? c.d(` [${d}]`) : ''}: `)).trim();
  return a || d;
}
async function askSecret(q, existing) {
  const hint = existing ? c.d(` [Enter = vorhandenen behalten …${existing.slice(-4)}]`) : c.d(' [Enter = überspringen]');
  muted = process.stdin.isTTY;
  const a = (await prompt(`  ${q}${hint}: `)).trim();
  muted = false;
  if (process.stdin.isTTY) process.stdout.write('\n');
  return a || existing || '';
}
async function yes(q, def = true) {
  const a = (await prompt(`  ${q} ${c.d(def ? '[J/n]' : '[j/N]')}: `)).trim().toLowerCase();
  return a ? a.startsWith('j') || a.startsWith('y') : def;
}

function readEnv() {
  const env = {};
  if (!fs.existsSync(ENV_FILE)) return env;
  for (const line of fs.readFileSync(ENV_FILE, 'utf8').split('\n')) {
    const m = line.match(/^\s*([A-Z0-9_]+)\s*=\s*(.*)\s*$/);
    if (m) env[m[1]] = m[2].replace(/^['"]|['"]$/g, '');
  }
  return env;
}
function writeEnv(env) {
  const order = ['STRIPE_SECRET_KEY', 'STRIPE_WEBHOOK_SECRET', 'SITE_URL', 'RESEND_API_KEY', 'MAIL_FROM', 'SHOP_EMAIL', 'STRIPE_REQUIRE_TOS', 'STRIPE_INVOICE'];
  const keys = [...order.filter((k) => k in env), ...Object.keys(env).filter((k) => !order.includes(k))];
  const body = keys.filter((k) => env[k] !== undefined && env[k] !== '').map((k) => `${k}=${/\s|</.test(env[k]) ? `"${env[k]}"` : env[k]}`).join('\n');
  fs.writeFileSync(ENV_FILE, `# Erzeugt von npm run setup – Inhalt 1:1 in Vercel → Settings → Environment Variables einfügen.\n# NIEMALS committen oder teilen.\n${body}\n`, { mode: 0o600 });
}

async function resend(method, url, key, body) {
  const res = await fetch('https://api.resend.com' + url, {
    method, headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch {}
  if (!res.ok) { const e = new Error((json && (json.message || json.name)) || text || res.statusText); e.status = res.status; throw e; }
  return json;
}

async function sendTestMail(env, cfg) {
  await resend('POST', '/emails', env.RESEND_API_KEY, {
    from: env.MAIL_FROM, to: [env.SHOP_EMAIL],
    subject: `✅ ${cfg.brand.name}: E-Mail-Versand funktioniert`,
    html: `<div style="font-family:Arial,sans-serif"><h2>Läuft! 🔥</h2><p>Bestellbestätigungen und Widerrufsbestätigungen werden ab jetzt von <b>${env.MAIL_FROM.replace(/</g, '&lt;')}</b> verschickt.</p></div>`,
  });
}

// ---------------------------------------------------------------- Ablauf
(async () => {
  const cfg = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  const env = readEnv();

  if (process.argv.includes('--testmail')) {
    if (!env.RESEND_API_KEY || !env.MAIL_FROM || !env.SHOP_EMAIL) { fail('Erst npm run setup ausführen (Resend fehlt).'); process.exit(1); }
    try { await sendTestMail(env, cfg); ok(`Testmail an ${env.SHOP_EMAIL} verschickt – Posteingang (und Spam) prüfen.`); }
    catch (e) { fail('Testmail fehlgeschlagen: ' + e.message); info('Ist die Domain in Resend schon „verified“? DNS kann bis zu ein paar Stunden dauern.'); }
    rl.close(); return;
  }

  console.log('\n' + c.o('🔪 CASPER SHOP – EINRICHTUNG') + c.d('   (Strg+C bricht jederzeit ab, nichts geht kaputt)'));
  console.log(c.d('   Werte in [Klammern] = Vorschlag → einfach Enter drücken.'));

  // ======================================================= 1. Firmendaten
  step('1/4', 'Deine Firmendaten (für Impressum, AGB, E-Mails)');
  const L = cfg.legal;
  L.company = await ask('Shop-/Firmenname', L.company || cfg.brand.name);
  L.owner = await ask('Inhaber (Vor- und Nachname)', L.owner);
  L.street = await ask('Straße und Hausnummer', L.street);
  L.zipCity = await ask('PLZ und Ort', L.zipCity);
  L.phone = await ask('Telefon (Pflicht im Impressum)', L.phone);
  L.email = await ask('Kontakt-E-Mail', L.email);
  const vat = await ask('USt-IdNr. (Enter = keine)', L.vatId);
  L.vatId = vat;
  L.kleinunternehmer = await yes('Kleinunternehmer nach § 19 UStG (keine MwSt.)?', !!L.kleinunternehmer);
  cfg.brand.email = L.email;
  if (L.kleinunternehmer) { cfg.pricing.vatNote = 'gem. § 19 UStG ohne MwSt.'; }
  const missing = ['owner', 'street', 'zipCity', 'phone', 'email'].filter((k) => isTodo(L[k]));
  missing.length ? warn('Noch offen: ' + missing.join(', ') + ' – Impressum ist ohne diese Angaben abmahnbar.') : ok('Firmendaten vollständig');

  // ======================================================= 2. Domain
  step('2/4', 'Deine Domain');
  const curHost = (env.SITE_URL || cfg.brand.siteUrl || '').replace(/^https?:\/\//, '').replace(/\/$/, '');
  const host = (await ask('Domain ohne https:// (z. B. www.casper-messer.de)', curHost)).replace(/^https?:\/\//, '').replace(/\/.*$/, '');
  const siteUrl = host ? 'https://' + host : '';
  if (siteUrl) { env.SITE_URL = siteUrl; cfg.brand.siteUrl = siteUrl; ok('Shop-Adresse: ' + siteUrl); }
  info('Noch keine Domain? Erst bei Vercel deployen, dann hier die ….vercel.app-Adresse eintragen.');

  // ======================================================= 3. Stripe
  step('3/4', 'Stripe (Zahlungen inkl. PayPal & Klarna)');
  info('Schlüssel: dashboard.stripe.com → Entwickler → API-Schlüssel → „Geheimer Schlüssel“');
  const key = await askSecret('Stripe Secret Key (sk_test_… / sk_live_…)', env.STRIPE_SECRET_KEY);
  if (key && !/^(sk|rk)_(test|live)_/.test(key)) {
    fail('Das sieht nicht nach einem Stripe-Secret-Key aus (beginnt mit sk_test_ oder sk_live_). Übersprungen.');
  } else if (key) {
    const live = key.includes('_live_');
    let stripe;
    try {
      stripe = require('stripe')(key);
      const acct = await stripe.accounts.retrieve();
      env.STRIPE_SECRET_KEY = key;
      ok(`Verbunden: ${acct.settings?.dashboard?.display_name || acct.business_profile?.name || acct.email || acct.id} (${acct.country}) – ${live ? c.g('LIVE-Modus') : c.y('Test-Modus')}`);
      if (live && !acct.charges_enabled) warn('Konto kann noch keine Zahlungen annehmen → im Stripe-Dashboard die Verifizierung abschließen.');
      if (!live) info('Test-Modus: Bezahlen mit Karte 4242 4242 4242 4242. Für den Start später mit sk_live_… erneut ausführen.');
    } catch (e) {
      fail('Stripe-Schlüssel funktioniert nicht: ' + e.message);
      stripe = null;
    }

    if (stripe) {
      // --- Zahlarten
      try {
        const list = await stripe.paymentMethodConfigurations.list({ limit: 20 });
        const pmc = list.data.find((p) => p.is_default && !p.parent) || list.data.find((p) => p.is_default) || list.data[0];
        if (pmc) {
          const names = { card: 'Karte', paypal: 'PayPal', klarna: 'Klarna', apple_pay: 'Apple Pay', google_pay: 'Google Pay' };
          const off = [];
          for (const [k, label] of Object.entries(names)) {
            const m = pmc[k];
            if (!m) { warn(`${label}: nicht verfügbar für dein Konto`); continue; }
            if (m.display_preference?.value === 'on') ok(`${label}: aktiv`);
            else if (m.available) { warn(`${label}: aus`); off.push(k); }
            else warn(`${label}: noch nicht freigeschaltet`);
          }
          if (off.length && await yes(`${off.map((k) => names[k]).join(', ')} jetzt einschalten?`)) {
            const upd = {};
            off.forEach((k) => { upd[k] = { display_preference: { preference: 'on' } }; });
            await stripe.paymentMethodConfigurations.update(pmc.id, upd);
            ok('Eingeschaltet');
          }
          if (!pmc.paypal || pmc.paypal.display_preference?.value !== 'on') {
            info('PayPal einmalig verknüpfen: dashboard.stripe.com/settings/payment_methods → PayPal → mit PayPal-Geschäftskonto verbinden.');
          }
        }
      } catch (e) {
        warn('Zahlarten konnten nicht gelesen werden (' + e.message + ') – bitte im Dashboard prüfen: dashboard.stripe.com/settings/payment_methods');
      }

      // --- Webhook
      if (siteUrl && !/localhost|127\.0\.0\.1/.test(siteUrl)) {
        const url = siteUrl + '/api/stripe-webhook';
        try {
          const eps = await stripe.webhookEndpoints.list({ limit: 100 });
          const existing = eps.data.find((w) => w.url === url);
          let create = !existing;
          if (existing) {
            if (env.STRIPE_WEBHOOK_SECRET && !(await yes(`Webhook für ${url} existiert schon. Neu anlegen (alter wird ersetzt)?`, false))) {
              ok('Vorhandenen Webhook behalten');
            } else {
              await stripe.webhookEndpoints.del(existing.id);
              create = true;
            }
          }
          if (create) {
            const ep = await stripe.webhookEndpoints.create({ url, enabled_events: WEBHOOK_EVENTS, description: `${cfg.brand.name} Shop – Bestellbestätigungen` });
            env.STRIPE_WEBHOOK_SECRET = ep.secret;
            ok('Webhook angelegt → ' + url);
          }
        } catch (e) {
          fail('Webhook konnte nicht angelegt werden: ' + e.message);
        }
      } else {
        warn('Webhook übersprungen – braucht eine echte https-Domain (Schritt 2).');
      }
    }
  } else {
    warn('Stripe übersprungen – Shop läuft im Demo-Modus (kein Bezahlen möglich).');
  }

  // ======================================================= 4. E-Mail
  step('4/4', 'E-Mail-Versand (Bestellbestätigung, Widerruf)');
  info('Kostenloses Konto: resend.com → API Keys → „Create API Key“ (Full access)');
  const rkey = await askSecret('Resend API-Key (re_…)', env.RESEND_API_KEY);
  const mailDomain = host.replace(/^www\./, '');
  let verified = false;
  if (rkey) {
    env.RESEND_API_KEY = rkey;
    env.MAIL_FROM = await ask('Absender', env.MAIL_FROM || `${L.company} <bestellung@${mailDomain || 'deine-domain.de'}>`);
    env.SHOP_EMAIL = await ask('Bestell-Benachrichtigungen an', env.SHOP_EMAIL || L.email);
    const fromDomain = (env.MAIL_FROM.match(/@([^>\s]+)/) || [])[1];
    if (fromDomain) {
      try {
        const list = await resend('GET', '/domains', rkey);
        let dom = (list.data || []).find((d) => d.name === fromDomain);
        if (!dom) {
          dom = await resend('POST', '/domains', rkey, { name: fromDomain, region: 'eu-west-1' });
          ok(`Mail-Domain ${fromDomain} in Resend angelegt (EU-Server)`);
        } else {
          dom = await resend('GET', '/domains/' + dom.id, rkey);
        }
        verified = dom.status === 'verified';
        if (verified) {
          ok(`Domain ${fromDomain} ist verifiziert`);
        } else {
          warn(`Domain ${fromDomain} noch nicht verifiziert. Trag diese DNS-Einträge bei deinem Domain-Anbieter ein:`);
          console.log('');
          for (const r of dom.records || []) {
            console.log(`     ${c.b(r.type.padEnd(5))} Name: ${c.o(r.name)}${r.priority ? `   Priorität: ${r.priority}` : ''}`);
            console.log(`           Wert: ${r.value}\n`);
          }
          info('Danach (DNS braucht 5 Min. bis ein paar Stunden): npm run setup -- --testmail');
          try { await resend('POST', `/domains/${dom.id}/verify`, rkey); } catch {}
        }
      } catch (e) {
        if (e.status === 401 || e.status === 403) warn('Der Key darf nur senden – Domain bitte selbst anlegen: resend.com/domains (dann DNS-Einträge eintragen).');
        else fail('Resend-Fehler: ' + e.message);
      }
    }
    if (verified) {
      try { await sendTestMail(env, cfg); ok(`Testmail an ${env.SHOP_EMAIL} verschickt`); }
      catch (e) { fail('Testmail fehlgeschlagen: ' + e.message); }
    }
  } else {
    warn('E-Mail übersprungen – ohne Mailversand gibt es keine Bestellbestätigung und der Widerrufsbutton verweist nur auf deine E-Mail.');
  }

  // ======================================================= Speichern
  writeEnv(env);
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2) + '\n');
  console.log('\n' + c.o('━━ FERTIG ━━'));
  ok('Gespeichert: .env (geheim, wird nicht committet) und shop.config.json');
  console.log(`
  ${c.b('Nächste Schritte:')}
   1. Vercel → dein Projekt → Settings → Environment Variables
      → kompletten Inhalt der Datei ${c.o('.env')} hineinkopieren (geht auf einmal) → Save → Redeploy
   2. ${c.o('npm run check:launch')} zeigt dir, was vor dem Start noch fehlt
`);
  rl.close();
})().catch((e) => { console.error(c.r('\n✗ ' + e.message)); rl.close(); process.exit(1); });
