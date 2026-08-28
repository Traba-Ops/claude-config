---
name: offer-letter
description: |
  Generates a Labor That Works offer letter PDF, uploads to Google Drive, notifies the hiring manager
  via Slack DM + Gmail draft, and drafts a candidate-facing offer email (looked up via Ashby).
  Asks for candidate details conversationally, generates PDF via Chrome headless,
  uploads to Google Drive, and creates two Gmail drafts: one for the HM and one for the candidate.
version: 1.0.0
---

# Offer Letter Skill

When this skill is invoked, follow these steps exactly. Do not show code or JSON to the user — keep it conversational.

> **Setup required:** The `offer-letter` repo must be cloned to `~/workspace/offer-letter/`. Clone it from `Traba-Ops/offer-letter` if you haven't already.

---

## Step 1: Collect Inputs Conversationally

Ask for the required fields first in one message:

> "Quick offer letter. I need four things: **candidate's full name**, **market city**, **state** (2-letter code, e.g. TX, FL, NV), and **hourly rate**."
>
> The state determines which benefits region (and premium rates) appear in the letter. If the user doesn't know the state, ask — don't guess from the city.

Once you have those three, ask for the optional fields in one follow-up message:

> "Got it. A few optional fields — just hit enter to skip any:
> - Role title (default: Field Operator)
> - Start date
> - Offer expiry date
> - Hiring manager name, title, email
> - Recruit bonus (default: $100), onboard bonus (default: $25)"

Do NOT ask where to send — send to the currently logged-in user's email (check `git config user.email` or ask once at setup).

---

## Step 2: Generate the PDF

Build a JSON object from the inputs:

```
{
  "name": "<full name>",
  "city": "<city>",
  "state": "<2-letter state code, e.g. TX, FL, NV>",
  "pay": "<rate>",
  "role": "<role or 'Field Operator'>",
  "startDate": "<start date or ''>",
  "expiry": "<expiry or ''>",
  "hmName": "<HM name or ''>",
  "hmTitle": "<HM title or ''>",
  "hmEmail": "<HM email or ''>",
  "recruitBonus": "<bonus or '100'>",
  "onboardBonus": "<bonus or '25'>"
}
```

Run:
```
node ~/workspace/offer-letter/generate.js '<json string>'
```

The script outputs JSON: `{ html, pdf, name, role, city, state, region, enrollmentKit }`. Capture the `pdf` path. The `enrollmentKit` object (if present) contains `{ region, en, es }` with Drive URLs for the English and Spanish enrollment kit PDFs.

---

## Step 3: Upload to Google Drive

**Use the HTML file, not the PDF.** The PDF is ~200KB which encodes to ~280KB base64 — too large for the Drive MCP's upload path. The HTML file is ~8KB, renders identically in any browser, and prints to PDF in one click.

Read the HTML file content using the Read tool (it will be under `~/workspace/offer-letter/output/`).

Upload using the Google Drive MCP tool `mcp__claude_ai_Google_Drive__create_file`:
- `title`: `"Offer Letter – <name> – <city> – <today's date>.html"`
- `textContent`: the full HTML file content
- `contentMimeType`: `"text/html"`
- `disableConversionToGoogleType`: `true`

The response will include a file ID and `viewUrl`. Use the `viewUrl` directly.

After upload, automatically open the Drive link in the user's browser:
```
open "<viewUrl>"
```

**To send a true PDF instead:** the user can run `gcloud auth application-default login --scopes=https://www.googleapis.com/auth/drive` to get Drive-scoped credentials, then use `node ~/workspace/offer-letter/upload-drive.js <pdf-path> <title>` which uploads via curl with the gcloud token.

---

## Step 4: Send Slack DM to Hiring Manager

After opening the Drive link, draft a Slack DM to the hiring manager that includes ALL offer details so they can see everything without opening the doc:

- Candidate name
- Role, market (city, state), hourly rate
- Start date, offer expiry
- Incentive bonuses (recruit bonus + onboard bonus — see "default bonus structure" below)
- Drive link + enrollment kit links (EN + ES)
- Instructions: "To share with the candidate, open the Drive link and click Share. Print → Save as PDF if they need a hard copy."

**Show the full draft message to the user and ask for approval before sending.** Only send via `mcp__claude_ai_Slack__slack_send_message` after explicit "yes" / "send it" / equivalent.

Use `mcp__claude_ai_Slack__slack_search_users` to find the HM's Slack user ID, then DM them using their user_id as the channel_id.

---

## Step 5: Send via Gmail Draft

Use the Gmail MCP tool `mcp__claude_ai_Gmail__create_draft` to create a draft to the hiring manager's email:

- **subject**: `Offer Letter – <name> – <role>, <city>`
- **htmlBody**:
```
<p>Hi [HM name],</p>
<p>Offer letter for <strong><name></strong> (<role>, <city>) is ready:</p>
<p><a href="<Drive URL>">View Offer Letter on Drive</a></p>
<p><a href="<enrollmentKit.en URL>">Benefits Enrollment Kit (English)</a> | <a href="<enrollmentKit.es URL>">Enrollment Kit (Spanish)</a></p>
<p><em>To share with the candidate, open the links and click Share in Drive. To get a PDF, open in Chrome and Print → Save as PDF.</em></p>
```

