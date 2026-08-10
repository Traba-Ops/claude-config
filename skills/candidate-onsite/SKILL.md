---
name: candidate-onsite
description: Plan a candidate's "Day in the Life" onsite — build the schedule against what they're actually deciding, brief every host on one outcome inside their calendar invite, book a different room per block, and produce the candidate-facing itinerary plus the office map. Use for "plan X's onsite", "day in the life", "candidate is coming in Tuesday", or when a late-stage candidate is visiting to make a decision. The method is general; the named hosts, rooms, and address are Traba's and need swapping elsewhere.
---

# Candidate onsite ("Day in the Life")

For a late-stage candidate visiting to decide. Half a day is the default; a full day only if they're traveling far.

## The one rule that matters: build the day against their actual hesitation

A generic tour is worthless. Find out what they are *actually still deciding* and point every block at it.

1. **Pull the Ashby record first.** `application.info` for the stage, `applicationFeedback.list` for every scorecard, and `interviewSchedule.list` for who has already interviewed them and when. The verbatim interviewer notes are what let you split settled from open, and the interviewer list tells you who *not* to schedule again. Auth is basic with `$ASHBY_API_KEY` as the username and an empty password.
2. **Then get the recruiter's debrief.** Search Slack for the external recruiter's call notes — usually the richest single source, and often the only place facts like "not currently employed since April" are written down. If a result is truncated, `slack_search_public_and_private` returns the full text where `slack_read_thread` and `slack_read_channel` both cut off.
3. **Separate what's settled from what's open.** Usually culture and scope are already won by this stage. Whatever's left — growth, ambition, ownership, comp — is the entire job of the day.
4. **Write their open questions down verbatim and assign each one to a host** — then put that host's question into their invite, in the candidate's words. If you skip this, four people give the same generic pitch and the candidate learns nothing after the first hour.

**Don't re-run the people they already met.** By this stage a late-stage candidate has usually done a full loop — Jay had already sat with seven Traba engineers three weeks earlier. Staffing this day with those same people wastes the visit and tells the candidate nothing new. Pull the interviewer list from Ashby and pick hosts who are *not* on it, unless someone is there for a specific reason (the hiring manager, the CEO, the CTO).

**And don't re-open what the loop already closed.** If an interviewer flagged something that the recruiter's notes actually answer — "didn't get a read on why he left" when the debrief explains it in a paragraph — say so explicitly in the plan and tell hosts not to probe it. Re-litigating a settled question on decision day signals we think something is wrong and puts the candidate on the defensive.

Frame each brief around what the candidate is curious about, not their doubts. The host reads it an hour before the block: "he's worried we're stalling" lands worse than "he wants to see what's coming" and produces the same conversation.

## The artifact that does the work: "what should they walk out thinking"

Every block gets one line, **in the candidate's voice**, of what they should be thinking as they leave it. Use the candidate's own pronouns in the real table; the column is written neutrally here.

| Time | Block | Who | They should walk out thinking |
|---|---|---|---|
| 10:30 | Neo technical deep dive | Moreno | *"An engineer here owns real things. Nobody's asking permission."* |
| 11:30 | CTO interview | Akshay | *"I understand the path to a very large company, and I can walk it here."* |

Both lines are first person, because the column is what the *candidate* is thinking. "I believe he can walk it" is the hiring team's voice and defeats the whole device.

Why this beats a topic list: it's testable. If they leave without that line, the block failed regardless of what got covered. Hosts also self-correct mid-meeting against a feeling in a way they never do against an agenda item.

Hold the through-line while you build — *arrives thinking X, should leave thinking Y* — and let it decide the order of the day. It doesn't need a document of its own.

**The walk-out line ships inside each host's calendar invite**, not in a plan doc. One line of what the candidate should be thinking as they leave, then a brief on **how to produce that feeling** rather than what to cover. "Show sequencing and why this before that" beats "walk through the roadmap." If a line needs evidence — a number, a demo, one concrete instance — say so explicitly.

## Build the schedule from constraints, not from a wish list

