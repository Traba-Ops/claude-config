---
name: traba-design
description: |
  Use when building any UI: HTML pages, mockups, prototypes, dashboards, product demos, or front-end code.
  Applies the design system — colors, typography, layout patterns, and component styles.
  Trigger on: HTML, CSS, React, styling, layout, components, mockup, prototype, dashboard, page, UI, frontend.
version: 3.1.0
---

# Traba Design System

You are building UI for Traba. Apply this design system exactly.

## Critical Rules (Do NOT violate)

1. **Page background is WHITE (`#FFFFFF`)** — never gray page backgrounds
2. **Tags/badges use `border-radius: 4px`** — NEVER pill-shaped / fully rounded
3. **Sidebar is 154px wide** — not 240px
4. **Font is Poppins only** — weights 400, 500, 600. NEVER bold (700+) or thin/light
5. **Dividers are 1px lines (`#E2E5E9`)** — not thick borders or background color blocks
6. **SVG icons use `stroke-width: 1.8`** — softer/friendlier than 2.0
7. **Friendly, not techy** — warm, approachable SaaS feel. Generous whitespace, soft borders, light tint backgrounds

## Design Philosophy

- **Light and open.** White backgrounds, thin borders, generous padding. The UI should feel breathable, not dense.
- **Hierarchy through weight and color, not size.** Section headers are 13-14px medium weight — they're distinguished by color and case, not by being large. KPI values are the exception (28px semibold).
- **Tint backgrounds for grouping.** Use `{color}-10` tints (e.g., `bg-violet-10`, `bg-green-10`) to create visual regions without hard borders. The only gray background area is the stats bar (`bg-gray-10`).
- **Subtle interactivity.** Hover states are gentle — border color shifts (`gray-20` → `gray-30`), background tints (`bg-gray-10`), slight transforms (`translateY(-1px)`). Never dramatic color changes.
- **Semantic color pattern.** Every semantic color (green, red, orange, blue, violet) follows the same pattern: `-10` for background tint, `-70` for text, `-60` for active/bright states, `-80` for darkest. Use this pattern consistently for badges, status indicators, and alerts.
- **Uppercase labels.** KPI labels, table headers, section labels, and sidebar section headers are always uppercase, `text-[11px] font-medium tracking-wide text-gray-60`.

## Reference Components

Pre-built TSX components live in [`components/`](components/). Copy these into new projects and adapt as needed. They use Tailwind utility classes with the Traba token palette.

| Component | File | Usage |
|-----------|------|-------|
| Badge | [`badge.tsx`](components/badge.tsx) | Status tags, category labels |
| Stat Card | [`stat-card.tsx`](components/stat-card.tsx) | KPI display cards |
| Section Header | [`section-header.tsx`](components/section-header.tsx) | Uppercase section labels |
| Sidebar | [`sidebar.tsx`](components/sidebar.tsx) | 154px app navigation |
| Topbar | [`topbar.tsx`](components/topbar.tsx) | Breadcrumb header bar |
| Filter Button | [`filter-button.tsx`](components/filter-button.tsx) | Toggle filter tabs |
| Data Table | [`data-table.tsx`](components/data-table.tsx) | Styled table with headers |
| Status Dot | [`status-dot.tsx`](components/status-dot.tsx) | Colored activity indicators |

For interactive patterns (tooltips, slide-out panels, selects, dialogs), use shadcn/ui components styled with Tailwind.

## Color Tokens

All colors are mapped as Tailwind theme colors — use them as utility classes (e.g., `text-midnight-100`, `bg-violet-10`, `border-gray-20`).

### Tailwind Theme Mapping

Include this in `app.css` inside a `@theme` block:

```css
@theme {
  --color-violet-100: #1A0033; --color-violet-90: #330066; --color-violet-80: #4D0099;
  --color-violet-70: #6600CC; --color-violet-60: #8000FF; --color-violet-50: #9933FF;
  --color-violet-40: #BF80FF; --color-violet-30: #D9B3FF; --color-violet-20: #E6CCFF;
  --color-violet-10: #F5EBFF;

  --color-midnight-100: #08105E; --color-midnight-80: #313981;
  --color-midnight-60: #6A70AF; --color-midnight-40: #9CA0C9; --color-midnight-10: #F2F3F7;

  --color-green-80: #0D5939; --color-green-70: #138656; --color-green-60: #1AB273; --color-green-10: #EDF8F3;
  --color-red-80: #910836; --color-red-70: #C20A47; --color-red-60: #F20D59; --color-red-10: #FEE7EE;
  --color-orange-80: #915808; --color-orange-70: #C2750A; --color-orange-60: #F2930D; --color-orange-10: #FEF4E7;
  --color-blue-80: #133986; --color-blue-70: #4562A1; --color-blue-60: #2060DF; --color-blue-10: #E9EFFC;
  --color-yellow-80: #806102; --color-yellow-70: #CC9900; --color-yellow-60: #FFBF00; --color-yellow-10: #FFF9E5;
  --color-peach-80: #912A08; --color-peach-70: #C2380A; --color-peach-60: #F2460D; --color-peach-10: #FEEDE7;

  --color-gray-80: #414D58; --color-gray-70: #576675; --color-gray-60: #66788A;
  --color-gray-50: #7A8A99; --color-gray-40: #B6BFC9; --color-gray-30: #C4CCD4;
  --color-gray-20: #E2E5E9; --color-gray-10: #F7F7F8;

  --font-sans: "Poppins", sans-serif;
}
```

