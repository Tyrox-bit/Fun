// Erzeugt PNGs aus den SVGs: og.png (Link-Vorschau 1200×630) und product.png (Stripe-Checkout 1000×1000).
// Braucht Playwright: npm i -D playwright && npx playwright install chromium
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const IMG = path.join(__dirname, '..', 'assets', 'img');
const FONTS = path.join(__dirname, '..', 'assets', 'fonts');
const fileUrl = (p) => 'file://' + p;

const OG = `<!doctype html><html><head><style>
@font-face{font-family:Anton;src:url('${fileUrl(FONTS + '/anton-latin-400-normal.woff2')}')}
@font-face{font-family:Inter;src:url('${fileUrl(FONTS + '/inter-latin-800-normal.woff2')}');font-weight:800}
*{margin:0;box-sizing:border-box}
body{width:1200px;height:630px;background:#0a0a0b;color:#fff;font-family:Inter;overflow:hidden;position:relative}
.tex{position:absolute;inset:0;background:url('${fileUrl(IMG + '/damascus.svg')}') center/cover;opacity:.18}
.glow{position:absolute;inset:0;background:radial-gradient(circle at 75% 50%,rgba(255,122,26,.35),transparent 55%)}
.knives{position:absolute;right:-40px;top:-30px;width:690px}
.copy{position:absolute;left:70px;top:90px;width:560px}
.tag{display:inline-block;background:#ff3d3d;padding:10px 20px;border-radius:99px;font-weight:800;font-size:26px;letter-spacing:.06em}
h1{font-family:Anton;font-weight:400;font-size:104px;line-height:.95;text-transform:uppercase;margin:26px 0 18px}
h1 span{color:#ff7a1a}
.price{font-family:Anton;font-size:64px}.price s{font-family:Inter;font-size:34px;color:#a8a29e;margin-left:14px}
.logo{position:absolute;left:70px;bottom:50px;font-family:Anton;font-size:34px;letter-spacing:8px;color:#d6d3d1}
</style></head><body><div class="tex"></div><div class="glow"></div>
<img class="knives" src="${fileUrl(IMG + '/hero.svg')}">
<div class="copy"><span class="tag">BLACK FRIDAY · −50 %</span><h1>Damast<br><span>Duo</span></h1>
<div class="price">99 € <s>199 €</s></div></div><div class="logo">CASPER</div></body></html>`;

const PRODUCT = `<!doctype html><html><head><style>
*{margin:0}body{width:1000px;height:1000px;background:radial-gradient(circle at 55% 45%,#2a241f,#0b0b0c 70%);overflow:hidden}
img{width:1000px;height:1000px}</style></head><body><img src="${fileUrl(IMG + '/hero.svg')}"></body></html>`;

(async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
  const tmp = path.join(IMG, '_render.html');
  const render = async (html) => { fs.writeFileSync(tmp, html); await page.goto(fileUrl(tmp), { waitUntil: 'load' }); };
  await render(OG);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: path.join(IMG, 'og.png') });

  await page.setViewportSize({ width: 1000, height: 1000 });
  await render(PRODUCT);
  await page.screenshot({ path: path.join(IMG, 'product.png') });
  await browser.close();
  fs.unlinkSync(tmp);
  console.log('PNGs erzeugt: og.png, product.png');
})();
