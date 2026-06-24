---
name: attach-video-to-pr
description: |
  Get a demo video rendering inline in a GitHub PR, as a comment. Mints a user-attachments URL
  with `gh-attach`, then posts a PR comment with it.
  Use when: (1) attaching a demo/QA video to a PR, (2) any "put this video on the PR so it plays
  inline" ask.
  Covers: why only user-attachments URLs auto-embed, the mint-then-post flow, and the fallback.
version: 1.0.0
user-invocable: true
---

# Attach a demo video to a PR (inline)

GitHub auto-embeds a video as a player only when its URL is on the `github.com/user-attachments/assets/…`
domain — release-asset and `raw.githubusercontent.com` URLs render as plain links, and `<video>`
HTML is stripped. There is no token API for minting that URL; it needs a github.com **web session**.
So: mint the URL with `gh-attach` (which reads your browser session), then post a PR comment with it.

## Prerequisites (one-time)

- `gh extension install sudosubin/gh-attach`
- Be logged into **github.com in a local browser** (Chrome by default) and have run `gh auth login`.
  `gh-attach` matches the browser session whose `dotcom_user` equals your gh login — no separate
  login step.

## Mint the URL

```bash
gh attach <video-path> -R <owner/repo> --json href --jq .href
```

Returns `https://github.com/user-attachments/assets/<uuid>`. The asset is minted under your session;
on private repos it's access-scoped to people with repo access (PR reviewers are fine). Add
`--browser <name>` / `--profile <name>` if the github.com session lives in a non-default browser.

## Post the comment

Post the minted URL with the **URL on its own line** — that's what triggers the inline player:

```bash
gh pr comment <PR#> --body "<minted-url>"
```

Prefer a comment over editing the PR description (`gh pr edit --body` replaces the whole body).

## Verify on first use

Confirm on a real PR that the posted comment renders an inline **player**, not a literal URL
(standard for a `user-attachments` URL on its own line). `.mp4` is known to work.

## Fallback

If minting fails (expired/missing browser session, video rejected) or the comment doesn't render a
player, upload the video to another host your team uses (a Slack thread, Drive) and link to it in
the PR instead.