**Publish the constraint table before proposing any schedule.** Pull every participant's real calendar for that day and write down: each person's genuinely free windows, which blocks are pinned (recurring meetings, all-hands, the candidate's flight), and total minutes available. Then solve.

Skipping this costs enormous rework. Requirements arrive one at a time — "keep the 1:1s", "add two more people", "we need lunch", "give X 45 minutes" — and each one invalidates a point-solution schedule. With the constraint table published, each new requirement re-solves in one step instead of restarting.

- **Delegate the calendar sweep to a subagent.** The Calendar MCP returns whole event objects; ten people blows the token limit. Have the subagent return one compact line per person.
- **A subagent may not have the MCP connector you're delegating to.** Availability isn't uniform — a Slack sweep came back having never run a single search because `mcp__claude_ai_Slack__*` didn't exist in that agent's toolset, while a Calendar agent spawned minutes later had everything. Tell the agent to verify its tools first and abort loudly rather than improvise, and for a two-or-three-call lookup just do it inline; the round trip costs more than the search.
- **Re-check the calendar of anyone the plan actually depends on.** A summarized sweep is fine for a first pass but is not reliable enough to schedule an exec or a blocking host on — it drops overlapping events and silently invents display names. Pull those calendars yourself before you commit a slot.
- **Never infer anyone's surname.** Calendar display names are frequently wrong — they produced "Akshay Reddy" for Akshay Buddiga. Slack is no better: most Traba profiles are first-name-only, so the absence of a surname there tells you nothing. If a full name is going in front of a candidate and you have not seen it from the person themselves or been told it, **ask** — do not guess and do not let a plausible-looking one through.
- **Mark soft vs hard.** Focus blocks, gym, work blocks, lunch, and commute move. Customer calls and all-hands don't.
- **1:1s can always be moved.** Treat every 1:1 as free space — never let one block a candidate slot or narrow the options you present. Interviews with other candidates are a step harder, since someone external gets rescheduled, but they move too when the alternative is breaking a fixed block.
- **Optional attendees are a lever** — someone booked solid may be optional on the thing that's blocking them.
- **Say which constraint is binding.** "X's only free window all day is 11:50–1:00" tells the user why they can't have what they asked for, and it's the sentence that ends the negotiation.

Some asks are genuinely impossible. Two 45-minute blocks don't fit in 75 minutes. Say so with the arithmetic rather than silently shaving something.

## Six blocks are mandatory; everything else is theirs

Unless told otherwise, every onsite contains these six. Three are pinned to a fixed position — place those first, then the CEO and CTO, then the meal, and only then fill what's left with what the candidate said they want.

1. **Office tour — 15 min, always the first block.**
2. **Overview with the hiring manager — 15 min, always the second block.**
3. **CEO interview — 30 min**, anywhere in the middle.
4. **CTO interview — 30 min**, anywhere in the middle.
5. **Lunch or dinner — 45 min**, one of the two, never neither.
6. **The close — 30 min, always the last block.**

Count them as six, not five: CEO and CTO are two blocks, two rooms, two invites.

**Do the arithmetic before you promise anyone anything.** The six come to 165 minutes. An 11:00–3:30 day is 270 minutes, so there are **105 minutes** — an hour and three quarters — actually available for what the candidate asked for. Only the first 30 and last 30 are *positionally* pinned, which is a different and much smaller claim than "everything else is free." Quote the 105, not the 210.

**Two collisions to check before you build anything else**, because both fail late and force a full restart:

- **The CEO versus the close.** If the CEO's only free window is the last half hour of the day, it is the same slot as the close. One of them moves, and it will not be the close. Look at the CEO's calendar first and find their second-best window.
- **The hiring manager at the top of the day.** Block 2 needs them 15 minutes after the candidate walks in — often the exact time they are in a standup or another interview. The overview cannot be delegated or moved, so that slot has to be cleared; it is usually the single hardest ask of the day. Recruiting running the tour (below) is what protects those 15 minutes, which is the main reason the tour isn't the hiring manager's by default.

**Traba staffing — who runs the tour, in order:** **Humna first, then Maya, and only as a last resort Jeff.** Recruiting owns the opener; pulling the hiring manager onto the door costs him the 15 minutes before his own overview block, which is the tightest slot in the day. Check availability in that order rather than assuming — Humna and Maya run back-to-back recruiter screens most days and one being OOO is common, so it is normal for this to fall through to Jeff, but only after you have actually looked.

**Oscar is remote.** He cannot run the tour or be in the room for the close. He still belongs in the close, by video, with someone assigned to get him on screen and unmuted before the candidate sits down.

The CEO and CTO blocks are **interviews**, not "conversations" or "chats" — use that word in the itinerary row and in the invite title. Naming the block "CTO interview" is not the same as reassuring the candidate about which blocks are or aren't interviews; the label is fine, the explanatory note is what doesn't belong.

**Who hosts what at Traba:** Neo roadmap and growth → Devin or Jake, or both. Neo technical deep dive → Micah or Moreno — both NYC, both in-person hosts (confirmed by Jeff 2026-08-09; a calendar timezone of America/Denver means nothing about where someone sits — verify location with Jeff, never infer it).

**Fixed block durations (Jeff, 2026-08-09):** the Neo roadmap/growth segment (Devin/Jake), the staffing business/ops roadmap segment (Lauren), and the Neo technical deep dive are **always 30 minutes each** — don't stretch them to fill a gap; give spare minutes to lunch-adjacent buffer or own-time-at-a-desk instead. Lunch is always 45 minutes (never 60).

**One host per working session, not two "to be safe."** Staffing a block with two people because both know the topic wastes an engineer's afternoon and gives the candidate a panel feel. Two is right only when you specifically want them to disagree in front of the candidate — a roadmap where the direction is genuinely contested. Otherwise one.

Everything else is flexible. **Ask the candidate what they want from the day** and build the remaining slots around their answer — a roadmap conversation, a technical deep dive, team rituals, whatever they name. A late-stage candidate who tells you their agenda has handed you the whole plan; the only mistake left is not using it.

## Block types that earn their place

**Own time at a desk (30 min).** They sit in the working area handling their own email. Nobody hosts them. This is the only uncurated signal in the day — what the floor actually sounds like on a normal working morning — and it's a real break in an otherwise packed schedule. Put it when the team is in a recurring meeting so there's nobody to meet anyway. **Tell whoever sits nearby not to entertain them.**

**Lunch, open invite, engineers only, no execs.** The only off-the-record time most visits have. Protect it. A real ask in the team channel produces a better table than a calendar invite — four people who came on their own beats ten who were invited, and two reads as nobody cared.

**A group session with two or three people.** Better than a 1:1 for showing whether two functions' ambitions line up (engineering and go-to-market arguing about where the product goes). Thirty minutes with three people goes flat unless someone opens with a real question cold — brief them to put one on the table and ask the candidate what *they* would build.

**Don't put a candidate in a retro.** Teams say what's broken in retros. Engineers will tell you directly that they'd be annoyed to sit through one while interviewing. An all-hands or a tech talk is the forward-looking equivalent.

**Sequencing: claim, then corroboration.** Put the CEO or the big-vision conversation *before* an all-hands, so the room reads as the whole company independently confirming what was just claimed. Reverse it and the pitch sounds like a rebuttal.

**Don't have the candidate present anything.** It flips the frame from recruiting them to auditioning them.

**A recurring meeting that already exists is the cheapest block you can give them.** If they asked to see team rituals, put them in the real standup rather than staging a description of one — it costs no host, nobody performs, and it's the only version that's actually true. The same goes for an all-hands. **Do not create an invite for these**; the event already exists, so just leave the slot on the itinerary and tell the host who runs it that the candidate will be sitting in.

## Travel is a hard constraint — solve it first

Get the actual flight before building anything. Work backward: airport arrival, bag pickup if they haven't checked out, and realistic traffic. Then set the leave-the-office time and build the day inside it.

- **Ask them to bring bags to the office** after checkout. Killing the hotel stop routinely buys 20–30 minutes.
- **Book the car in advance.** A candidate hailing a ride after a close is a bad final beat.
- **If they arrive the night before, take that evening.** A low-key dinner with two or three teammates does everything the lunch is trying to do, with no clock and no agenda, and they walk in the next morning already knowing faces.

## The close

Last block of the day, 30 minutes, small room. **The roster is the hiring manager plus the recruiter, and that's it** — the two people who have walked the candidate through the process. Not a panel, and not "whoever else was good with them."

On the itinerary this block is called **"Wrap up"**, and both names go in the `Who you're meeting` column exactly as they'd be introduced — "Jeff Chen, Oscar (by video)". Naming the recruiter is expected and fine; what must never appear is the *word* close, the word verbal, or anything about the number. The leak check below is about strategy language, not about who's in the room.

**Align the number before the morning of.** If the close is when you work out what you're offering, it's a meeting, not a close.

Brief it as: don't say "we'd love to have you." Name the thing only they do, and what you want them to own in their first six months. Then ask.

If someone joins remotely, assign an owner to get them on screen and unmuted *before* the candidate sits down.

## Two artifacts, and neither of them is an internal plan

The deliverables are **the candidate-facing itinerary** and **the office map it links to**. That's the whole set.

**Do not write an internal plan doc.** It reads well and nobody opens it. Everything that would have gone in it — the premise, the walk-out-thinking line, the per-host brief, the calendar move — belongs in the one place the host will actually look on the day, which is **their own calendar invite**. Put it there instead. The premise and the through-line are yours to hold while you build; they shape the schedule and the briefs, and then they don't need a home of their own.

**Candidate-facing itinerary** — keep it to **the full street address, the schedule table, and a link to the office map.** Four elements including the title, and nothing else. The address is `115 5th Ave, Floor 6` — put it in the header line, and never infer the floor from a room-resource name (`Traba HQ-2-Batcave` is a room-system prefix, not floor 2).

Cut everything else: no framing paragraph about what they asked for, no notes section explaining the blocks, no reassurance about what is and isn't an interview, and **no "so-and-so will meet you at the door" line** — the first row of the table already names who they're meeting at the first block, so the door line is redundant on the page and it pins a person before the day is final. Add the car time only if they're travelling.

Table columns are exactly `Time | Duration | What | Who you're meeting | Where` (Duration as `45 min`; `—` for the head-out row).

**Office map** — **every candidate gets their own copy.** Copy the NYC office map spreadsheet fresh for each onsite, then **put the candidate's name in cell I7** — that's the seat they'll be sitting at, and it's the whole reason the copy is per-candidate rather than a shared link. Never send two candidates the same map file.

**The file you copy is probably the last candidate's copy, not a clean template** — I7 came through still saying "Pranav." Always read I7 after copying and confirm it holds *this* candidate's name and nobody else's. Keep only the current tab, and **rooms only, people removed** — clear the other name cells. A hand-built map looks worse and costs more, so always copy the real one. Link it from the itinerary as one line at the bottom rather than embedding it or describing the floor in prose.

**Check the candidate doc for leaks before sending.** Grep it for the walk-out-thinking lines, comp strategy, competitor names, "close", and "verbal". The last block is "Wrap up", not "Pen to paper — the verbal." The recruiter's *name* belongs there; the recruiting *vocabulary* does not.

### Making the itinerary a Google Doc

It's a Google Doc, not a file on disk. Use the **Drive MCP** — `mcp__claude_ai_Google_Drive__create_file` with `contentMimeType: text/markdown` (or `text/html`) and the body in `textContent`. No gcloud, no token, no scope juggling, and it produces real heading styles.

- **Don't reach for `gcloud auth print-access-token`.** It does **not** carry Drive scope by default — Drive and Docs return 403 `ACCESS_TOKEN_SCOPE_INSUFFICIENT`. Getting the scope needs `gcloud auth login --enable-gdrive-access`, an interactive browser flow that **cannot run in a background job**. Only fall back to gcloud + the Docs REST API to edit an *existing* doc in place, and then have the user run the login via `! gcloud auth login --enable-gdrive-access`.
- **The Drive MCP has no delete or trash tool.** Every `create_file` is permanent from your side, so don't create speculative drafts — you'll strand them and have to ask the user to clean up. Get the content right before the first call.
- **`read_file_content` is not a faithful view of the doc.** It renders a Doc table as an empty header row plus a body row of literal `\*\*Time\*\*` escapes, even when the real cells are properly bolded and there's no stray row. This looks exactly like a broken import and will send you chasing a bug that doesn't exist. **Verify with `download_file_content` and `exportMimeType: text/html`** — that export is ground truth, and bolded cells appear there as `font-weight:700`.
- `fileSize: 1` in the `create_file` response doesn't mean the body was dropped. Ignore it.
- If `create_file` ever returns a Cloudflare "you have been blocked" HTML page, it's the WAF reacting to shell commands in the body. Onsite docs shouldn't contain any.

## Calendar invites

One per block, organized by the host, room booked. Include the candidate if you have their email.

- **Prefix every title `HOLD:`** — e.g. `HOLD: Pranav onsite — CTO interview`. It reads as provisional, so people move things around it instead of treating it as settled.
- **Put the hiring manager on every invite**, including blocks they aren't part of. They decline the ones they're not in; the day still shows up on their calendar as one continuous thing, which is what they need to run it.
- **Use Zoom, not Google Meet, for anything in a conference room.** Traba's rooms are Zoom Rooms and in practice have not joined Meet links. Google attaches a Meet link to invites with attendees, and the Calendar MCP's create/update path gives you no way to remove one once it's there — so swap it by hand via the Zoom add-on in the event, or have the host create the invite from Zoom in the first place. Check the event before the day rather than assuming the swap took.
- **The invite description is where the brief lives**, because there is no internal doc. Structure it as: candidate name + role, the walk-out-thinking line, two to four sentences of how to produce it, and the host's own calendar move. The briefs are the part nobody can infer from a calendar entry — "don't resolve the contradiction for him", "a demo won't land, he already does this" — so they have to survive here.
- **Keep it to that.** A goal line plus a few instructions. Nobody reads a six-paragraph calendar invite, and the long reasoning has nowhere else to be because it shouldn't exist.
- **Put each person's required calendar move in their own invite** ("this needs your 3:45 prep pushed") so the ask travels with the event.
- **Book the room as a resource attendee, not just location text.** Adding the room's `c_...@resource.calendar.google.com` address to `attendees` with `resource: true` is what actually reserves it; putting the name in `location` only labels the event and leaves the room bookable by anyone else. After creating, re-list the events and confirm each room came back `responseStatus: accepted` — that is the only proof the booking took.
- **Check room resource calendars** before booking. **Put the candidate in a different room every block** — a day spent in one conference room while people cycle through feels like a holding pen, and they see none of the office. Rotating walks them across the whole floor, which is most of what makes a place feel like somewhere they'd work. The cost is real: one booking per block instead of one for the day, so check every room against its resource calendar. Have each host **collect them from the previous room** rather than sending them to find the next one.
- **Verify full names the way the surname rule above says** — from the person, from someone who knows, or from the org chart. Not from a calendar display name, and not from a Slack profile: Slack gave "Moreno Rodriguez" for Moreno Antunes on the same day its profiles were right about four other people. Putting a colleague's wrong surname in front of a candidate is the kind of error that gets noticed.
- **No gaps.** Account for every minute including the walk-out. A ten-minute gap between an all-hands and the close is still worth an event.
- **Announce optional attendees as optional in the first line** of the description, or a whole eng list thinks it must attend.
- Use `notificationLevel: NONE` for cosmetic edits, `ALL` for time or attendee changes.

## Traps

- **Google Docs `uploadType=media` is a whole-file replace.** If you do go the REST route, always `GET /drive/v3/files/{id}/export?mimeType=text/markdown` immediately before writing, or you'll silently destroy edits the user made in the browser.
- **Calendar has no headless fallback at all.** Calendar work needs the MCP connector. If the connector's session expires mid-task, say so and stop rather than guessing.
- **Slack cannot invite people to a private channel** — a bot that isn't a member gets `channel_not_found`, and the Slack MCP has no invite tool at all. Hand the user a ready-to-paste `/invite @a @b @c` line.
- **When anything about the timing changes, the calendar and the docs drift apart.** This is not only about the date — one fixed block ending ten minutes later than you assumed retimes every block after it. Update the invites and the itinerary in the same turn, and grep the docs for the old day name and the old times.