After creating the draft, tell the user to check Gmail and hit Send (the Gmail MCP can only create drafts, not send directly). Gmail MCP does not support attachments — the draft will contain the Drive link only. To attach the actual PDF, the user must open the draft and attach it manually from `~/workspace/offer-letter/output/`.

---

## Step 6: Draft Candidate Offer Email

After the HM draft, create a **second Gmail draft** — this one goes directly to the candidate for them to review and sign the offer letter.

### 6a: Look up candidate email in Ashby

Use the Ashby API to find the candidate's personal email:
```
curl -s -u "$ASHBY_API_KEY:" https://api.ashbyhq.com/candidate.search \
  -H 'Content-Type: application/json' \
  -d '{"name": "<candidate full name>"}'
```
Extract the email from `results[0].primaryEmailAddress.value`. If Ashby returns no results or no email, ask the user for the candidate's email address.

**Gotcha:** The search parameter is `"name"`, NOT `"term"`.

### 6b: Search Gmail for tone calibration

Search for recent sent offer letter emails to match the user's exact tone:
```
query: "subject:(offer letter) from:me newer_than:3m"
```
Pull full text of 2-3 recent sent emails. The established template pattern is:

```
Hey <FirstName>,

Congratulations! We are excited to share your official offer to join Traba as a <Role>. We truly believe you will make a real impact on our team and the associates we serve.

Please find your official offer letter attached for your review. We'd love to hear back with your signature by <Day of week of expiry>. In the meantime, don't hesitate to reach out with any other questions.

I've CC'd <Manager first name> on this email. I will support your training, and then <Manager first name> will be your effective manager thereafter.

Also some good news: the offer is at $<rate>/hr (plus the bonus structure articulated in the letter). We're excited to begin working together soon. Congrats again!

Warm regards,
Elijah
```

**Always re-read recent sent emails** rather than relying on this template alone — the user may have evolved their phrasing. Use the most recent emails as the ground truth.

### 6c: Create the Gmail draft

Use `mcp__claude_ai_Gmail__create_draft`:
- **to**: candidate's personal email (from Ashby)
- **cc**: hiring manager's email (from offer letter inputs — `hmEmail`) AND `mdispirito@traba.work` (always)
- **bcc**: `aarimany@traba.work` (always)
- **subject**: `New Traba Offer Letter`
- **body**: the email text from 6b, filled in with candidate details

**Show the full draft text to the user for review before creating the draft.** Wait for approval or edits. The user may want to adjust CC recipients, the manager line, or other details.

After creating the draft, remind the user:
- Manually attach the PDF from `~/workspace/offer-letter/output/` (Gmail MCP doesn't support attachments)
- Review and hit Send in Gmail

### 6d: Calculate signature deadline

The expiry date from the offer letter determines the "we'd love to hear back by" day. Convert the expiry date to a day of the week (e.g., "Tuesday", "Thursday") and use that in the email. If no expiry was set, default to "end of the week."

---

## Step 7: Confirm to User

Reply with one short message:
> "Done — Slack DM sent to [HM name], both Gmail drafts ready (HM + candidate). Drive link: [url] — attach the PDF to the candidate draft and hit Send on both."

---

## Notes

- Company name throughout the letter is **Labor That Works** (not Traba)
- The PDF is also saved locally at `~/workspace/offer-letter/output/` as a backup
- If the Drive upload fails, tell the user the local PDF path and suggest they upload manually
- **"Default bonus structure"** means exactly these two line items — no others:
  - **Recruit bonus:** $100 (candidate you sourced hits 10 shifts)
  - **Onboard bonus:** $25 (candidate you supported hits 10 shifts)
- These bonuses must ALWAYS appear in the offer letter's Compensation section (not just the Slack message). After the base hourly rate line, add an "Incentive Bonuses" subsection with both line items.
- The base hourly rate line in the Compensation section must ALWAYS be fully bolded: `<strong>Base Hourly Rate: $XX/hour</strong>` (the entire phrase, not just partial)
- Do NOT include the on-time worker bonus ($50/shift) or any other performance bonuses unless the user explicitly adds them
- **When changing offer letter content** (benefits, PTO/leave, bonuses): the actual letter text lives in `~/workspace/offer-letter/generate.js`, not this SKILL.md. This file only controls conversational inputs and the Slack/email summary — update both if the change affects inputs too.

### Benefits Region Mapping

The `state` input maps to a benefits region which determines the Employee Only weekly premium. All other premium tiers ($199.38 Spouse, $187.62 Child(ren), $252.69 Family) are the same across regions.

| Region | Employee Only (weekly) | States |
|--------|----------------------|--------|
| 1 | $28.39 | TX, NC, FL, UT, GA, NV, AR, IN, OH, SC |
| 2 | $39.59 | TN, MO, KY, MI, AZ |
| 3 | $56.43 | PA, WV, CO, MN, WI, MD, VA |
| 4 | $50.72 | MS, NJ, IL, WA, OK, MA, DC |

If the state is not in the mapping (e.g. CA, NY), the generator defaults to Region 1 rates and `enrollmentKit` will be `null`. Warn the user and ask them to provide a `region` override (1-4) if they know it.

The generator also outputs `enrollmentKit.en` and `enrollmentKit.es` Drive URLs for the Beni Solutions enrollment kit PDFs. Include both links in the Gmail draft so the HM can forward the appropriate kit to the candidate.
