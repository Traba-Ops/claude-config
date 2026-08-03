# Provenance

`SKILL.md` and `LICENSE` are vendored **verbatim** from the upstream i-have-adhd
plugin. Keep them byte-identical so a re-sync is a clean diff against a known
base — put bundle-specific notes here instead.

| | |
|---|---|
| Upstream | https://github.com/ayghri/i-have-adhd |
| Revision | `d05af1e4ac2259846e81686d14180d46d84acc2d` (2026-07-31) |
| License | MIT — Ayoub Ghriss, kept at `LICENSE` |

Upstream paths: `SKILL.md` ← `.cursor/skills/i-have-adhd/SKILL.md`, `LICENSE` ←
`LICENSE`.

To re-sync: diff the upstream files at the revision above against these two, then
bump the revision here.

The `metadata.hermes` block in the frontmatter is upstream plugin-registry
metadata with no meaning in this bundle. It's kept only to preserve the verbatim
diff — don't build anything on it.

`hooks/adhd-always-on.sh` in this repo is *adapted* from upstream's
`hooks/always-on.sh` (not verbatim — it resolves the skill from
`$CLAUDE_CONFIG_DIR` and drops the Node dependency); see the header comment in
that file.
