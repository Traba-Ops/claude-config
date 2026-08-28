// Template: attach to the user's logged-in Chrome over CDP and do the hard things.
// Copy this, adapt the ADAPT-marked bits, run with: node drive.js
// Requires: npm i playwright-core  (in the working dir). Chrome launched via launch-chrome-cdp.sh.
const { chromium } = require('playwright-core');

const PORT = process.env.CDP_PORT || 9222;
const PAGE_MATCH = process.env.PAGE_MATCH || '/';   // ADAPT: URL substring of the target tab
const SEND = process.env.SEND === '1';              // gate irreversible submit behind a flag

async function findPage(ctx) {
  return ctx.pages().find(p => p.url().includes(PAGE_MATCH)) || (await ctx.newPage());
}

// Reveal a hidden file input by clicking the uploader control, then set files, then commit.
async function uploadFiles(page, { openerText, confirmText, files }) {
  if (openerText) {
    // ADAPT: default finds the icon button immediately before a text button named `openerText`
    await page.evaluate((anchorText) => {
      const btns = [...document.querySelectorAll('button')];
      const anchor = btns.find(b => b.innerText.trim() === anchorText);
      const opener = btns[btns.indexOf(anchor) - 1];
      ['pointerdown','mousedown','pointerup','mouseup','click'].forEach(t =>
        opener.dispatchEvent(new PointerEvent(t, {bubbles:true, cancelable:true, view:window, button:0})));
    }, openerText);
  }
  const input = await page.waitForSelector('input[type=file]', { state: 'attached', timeout: 8000 });
  await input.setInputFiles(files);
  if (confirmText) await page.getByRole('button', { name: confirmText }).click().catch(() => {});
  await page.waitForTimeout(2000);
}

(async () => {
  const browser = await chromium.connectOverCDP(`http://localhost:${PORT}`);
  const ctx = browser.contexts()[0];
  const page = await findPage(ctx);
  await page.bringToFront();
  await page.reload({ waitUntil: 'domcontentloaded' });          // NOT networkidle
  // ADAPT: wait for a known element on your page:
  // await page.waitForSelector('YOUR_SELECTOR', { timeout: 15000 });

  // ---- EXAMPLE: upload files + fill a message + submit (staged behind SEND) ----
  // await uploadFiles(page, { openerText: 'Send', confirmText: 'Add File',
  //                           files: ['/abs/a.pdf', '/abs/b.pdf'] });
  // await page.fill('YOUR_MESSAGE_SELECTOR', 'your text');

  // Always screenshot-to-disk and verify BEFORE any irreversible click:
  await page.screenshot({ path: '/tmp/cdp_staged.png', fullPage: true });
  console.log('staged screenshot -> /tmp/cdp_staged.png');

  if (SEND) {
    // await page.getByRole('button', { name: 'Send' }).click();
    // await page.waitForTimeout(2500);
    // await page.screenshot({ path: '/tmp/cdp_sent.png', fullPage: true });
    console.log('SEND path — wire up your submit click.');
  }
  await browser.close();
})().catch(e => { console.error('ERR', e.message); process.exit(1); });