### Brand Colors

| Token | Hex | Usage |
|-------|-----|-------|
| `violet-60` | `#8000FF` | Primary CTA, active states, accent |
| `violet-10` | `#F5EBFF` | Active sidebar bg, violet badge bg |
| `midnight-100` | `#08105E` | Headings, primary text |

### Semantic Colors

Pattern: `-10` = bg tint, `-70` = text, `-60` = bright/active, `-80` = darkest

| Color | Purpose |
|-------|---------|
| Green | Success, active, approved |
| Red | Error, inactive, rejected |
| Orange | Warning, stale, pending |
| Blue | Info, links, neutral highlight |

### Grayscale

| Token | Usage |
|-------|-------|
| `gray-70` | Secondary text, ghost button text |
| `gray-60` | Muted text, table headers, inactive tabs |
| `gray-50` | Faint text, sidebar section labels |
| `gray-40` | Placeholder text, search icons |
| `gray-30` | Border hover state |
| `gray-20` | Default borders, dividers |
| `gray-10` | Table header bg, stats bar bg |

## Typography

Font: `Poppins` — weights 400 (Regular), 500 (Medium), 600 (SemiBold). Never 700+.

| Role | Tailwind classes |
|------|-----------------|
| Page heading | `text-lg font-semibold text-midnight-100` (18-20px) |
| Section header | `text-[13px] font-medium text-midnight-100` |
| Body text | `text-[13px] text-midnight-100` |
| KPI value | `text-[28px] font-semibold text-midnight-100` |
| KPI / table label | `text-[11px] font-medium uppercase tracking-wide text-gray-60` |
| Secondary text | `text-[13px] text-gray-70` |
| Muted text | `text-xs text-gray-60` |
| Faint text | `text-[11px] text-gray-50` |
| Links | `text-violet-60 no-underline hover:underline` |

## Layout

| Token | Value |
|-------|-------|
| Page background | White (`bg-white`) |
| Card | `rounded-xl border border-gray-20 bg-white p-4` |
| Card hover | `hover:border-gray-30` |
| Sidebar | 154px wide, white bg, right border |
| Topbar | 52px tall, white bg, bottom border |
| Content padding | 20-24px |
| Default border | `border border-gray-20` |
| Divider | `border-t border-gray-20` |

### Border Radius Scale

| Element | Radius |
|---------|--------|
| Tags / badges | `rounded` (4px) |
| Buttons, inputs, tables, nav items | `rounded-lg` (8px) |
| Toast | `rounded-[10px]` |
| Cards, avatars | `rounded-xl` (12px) |

## Button Variants

| Variant | Classes |
|---------|---------|
| Primary | `bg-violet-60 text-white hover:bg-violet-70` |
| Ghost | `border border-gray-20 bg-white text-gray-70 hover:border-gray-30 hover:bg-gray-10` |
| Active filter | `border-violet-60 bg-violet-10 text-violet-60` |

All buttons: `h-9 rounded-lg px-3.5 font-sans text-[13px] font-medium cursor-pointer`

## Hover Micro-Interactions

- Cards: `hover:border-gray-30`
- Table rows: `hover:bg-[#FAFAFA]`
- Lift effect: `hover:-translate-y-px hover:shadow-[0_2px_8px_rgba(0,0,0,0.06)]`
- Edit buttons: `hover:border-violet-60 hover:text-violet-60`
- Transitions: `transition-all duration-150`

## Data Visualization

Use inline SVG for lightweight charts. Color: `violet-60` (`#8000FF`) as primary chart color with opacity variations. For complex dashboards, chart libraries are fine.

- **Sparklines / bar charts:** `bg-violet-60 opacity-50`, hover to `opacity-85`
- **Progress bars:** 6px height, `bg-gray-20` track, colored fill (`green-60`, `orange-60`, `red-60`, `violet-60`)
- **Heatmaps:** CSS grid, intensity via violet shades (`gray-10` → `violet-20` → `violet-40` → `violet-60`)
- **Status dots:** 7-8px circles with semantic colors (`green-60` active, `orange-60` stale, `red-60` inactive)

## Content Guidelines

Use realistic Traba data:

| Category | Examples |
|----------|----------|
| Roles | Picker, Packer, Forklift Operator, Dock Worker, QC Inspector |
| Facilities | "Warehouse A - Newark", "DC East - Edison", "Fulfillment Center - Cranbury" |
| KPIs | Pick rate: 120-160 units/hr, Fill rate: 85-98%, Attendance: 90-99% |
| Shifts | Morning (6a-2p), Afternoon (2p-10p), Night (10p-6a) |

### Worker Type Differentiation

Always visually distinguish with left border + tint:

| Type | Colors | Border |
|------|--------|--------|
| FT Employee | `bg-blue-10 text-blue-80` | `border-l-[3px] border-l-blue-60` |
| Traba Temp | `bg-violet-10 text-violet-80` | `border-l-[3px] border-l-violet-60` |
| Other Agency | `bg-gray-10 text-gray-70` | `border-l-[3px] border-l-gray-40` |
