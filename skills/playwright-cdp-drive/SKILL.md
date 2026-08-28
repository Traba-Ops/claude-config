---
name: playwright-cdp-drive
description: |
  Drive the user's ALREADY-LOGGED-IN Chrome programmatically via Playwright over CDP —
  for the things claude-in-chrome can't do well: real file UPLOADS into web forms/dropzones,
  screenshots saved to DISK (as files you can reuse/attach), downloads, and scripted/batch DOM
  automation against authenticated sessions (SSO + passkey sites). Use when a task needs to
  upload files to a site, capture a page as a real image/PDF on disk, or repeat a browser action
  many times reliably, and the site requires the user's existing login. On macOS.
version: 1.0.0
---

# Playwright-over-CDP: drive the user's logged-in Chrome

## When to use this (vs. claude-in-chrome)
claude-in-chrome is great for *interactive* browsing of the user's real Chrome, but it **can't
save screenshots to disk** and its **file upload is unreliable/broken**. Reach for THIS skill when:
- You must **upload file(s)** into a web dropzone / `<input type=file>` (the hard case).
- You need a screenshot or PDF **written to a real file** (to reuse, attach, or diff).
- You're doing the **same browser action many times** and want a deterministic script.
- The site needs the user's **existing SSO/passkey session** — so a fresh Playwright browser
  (which starts logged out and can't script passkeys) is a non-starter.

If you only need to click around / read a page once, just use claude-in-chrome — don't set this up.

## The core idea
Never let Playwright *launch* Chrome at the user's real profile (see gotchas — it silently kills
their sessions on macOS). Instead: the user's **real Chrome.app** launches with a debug port and a
**dedicated bot profile**; the user logs in **once**; Playwright **attaches** over CDP and reuses
that live session. Then `setInputFiles` and `screenshot({path})` just work.

## Setup (one-time per machine, then reused)
1. Launch the bot Chrome (own profile, own debug port — runs alongside the user's normal Chrome):
   ```bash
   # the launcher sits next to this SKILL.md — run it from the skill's own directory:
   bash launch-chrome-cdp.sh <profile-name> [start-url]
   # e.g. bash launch-chrome-cdp.sh soc2 https://app.example.com
   ```
   It verifies `http://localhost:9222/json/version` responds.
2. **Ask the user to log into the target site(s) in that new Chrome window** (SSO + passkey). This
   is the ONE human step; the session then persists in the bot profile for future runs.
3. Ensure `playwright-core` is available: `cd <workdir> && npm i playwright-core` (no browser
   download needed — we attach to existing Chrome).

## Connect + drive
```js
const { chromium } = require('playwright-core');
const browser = await chromium.connectOverCDP('http://localhost:9222');
const ctx = browser.contexts()[0];
// pick the tab you want by URL substring (or ctx.newPage())
const page = ctx.pages().find(p => p.url().includes('/your/path')) || await ctx.newPage();
await page.bringToFront();
```

### Upload files (the main event)
Works even when the real `<input type=file>` is hidden behind a styled dropzone or opens in a modal.
```js
// If the input only appears after a click (paperclip / "Attach" / modal), trigger it first.
// The uploader button is often an icon with no text — e.g. "the button right before Send":
await page.evaluate(() => {
  const btns=[...document.querySelectorAll('button')];
  const anchor=btns.find(b=>b.innerText.trim()==='Send');       // adapt anchor per site
  const opener=btns[btns.indexOf(anchor)-1];
  ['pointerdown','mousedown','pointerup','mouseup','click'].forEach(t=>
    opener.dispatchEvent(new PointerEvent(t,{bubbles:true,cancelable:true,view:window,button:0})));
});
const input = await page.waitForSelector('input[type=file]', { state:'attached', timeout:8000 });
await input.setInputFiles(['/abs/a.pdf','/abs/b.png']);          // hidden inputs are fine
// MANY dropzones need a confirm step to COMMIT the files — click it or the files never attach:
await page.getByRole('button', { name: 'Add File' }).click().catch(()=>{});  // adapt label
await page.waitForTimeout(2000);
// then fill any message field + click the submit/Send button
```
Alternative when a visible "Browse" button spawns the input:
```js
const [chooser] = await Promise.all([ page.waitForEvent('filechooser'),
                                      page.getByText('Upload').click() ]);
await chooser.setFiles('/abs/file.pdf');
```

### Screenshot / PDF to disk
```js
await page.screenshot({ path: '/abs/out.png', fullPage: true });   // real file, reusable
// NB: page.pdf() is headless-Chromium only — it does NOT work in this headful CDP attach.
// For a PDF, use the site's own export/print, or screenshot then convert.
```
Read the PNG back to verify state before any irreversible click (Send/Submit). Stage first,
verify the screenshot, THEN submit — especially for outward-facing actions.

## macOS gotchas (each of these will silently waste an hour)
- **Chrome 136+ ignores `--remote-debugging-port` on the DEFAULT user-data-dir.** You MUST pass a
  non-default `--user-data-dir` (the launch script does). Otherwise port 9222 never opens.
- **Never `chromium.launch()/launchPersistentContext()` at the real profile.** Playwright injects
  `--use-mock-keychain`, which decrypts the real macOS-keychain cookies to garbage → the user looks
  logged out, no error. Only `connectOverCDP` to a user-launched real Chrome preserves sessions.
- **`waitUntil:'networkidle'` never settles** on apps with live connections (websockets/polling).
  Use `'domcontentloaded'` + `waitForSelector` on a known element.
- **One CDP debugger client per target.** Don't point this at a tab claude-in-chrome is driving;
  keep the bot profile separate (different `--user-data-dir`) so they don't fight over the target
  or the `SingletonLock`.
- **Fully quit any Chrome using that profile dir before launching** (SingletonLock). The bot
  profile is separate from the daily profile, so normally no conflict.
- **CDP on :9222 is unauthenticated full browser control = live credentials.** Keep it loopback,
  short-lived, and use a dedicated bot profile with only the sessions you need. Kill Chrome when done.

## Cleanup
```bash
pkill -f 'remote-debugging-port=9222'   # stop the bot Chrome when finished
```
The bot profile at `~/.chrome-cdp-profiles/<name>` persists the login for next time — leave it
unless you want to force re-auth.
