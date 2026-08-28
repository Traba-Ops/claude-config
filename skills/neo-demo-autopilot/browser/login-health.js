#!/usr/bin/env node
// Login-health probe for the persistent CDP bot Chrome.
// Attaches to the bot Chrome on :9222, loads the app, and reports whether the
// bot profile is past the /login wall. Exit 0 = LOGGED_IN, 3 = LOGGED_OUT,
// 1 = error (can't attach / server down). Used by the autopilot browser preflight.
const path = require('path')
const PW = path.join(require('os').homedir(), '.chrome-cdp-profiles/.pw/node_modules/playwright-core')
const { chromium } = require(PW)

const APP = process.env.APP_URL || 'http://localhost:4203'
const APP_HOST = new URL(APP).host // e.g. localhost:4203 — used to find the app tab
const CDP = process.env.CDP_URL || 'http://localhost:9222'

;(async () => {
  const browser = await chromium.connectOverCDP(CDP)
  const ctx = browser.contexts()[0]
  const page =
    ctx.pages().find((p) => p.url().includes(APP_HOST)) ||
    ctx.pages()[0] ||
    (await ctx.newPage())
  await page.bringToFront()
  await page.goto(APP + '/', { waitUntil: 'domcontentloaded' })
  await page.waitForTimeout(3500)
  const url = page.url()
  const body = (await page.evaluate(() => document.body.innerText.slice(0, 400)))
    .replace(/\s+/g, ' ')
    .trim()
  const loggedOut = /\/login/.test(url) || /\bLog in\b|\bSign up\b/.test(body)
  console.log('URL:', url)
  console.log('STATE:', loggedOut ? 'LOGGED_OUT' : 'LOGGED_IN')
  console.log('PROBE:', body.slice(0, 160))
  // Don't browser.close() — over CDP that tears down the persistent bot Chrome.
  // Exiting drops the CDP socket and leaves the logged-in Chrome running for reuse.
  process.exit(loggedOut ? 3 : 0)
})().catch((e) => {
  console.error('ERR:', e.message)
  process.exit(1)
})
