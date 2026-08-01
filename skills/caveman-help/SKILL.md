---
name: caveman-help
description: >
  Quick-reference card for all caveman modes, skills, and commands.
  One-shot display, not a persistent mode. Trigger: /caveman-help,
  "caveman help", "what caveman commands", "how do I use caveman".
---

# Caveman Help

Display this reference card when invoked. One-shot — do NOT change mode, write flag files, or persist anything. Output in caveman style.

## Modes

| Mode | Trigger | What change |
|------|---------|-------------|
| **Lite** | `/caveman lite` | Drop filler. Keep sentence structure. |
| **Full** | `/caveman` | Drop articles, filler, pleasantries, hedging. Fragments OK. Default. |
| **Ultra** | `/caveman ultra` | Extreme compression. Bare fragments. Tables over prose. |
| **Wenyan-Lite** | `/caveman wenyan-lite` | Classical Chinese style, light compression. |
| **Wenyan-Full** | `/caveman wenyan` | Full 文言文. Maximum classical terseness. |
| **Wenyan-Ultra** | `/caveman wenyan-ultra` | Extreme. Ancient scholar on a budget. |

Mode stick until changed or session end.

## Skills

| Skill | Trigger | What it do |
|-------|---------|-----------|
| **caveman** | `/caveman [level]` | The mode itself. Levels above. |
| **caveman-help** | `/caveman-help` | This card. |

## Deactivate

Say "stop caveman" or "normal mode". Resume anytime with `/caveman`.

## Language

Keep user's language by default. User write Portuguese → reply Portuguese caveman. Compress the style, not the language. Technical terms, code, commands, commit types, and exact error strings stay verbatim unless user ask for translation.

## Always-On

Caveman on by default. One flag file drive it: `~/.claude/.caveman-always`. Line 1 = intensity.

| Want | Do |
|------|-----|
| Off for this session | Say "stop caveman" or "normal mode" |
| Off for good | `rm ~/.claude/.caveman-always` |
| Different intensity | Write `lite`, `full`, `ultra`, `wenyan-lite`, `wenyan-full`, or `wenyan-ultra` into that file |
| Back on after deleting | Re-run the installer, or `echo lite > ~/.claude/.caveman-always` |

```bash
echo ultra > ~/.claude/.caveman-always   # change intensity
rm ~/.claude/.caveman-always             # turn always-on off
```

Unrecognized value in file → falls back to `full`. Custom `CLAUDE_CONFIG_DIR` → flag live there, not `~/.claude`.

## More

Full docs: https://github.com/JuliusBrussee/caveman
