#!/usr/bin/env node
// Unattended demo driver over CDP. Enables demo mode + selects a set via
// localStorage (cold start), opens a fresh chat, fires the trigger, then walks
// the beats — resuming at each pause — capturing a disk screenshot + the mounted
// message text at every step. This is the workhorse the autopilot critique uses
// instead of claude-in-chrome: Playwright scrolls the react-virtuoso list
// deterministically (scrollIntoView on the newest node), so the blank-frame
// scroll-follow behavior can't hide content from verification.
//
// Env: SET_ID (required), TRIGGER (required), RESUMES (comma-sep phrases, one per
// pause after the first beat), OUT_DIR (screenshot dir), APP_URL, CDP_URL.
const path = require('path')
const PW = path.join(require('os').homedir(), '.chrome-cdp-profiles/.pw/node_modules/playwright-core')
const { chromium } = require(PW)
const fs = require('fs')

const APP = process.env.APP_URL || 'http://localhost:4203'
const CDP = process.env.CDP_URL || 'http://localhost:9222'
const SET_ID = process.env.SET_ID
const TRIGGER = process.env.TRIGGER
const RESUMES = (process.env.RESUMES || '').split('|').map((s) => s.trim()).filter(Boolean)
const OUT = process.env.OUT_DIR || '/tmp/neo-demo-drive'

if (!SET_ID || !TRIGGER) {
  console.error('SET_ID and TRIGGER are required')
  process.exit(2)
}
fs.mkdirSync(OUT, { recursive: true })

async function scrollToNewest(page) {
  // Set every scrollable container to its bottom — robust to react-virtuoso.
  await page.evaluate(() => {
    const scrollables = [...document.querySelectorAll('*')].filter((e) => {
      const s = getComputedStyle(e)
      return e.scrollHeight > e.clientHeight + 40 && /auto|scroll/.test(s.overflowY)
    })
    scrollables.sort((a, b) => b.scrollHeight - a.scrollHeight)
    for (const el of scrollables.slice(0, 3)) el.scrollTop = el.scrollHeight
    window.scrollTo(0, document.body.scrollHeight)
  })
}

async function messageText(page) {
  return (await page.evaluate(() => document.body.innerText))
    .replace(/\s+/g, ' ')
    .trim()
}

// Deterministic layout probe: flags content overflow / text clipping / page
// horizontal-scroll — the objective half of the design tier (no model taste).
async function probeLayout(page) {
  return await page.evaluate(() => {
    const out = []
    const seen = new Set()
    for (const e of document.querySelectorAll('body *')) {
      const cs = getComputedStyle(e)
      const txt = (e.textContent || '').trim()
      const overflowsX = e.scrollWidth > e.clientWidth + 2
      const clipsX = /hidden|clip|auto|scroll/.test(cs.overflowX)
      if (overflowsX && clipsX && txt && e.clientWidth > 60) {
        const key = e.tagName + txt.slice(0, 24)
        if (!seen.has(key)) {
          seen.add(key)
          out.push({ kind: 'overflow-x', tag: e.tagName, clientW: e.clientWidth, scrollW: e.scrollWidth, text: txt.slice(0, 60) })
        }
      }
      if (cs.textOverflow === 'ellipsis' && overflowsX && txt) {
        out.push({ kind: 'text-clip', tag: e.tagName, text: txt.slice(0, 60) })
      }
    }
    if (document.documentElement.scrollWidth > window.innerWidth + 2) {
      out.push({ kind: 'page-overflow-x', scrollW: document.documentElement.scrollWidth, vw: window.innerWidth })
    }
    return out.slice(0, 60)
  })
}

// Zoomed per-element screenshots (card-like containers) — the evidence the
// Layer-2 design-critique subagent judges, at real render width.
async function captureElements(page, prefix) {
  const handle = await page.evaluateHandle(() => {
    const cards = []
    for (const e of document.querySelectorAll('body *')) {
      const cs = getComputedStyle(e)
      const r = e.getBoundingClientRect()
      const cardish = parseFloat(cs.borderRadius) >= 8 || cs.boxShadow !== 'none'
      if (cardish && r.width > 320 && r.height > 70 && r.height < 1500 && (e.textContent || '').trim().length > 20) {
        cards.push(e)
      }
    }
    return cards.filter((c) => !cards.some((o) => o !== c && o.contains(c)))
  })
  const props = await handle.getProperties()
  const shots = []
  let i = 0
  for (const [, h] of props) {
    const el = h.asElement()
    if (!el) continue
    i++
    const p = `${OUT}/${prefix}-el-${i}.png`
    await el.screenshot({ path: p }).catch(() => {})
    shots.push(p)
  }
  return shots
}

async function send(page, text) {
  const input = page
    .getByPlaceholder(/Ask Neo|Reply to Neo/i)
    .or(page.locator('textarea'))
    .first()
  await input.click()
  await input.fill(text)
  await input.press('Enter')
}

async function settle(page, maxMs) {
  // Wait until the streamed content stops changing (beat finished) or maxMs.
  // Robust to the slow char-stream: resume only once the beat has fully landed.
  const end = Date.now() + maxMs
  let last = ''
  let stableSince = Date.now()
  while (Date.now() < end) {
    await page.waitForTimeout(2000)
    await scrollToNewest(page)
    const t = await messageText(page)
    if (t === last) {
      if (Date.now() - stableSince > 4500) return
    } else {
      last = t
      stableSince = Date.now()
    }
  }
}

;(async () => {
  const browser = await chromium.connectOverCDP(CDP)
  const ctx = browser.contexts()[0]
  const page = ctx.pages().find((p) => p.url().includes('4203')) || (await ctx.newPage())
  await page.bringToFront()

  // Cold start: demo mode on, set active, wipe prior sessions/approvals.
  await page.goto(APP + '/', { waitUntil: 'domcontentloaded' })
  await page.evaluate((setId) => {
    localStorage.setItem('neo_demo_mode_enabled', 'true')
    localStorage.setItem('neo_demo_active_set_id', setId)
    localStorage.removeItem('neo_demo_sessions')
    localStorage.removeItem('neo_demo_approval_resolutions')
  }, SET_ID)

  const netPosts = []
  page.on('request', (r) => {
    if (r.method() === 'POST' && /web-chat-init|\/neo\//.test(r.url())) netPosts.push(r.url())
  })

  await page.goto(APP + '/chat?newChat=1', { waitUntil: 'domcontentloaded' })
  await page.waitForTimeout(2500)
  if (/\/login/.test(page.url())) {
    console.log('STATE: LOGGED_OUT — bot profile needs one re-login. Aborting.')
    await browser.close()
    process.exit(3)
  }

  const AFFIRM = process.env.AFFIRM || 'yes, continue'
  const MAX = parseInt(process.env.MAX_STEPS || '9', 10)

  async function capture(label, note) {
    await scrollToNewest(page)
    const shot = `${OUT}/${label}.png`
    await page.screenshot({ path: shot, fullPage: true })
    const txt = await messageText(page)
    fs.writeFileSync(`${OUT}/${label}.txt`, txt)
    const layout = await probeLayout(page)
    fs.writeFileSync(`${OUT}/${label}.layout.json`, JSON.stringify(layout, null, 2))
    const els = await captureElements(page, label)
    console.log(`--- ${label} (${note}) -> ${shot}  [${els.length} element frames]`)
    if (layout.length) {
      console.log(`  ⚠ LAYOUT FLAGS (${layout.length}): ` + layout.slice(0, 6).map((f) => `${f.kind}:"${(f.text || '').slice(0, 28)}"`).join(' | '))
    }
    console.log(txt.slice(-500))
    console.log('')
  }
  async function firstApprove() {
    // react-virtuoso unmounts off-screen rows, so an approval above the
    // scrolled-to-bottom closer can vanish from the DOM. Scroll up in steps to
    // re-mount it before giving up, and scroll it into view before returning.
    for (let s = 0; s < 6; s++) {
      const b = page
        .getByRole('button', { name: /^(Approve( once)?|Use this file)$/i })
        .first()
      if ((await b.count()) > 0 && (await b.isVisible().catch(() => false))) {
        await b.scrollIntoViewIfNeeded().catch(() => {})
        return b
      }
      await page.evaluate(() => {
        const sc = [...document.querySelectorAll('*')]
          .filter((e) => {
            const cs = getComputedStyle(e)
            return e.scrollHeight > e.clientHeight + 40 && /auto|scroll/.test(cs.overflowY)
          })
          .sort((a, b) => b.scrollHeight - a.scrollHeight)[0]
        if (sc) sc.scrollTop = Math.max(0, sc.scrollTop - 550)
      })
      await page.waitForTimeout(600)
    }
    return null
  }

  // Beat 1 (the trigger). Then auto-advance: click Approve at approval gates,
  // else send an affirmative at user-prompt gates. Stop at the first backend
  // POST — that's the script ending (expected) or a mid-script fall-through (bug).
  await send(page, TRIGGER)
  await settle(page, 95000)
  await capture('step-1', 'trigger')

  for (let step = 2; step <= MAX; step++) {
    const before = netPosts.length
    const appr = await firstApprove()
    const action = appr ? 'approve' : 'prompt'
    if (appr) {
      await appr.click().catch(() => {})
    } else {
      await send(page, AFFIRM)
    }
    await settle(page, 95000)
    await capture(`step-${step}`, action)
    if (netPosts.length > before) {
      console.log(`STEP ${step}: backend POST after "${action}" — end-of-script / fall-through here.`)
      break
    }
  }

  console.log('BACKEND_CHAT_POSTS:', netPosts.length, netPosts.slice(0, 5).join(' '))
  await browser.close()
  process.exit(0)
})().catch((e) => {
  console.error('ERR:', e.message)
  process.exit(1)
})
