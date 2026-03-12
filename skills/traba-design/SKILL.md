---
name: traba-design
description: |
  Use when building any UI for Traba: HTML mockups, prototypes, product demos, or front-end code.
  Applies the full Traba design system — colors, typography, layout patterns, and component styles.
version: 2.0.0
---

# Traba Design System

You are building UI for Traba. Apply the following design system exactly. Do not deviate from these tokens, fonts, or patterns.

## Critical Rules (Do NOT violate)

1. **Page background is WHITE (`#FFFFFF`)** — never use gray backgrounds for the page
2. **Tags/badges use `border-radius: 4px`** — NEVER pill-shaped / fully rounded
3. **Sidebar is 154px wide** — not 240px
4. **Font is Poppins only** — weights 400, 500, 600. NEVER bold (700+) or thin/light
5. **Dividers are 1px lines (`#E2E5E9`)** — not thick borders or background color blocks
6. **SVG icons use `stroke-width: 1.8`** — softer/friendlier than 2.0
7. **Friendly, not techy** — warm, approachable SaaS feel. Generous whitespace, soft borders, light tint backgrounds

---

## Setup — CSS Custom Properties

Include this `:root` block and font import:

```css
@import url('https://fonts.googleapis.com/css2?family=Poppins:wght@400;500;600&display=swap');

:root {
  /* Brand */
  --violet-100: #1A0033; --violet-90: #330066; --violet-80: #4D0099;
  --violet-70: #6600CC; --violet-60: #8000FF; --violet-50: #9933FF;
  --violet-40: #BF80FF; --violet-30: #D9B3FF; --violet-20: #E6CCFF;
  --violet-10: #F5EBFF;

  /* Midnight */
  --midnight-100: #08105E; --midnight-80: #313981;
  --midnight-60: #6A70AF; --midnight-40: #9CA0C9; --midnight-10: #F2F3F7;

  /* Semantic */
  --green-80: #0D5939; --green-70: #138656; --green-60: #1AB273; --green-10: #EDF8F3;
  --red-80: #910836; --red-70: #C20A47; --red-60: #F20D59; --red-10: #FEE7EE;
  --orange-80: #915808; --orange-70: #C2750A; --orange-60: #F2930D; --orange-10: #FEF4E7;
  --blue-80: #133986; --blue-70: #4562A1; --blue-60: #2060DF; --blue-10: #E9EFFC;
  --yellow-80: #806102; --yellow-70: #CC9900; --yellow-60: #FFBF00; --yellow-10: #FFF9E5;
  --peach-80: #912A08; --peach-70: #C2380A; --peach-60: #F2460D; --peach-10: #FEEDE7;

  /* Grayscale */
  --black: #000000; --gray-80: #414D58; --gray-70: #576675;
  --gray-60: #66788A; --gray-50: #7A8A99; --gray-40: #B6BFC9;
  --gray-30: #C4CCD4; --gray-20: #E2E5E9; --gray-10: #F7F7F8;
  --white: #FFFFFF;
}
```

---

## Typography

```
Font family: 'Poppins', sans-serif
```

| Role | Size | Weight | Color |
|------|------|--------|-------|
| Worker name / page heading | 18–20px | 600 (SemiBold) | `#08105E` |
| Page title | 16–18px | 600 (SemiBold) | `#08105E` |
| Section header | 13–14px | 500 (Medium) | `#08105E` |
| Body text | 13–14px | 400 (Regular) | `#08105E` |
| KPI value (large) | 16–28px | 600 (SemiBold) | `#08105E` |
| KPI value (stats bar) | 16px | 600 (SemiBold) | `#08105E` / `#8000FF` / `#138656` |
| KPI label | 11–12px | 500 (Medium) | `#66788A`, uppercase, letter-spacing 0.5px |
| Table header | 11px | 500 (Medium) | `#66788A`, uppercase, letter-spacing 0.5px |
| Tag / badge text | 11px | 500 (Medium) | Varies by color |
| Tag small variant | 10px | 500 (Medium) | Varies by color |
| Text secondary | 13–14px | 400 (Regular) | `#576675` |
| Text muted | 11–12px | 400 (Regular) | `#66788A` |
| Text faint | 10–11px | 400 (Regular) | `#7A8A99` |
| Sidebar section label | 10px | 500 (Medium) | `#7A8A99`, uppercase, letter-spacing 0.8px |
| Sidebar nav item | 13px | 500 (Medium) | `#576675` |
| Links | Inherit size | 400 (Regular) | `#8000FF`, no underline (underline on hover) |
| Breadcrumb parent | 14px | 400 (Regular) | `#576675` |
| Breadcrumb current | 14px | 500 (Medium) | `#08105E` |

---

## Color Tokens

### Brand
| Token | Hex | Usage |
|-------|-----|-------|
| **Violet60** | `#8000FF` | Primary CTA, active states, accent, availability dots |
| **Violet10** | `#F5EBFF` | Active sidebar bg, light tint areas, violet badge bg |
| **Midnight100** | `#08105E` | Headings, primary text, toast bg |
| **Midnight10** | `#F2F3F7` | Subtle brand tint |

### Semantic Colors (pattern: 10 = bg tint, 70 = text, 80 = darkest)
| Color | 80 | 70 | 60 | 10 |
|-------|-----|-----|-----|-----|
| **Green** (success) | `#0D5939` | `#138656` | `#1AB273` | `#EDF8F3` |
| **Red** (error) | `#910836` | `#C20A47` | `#F20D59` | `#FEE7EE` |
| **Orange** (warning) | `#915808` | `#C2750A` | `#F2930D` | `#FEF4E7` |
| **Blue** (info) | `#133986` | `#4562A1` | `#2060DF` | `#E9EFFC` |
| **Yellow** | `#806102` | `#CC9900` | `#FFBF00` | `#FFF9E5` |
| **Peach** | `#912A08` | `#C2380A` | `#F2460D` | `#FEEDE7` |

### Grayscale
| Token | Hex | Usage |
|-------|-----|-------|
| Black100 | `#000000` | Rarely used |
| Gray80 | `#414D58` | — |
| **Gray70** | `#576675` | Secondary text, ghost button text |
| **Gray60** | `#66788A` | Muted text, table headers, inactive tabs |
| Gray50 | `#7A8A99` | Faint text, sidebar section labels |
| Gray40 | `#B6BFC9` | Placeholder text, search icons |
| **Gray30** | `#C4CCD4` | Border hover, breadcrumb chevron, inactive dots |
| **Gray20** | `#E2E5E9` | Borders, dividers, table row borders |
| **Gray10** | `#F7F7F8` | Table headers, stats bar bg, note bg, collapsed rows |
| White0 | `#FFFFFF` | Page bg, card bg, sidebar bg |

---

## Layout Tokens

| Token | Value |
|-------|-------|
| Page background | `#FFFFFF` |
| Card background | `#FFFFFF` |
| Card border | `1px solid #E2E5E9` |
| Card border-radius | `12px` |
| Card padding | `16px` |
| Card gap (in grids) | `12px` |
| Sidebar width | `154px` |
| Sidebar background | `#FFFFFF` |
| Sidebar border | `border-right: 1px solid #E2E5E9` |
| Topbar height | `52px` |
| Topbar background | `#FFFFFF` |
| Topbar border | `border-bottom: 1px solid #E2E5E9` |
| Content padding | `20–24px` |
| Content offset | `margin-left: 154px` |
| Border default | `1px solid #E2E5E9` |
| Border hover | `1px solid #C4CCD4` |
| Divider | `height: 1px; background: #E2E5E9; margin: 14px 0` |

### Border Radius Scale
| Element | Radius |
|---------|--------|
| Tags / badges | `4px` |
| Edit buttons | `4px` |
| Sidebar logo icon | `6px` |
| Buttons (all types) | `8px` |
| Sidebar nav items | `8px` |
| Tables | `8px` |
| Search inputs | `8px` |
| View toggles | `8px` |
| Notes | `8px` |
| Compliance banners | `8px` |
| Popovers | `8px` |
| Toast | `10px` |
| Cards | `12px` |
| Avatar (profile) | `12px` |

### Utility Classes

```css
/* Grid layouts */
.grid-2 { display: grid; grid-template-columns: 1fr 1fr; gap: 16px; }
.grid-3 { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px; }
.grid-4 { display: grid; grid-template-columns: 1fr 1fr 1fr 1fr; gap: 16px; }

/* Card */
.card {
  background: var(--white); border: 1px solid var(--gray-20);
  border-radius: 12px; padding: 16px;
}
.card:hover { border-color: var(--gray-30); }

/* KPI */
.kpi-card { text-align: center; padding: 16px; }
.kpi-value { font-size: 28px; font-weight: 600; color: var(--midnight-100); }
.kpi-label {
  font-size: 11px; font-weight: 500; color: var(--gray-60);
  text-transform: uppercase; letter-spacing: 0.5px; margin-top: 4px;
}
```

---

## Components

### Buttons

| Variant | Background | Color | Border | Height | Padding | Radius |
|---------|-----------|-------|--------|--------|---------|--------|
| Primary | `#8000FF` | `#FFFFFF` | none | 36px | 0 14px | 8px |
| Secondary | `#FFFFFF` | `#8000FF` | `1px solid #8000FF` | 36px | 0 14px | 8px |
| Ghost | `#FFFFFF` | `#576675` | `1px solid #E2E5E9` | 36px | 0 14px | 8px |
| Icon-only | `#FFFFFF` | `#576675` | `1px solid #E2E5E9` | 36px | 0 | 8px (w:36px) |

All buttons: `font-size: 13px; font-weight: 500; font-family: 'Poppins'; cursor: pointer;`
Hover: Primary → `#6600CC`, Ghost → `background: #F7F7F8; border-color: #C4CCD4`

```css
.btn-primary {
  height: 36px; padding: 0 14px; border-radius: 8px; border: none;
  background: var(--violet-60); color: var(--white);
  font-family: 'Poppins', sans-serif; font-size: 13px; font-weight: 500; cursor: pointer;
}
.btn-primary:hover { background: var(--violet-70); }

.btn-ghost {
  height: 36px; padding: 0 14px; border-radius: 8px;
  background: var(--white); color: var(--gray-70);
  border: 1px solid var(--gray-20);
  font-family: 'Poppins', sans-serif; font-size: 13px; font-weight: 500; cursor: pointer;
}
.btn-ghost:hover { background: var(--gray-10); border-color: var(--gray-30); }
```

### Tags / Badges

```
padding: 4px 8px; border-radius: 4px; font-size: 11px; font-weight: 500;
Small: padding: 3px 6px; font-size: 10px;
```

| Variant | Background | Text Color |
|---------|-----------|------------|
| Green | `#EDF8F3` | `#138656` |
| Red | `#FEE7EE` | `#C20A47` |
| Orange | `#FEF4E7` | `#C2750A` |
| Blue | `#E9EFFC` | `#133986` |
| Violet | `#F5EBFF` | `#4D0099` |
| Gray | `#F7F7F8` | `#576675` |
| Midnight | `#F2F3F7` | `#313981` |

```css
.badge {
  padding: 4px 8px; border-radius: 4px;
  font-size: 11px; font-weight: 500; display: inline-block;
}
.badge-sm { padding: 3px 6px; font-size: 10px; }
.badge-green { background: var(--green-10); color: var(--green-70); }
.badge-red { background: var(--red-10); color: var(--red-70); }
.badge-orange { background: var(--orange-10); color: var(--orange-70); }
.badge-blue { background: var(--blue-10); color: var(--blue-80); }
.badge-violet { background: var(--violet-10); color: #4D0099; }
.badge-gray { background: var(--gray-10); color: var(--gray-70); }
.badge-midnight { background: var(--midnight-10); color: var(--midnight-80); }
```

### Tables

| Property | Value |
|----------|-------|
| Border | `1px solid #E2E5E9` |
| Border-radius | `8px` |
| Border-collapse | `separate` (with `border-spacing: 0`) |
| Header bg | `#F7F7F8` |
| Header text | 11px uppercase Medium `#66788A`, letter-spacing 0.5px |
| Header padding | `10px 12px` |
| Row padding | `12px` |
| Row border | `border-bottom: 1px solid #E2E5E9` (none on last row) |
| Row hover | `background: #FAFAFA` |
| Cell font | 13px Regular `#08105E` |
| Sub-text | 11px Regular `#66788A` |

### Sidebar (154px)

| Element | Spec |
|---------|------|
| Logo icon | 28px square, `#8000FF` bg, 6px radius, white "T" |
| Logo text | "Traba", 14px SemiBold, `#08105E` |
| Section label | 10px uppercase, `#7A8A99`, letter-spacing 0.8px |
| Nav item | 13px Medium, `#576675`, 8px padding, 8px radius |
| Nav active | `background: #F5EBFF; color: #8000FF` |
| Nav hover | `background: #F7F7F8` |
| User avatar | 28px circle, `#F5EBFF` bg, `#8000FF` text |
| User name | 12px Medium `#08105E` |
| User role | 10px Regular `#66788A` |

### Topbar / Breadcrumb

| Element | Spec |
|---------|------|
| Height | 52px |
| Background | `#FFFFFF`, `border-bottom: 1px solid #E2E5E9` |
| Back icon | 24px, `#576675` (hover: `#8000FF`) |
| Breadcrumb parent | 14px Regular `#576675` |
| Breadcrumb current | 14px Medium `#08105E` |
| Chevron | SVG, `#C4CCD4` |
| Actions | Right-aligned buttons |

### Tab Bar

| Element | Spec |
|---------|------|
| Background | `#FFFFFF`, `border-bottom: 1px solid #E2E5E9` |
| Margin-top | 16px (gap below cards) |
| Tab padding | `10px 16px` |
| Tab font | 13px Medium |
| Inactive tab | `#66788A` |
| Active tab | `#8000FF`, `border-bottom: 2px solid #8000FF` |
| Count badge | 11px Regular `#B6BFC9` |

### Popovers / Tooltips

| Property | Value |
|----------|-------|
| Width | 240px |
| Background | `#FFFFFF` |
| Border | `1px solid #E2E5E9` |
| Radius | 8px |
| Shadow | `0 4px 12px rgba(0,0,0,0.08)` |
| Padding | 16px |
| Arrow | 8px rotated square, matching border/bg |
| Internal divider | `height:1px; background:#E2E5E9; margin:10px 0` |
| Header | Tag badge + date (10px `#7A8A99`) |
| Meta labels | 12px `#66788A` |
| Meta values | 12px `#576675` |
| Notes text | 12px `#08105E`, line-height 1.6 |
| Transcript | 11px `#576675`, timestamps `#8000FF` Medium |
| Checklist | 14px checkmark SVGs + 12px text |

### Stats Bar

| Property | Value |
|----------|-------|
| Background | `#F7F7F8` (the ONLY gray bg area) |
| Border-top | `1px solid #E2E5E9` |
| Layout | `grid-template-columns: 1fr 1fr 1fr` |
| Cell padding | `12–16px`, centered |
| Vertical divider | 1px `#E2E5E9` via `::before` |
| Value | 16px SemiBold |
| Label | 12px Regular `#576675` |

### Availability Dot Matrix

| Element | Spec |
|---------|------|
| Grid | `130px repeat(7, 1fr)` |
| Day headers | S M T W T F S, 12px Medium `#66788A`, centered |
| Time rows | Morning (4a–12p), Afternoon (12p–5p), Evening (5p–10p), Overnight (10p–4a) |
| Row label | 12px Regular `#576675` |
| Sub-label | 10px `#7A8A99` |
| Active dot | 8px circle `#8000FF` |
| Inactive dot | 4px circle `#C4CCD4` |

### Verification Pips

```
display: flex; gap: 3px;
Each pip: 18px × 4px, border-radius: 2px
Empty: #E2E5E9 | Green: #1AB273 | Orange: #F2930D | Red: #F20D59 | Violet: #8000FF
```

### Notes

| Property | Value |
|----------|-------|
| Background | `#F7F7F8` |
| Radius | 8px |
| Padding | `12px 14px` |
| Author | 12px Medium `#08105E` + role tag |
| Date | 11px Regular `#66788A` |
| Body | 13px Regular `#576675`, line-height 1.6 |

### Search Input

| Property | Value |
|----------|-------|
| Padding | `8px 12px` |
| Border | `1px solid #E2E5E9` (focus: `#8000FF`) |
| Radius | 8px |
| Width | 260px |
| Icon | 16px `#B6BFC9` |
| Text | 13px Regular `#08105E`, placeholder `#B6BFC9` |

### Toast

| Property | Value |
|----------|-------|
| Position | fixed, bottom 24px, right 24px |
| Background | `#08105E` |
| Text | `#FFFFFF`, 13px Medium |
| Padding | `12px 24px` |
| Radius | 10px |

### Custom Select Dropdowns

```css
.filter-select {
  border: 1px solid var(--gray-20); border-radius: 8px;
  padding: 7px 12px; padding-right: 28px;
  font-family: 'Poppins', sans-serif; font-size: 12px; color: var(--gray-70);
  appearance: none; cursor: pointer;
  background: var(--white) url("data:image/svg+xml,%3Csvg width='10' height='6' viewBox='0 0 10 6' fill='none' xmlns='http://www.w3.org/2000/svg'%3E%3Cpath d='M1 1L5 5L9 1' stroke='%23576675' stroke-width='1.5' stroke-linecap='round'/%3E%3C/svg%3E") no-repeat right 10px center;
}
.filter-select:focus { border-color: var(--violet-60); outline: none; }
```

---

## Layout Patterns

### Standard Dashboard (sidebar + topbar + scrollable main)

```css
.sidebar {
  position: fixed; left: 0; top: 0; bottom: 0;
  width: 154px; background: var(--white);
  border-right: 1px solid var(--gray-20);
  z-index: 100;
}
.topbar {
  position: fixed; left: 154px; top: 0; right: 0;
  height: 52px; background: var(--white);
  border-bottom: 1px solid var(--gray-20);
  z-index: 90; display: flex; align-items: center; padding: 0 24px;
}
.main {
  position: fixed; left: 154px; top: 52px; right: 0; bottom: 0;
  overflow-y: auto; background: var(--white); padding: 20px 24px;
}
```

### Three-Column Profile Header

For worker/entity detail pages, use a 3-card grid at top:

```css
.profile-header {
  display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 12px;
  padding: 20px 24px 0;
}
```

- **Card 1 (Identity)**: Avatar (80px, 12px radius) + name + tags + dates + rating + contact + demographics + stats bar at bottom
- **Card 2 (Account/Setup)**: Key-value rows with label left, value/tag right
- **Card 3 (Preferences)**: Toggle tabs + availability dot matrix + preference key-values + roles as tags

### Ops Layout with AI Side Panel

For dashboards with AI recommendations:

```css
.ops-layout { display: grid; grid-template-columns: 1fr 340px; gap: 20px; }
```

### Schedule Grid

For shift scheduling views:

```css
.schedule-grid {
  display: grid;
  grid-template-columns: 100px repeat(7, 1fr);
  gap: 1px; background: var(--gray-20);
}
.schedule-cell { background: var(--white); padding: 8px; min-height: 80px; }
```

### Zone Card Grid

For facility/operational views: 2-column grid with status cards per zone.

---

## Interactivity

### Tab Switching

Standard tab pattern with fade-up animation:

```css
@keyframes fadeUp {
  from { opacity: 0; transform: translateY(4px); }
  to { opacity: 1; transform: translateY(0); }
}
.tab-content { display: none; animation: fadeUp 0.2s ease; }
.tab-content.active { display: block; }
```

```js
function switchTab(tabName) {
  document.querySelectorAll('.tab-btn').forEach(t => t.classList.remove('active'));
  document.querySelectorAll('.tab-content').forEach(c => c.classList.remove('active'));
  document.querySelector(`[data-tab="${tabName}"]`).classList.add('active');
  document.getElementById(`tab-${tabName}`).classList.add('active');
}
```

### Toast Notifications

Toast pattern with auto-dismiss after 3–4 seconds:

```css
.toast {
  position: fixed; bottom: 24px; right: 24px;
  background: var(--midnight-100); color: var(--white);
  padding: 12px 24px; border-radius: 10px;
  font-size: 13px; font-weight: 500;
  transform: translateY(100px); opacity: 0;
  transition: all 0.3s ease; z-index: 999;
}
.toast.show { transform: translateY(0); opacity: 1; }
```

```js
function showToast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.classList.add('show');
  setTimeout(() => t.classList.remove('show'), 3500);
}
```

### Hover Micro-Interactions

- Shift blocks, zone cards, worker rows: lift on hover
  ```css
  .shift-block:hover { transform: translateY(-1px); box-shadow: 0 2px 8px rgba(0,0,0,0.06); }
  ```
- Table rows: `background: #FAFAFA` on hover
- Cards: `border-color: var(--gray-30)` on hover
- Edit buttons: `border-color: var(--violet-60); color: var(--violet-60)` on hover

### Expandable Rows / Slide-In Panels

For detail views, use slide-in panels from the right:

```css
.slide-panel {
  position: fixed; top: 0; right: -420px; bottom: 0;
  width: 420px; background: var(--white);
  border-left: 1px solid var(--gray-20);
  box-shadow: -4px 0 16px rgba(0,0,0,0.06);
  transition: right 0.3s ease; z-index: 200;
}
.slide-panel.open { right: 0; }
.overlay {
  position: fixed; inset: 0; background: rgba(0,0,0,0.15);
  z-index: 199; display: none;
}
```

### Collapsed Attribute Rows

```css
.collapsed-row {
  background: var(--gray-10); cursor: pointer;
  font-size: 12px; color: var(--gray-60); padding: 8px 12px;
}
.collapsed-row:hover { background: var(--midnight-10); }
```

Content: chevron-down icon (14px) + "X attributes with no data" text.

### Live Pulse Indicator

For real-time dashboards:

```css
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.4; }
}
.live-dot {
  width: 8px; height: 8px; border-radius: 50%;
  background: var(--green-60); animation: pulse 2s infinite;
}
```

---

## Data Visualization

For lightweight charts, use inline SVG. For complex dashboards, chart libraries are fine.

### Line Charts

```html
<svg viewBox="0 0 300 100" style="width:100%;height:100px;">
  <polyline points="0,80 50,60 100,45 150,55 200,30 250,20 300,25"
    fill="none" stroke="#8000FF" stroke-width="2" stroke-linecap="round"/>
  <!-- Optional fill area -->
  <polygon points="0,80 50,60 100,45 150,55 200,30 250,20 300,25 300,100 0,100"
    fill="#8000FF" fill-opacity="0.08"/>
</svg>
```

### Bar Charts

```html
<svg viewBox="0 0 200 80" style="width:100%;height:80px;">
  <rect x="10" y="20" width="20" height="60" rx="3" fill="#8000FF" opacity="0.8"/>
  <rect x="40" y="35" width="20" height="45" rx="3" fill="#8000FF" opacity="0.6"/>
  <!-- ... more bars -->
</svg>
```

### Donut Charts

```html
<svg viewBox="0 0 36 36" style="width:64px;height:64px;">
  <circle cx="18" cy="18" r="15.9" fill="none" stroke="#E2E5E9" stroke-width="3"/>
  <circle cx="18" cy="18" r="15.9" fill="none" stroke="#8000FF" stroke-width="3"
    stroke-dasharray="75, 25" stroke-dashoffset="25" stroke-linecap="round"/>
  <text x="18" y="20" text-anchor="middle" font-size="8" font-weight="600"
    fill="#08105E">75%</text>
</svg>
```

### Progress Bars

```css
.progress-bar {
  height: 6px; background: var(--gray-20); border-radius: 3px; overflow: hidden;
}
.progress-fill { height: 100%; border-radius: 3px; }
/* Color by status: */
.fill-green { background: var(--green-60); }
.fill-orange { background: var(--orange-60); }
.fill-red { background: var(--red-60); }
.fill-violet { background: var(--violet-60); }
```

### Heatmaps

CSS grid with cells colored by intensity:

```css
.heatmap { display: grid; grid-template-columns: repeat(7, 1fr); gap: 2px; }
.heat-cell { width: 100%; aspect-ratio: 1; border-radius: 2px; }
/* Intensity levels: */
.heat-0 { background: var(--gray-10); }
.heat-1 { background: #E6CCFF; }
.heat-2 { background: #BF80FF; }
.heat-3 { background: #8000FF; }
```

### Gantt-Style Timelines

Absolute-positioned bars within a relative container:

```css
.gantt-row { position: relative; height: 28px; margin-bottom: 4px; }
.gantt-bar {
  position: absolute; top: 4px; height: 20px; border-radius: 4px;
  font-size: 10px; color: var(--white); padding: 0 6px;
  display: flex; align-items: center;
}
.gantt-completed { background: var(--green-60); }
.gantt-in-progress { background: var(--violet-60); }
.gantt-upcoming { background: var(--gray-20); color: var(--gray-60); }
```

### Bell Curves / Distributions

SVG path with fill gradient:

```html
<svg viewBox="0 0 200 80" style="width:100%;height:80px;">
  <defs>
    <linearGradient id="bellGrad" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0%" stop-color="#8000FF" stop-opacity="0.2"/>
      <stop offset="100%" stop-color="#8000FF" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <path d="M0,80 C40,78 60,10 100,10 C140,10 160,78 200,80 Z" fill="url(#bellGrad)"/>
  <path d="M0,80 C40,78 60,10 100,10 C140,10 160,78 200,80" fill="none" stroke="#8000FF" stroke-width="2"/>
</svg>
```

---

## Content Guidelines

### Realistic Traba Data

Use data that reflects Traba's warehouse staffing business:

| Category | Examples |
|----------|----------|
| **Roles** | Picker, Packer, Forklift Operator, Dock Worker, QC Inspector, Reach Truck Operator, Returns Processor |
| **Facilities** | "Warehouse A - Newark", "DC East - Edison", "Fulfillment Center - Cranbury" |
| **KPIs** | Pick rate: 120–160 units/hr, Fill rate: 85–98%, Attendance: 90–99%, Labor cost/unit: $0.30–0.60 |
| **Certifications** | Forklift, OSHA 10/30, Food Handler, Hazmat, First Aid/CPR |
| **Shifts** | Morning (6a–2p), Afternoon (2p–10p), Night (10p–6a), Flex (varies) |

### Worker Type Differentiation

Always visually distinguish worker types:

| Type | Badge Color | Border Color | Usage |
|------|------------|-------------|-------|
| FT Employee | Blue tint (`--blue-10` / `--blue-80`) | `--blue-60` left border | Full-time warehouse staff |
| Traba Temp | Violet tint (`--violet-10` / `#4D0099`) | `--violet-60` left border | Workers from Traba platform |
| Other Agency | Gray tint (`--gray-10` / `--gray-70`) | `--gray-40` left border | Third-party agency workers |

Use `border-left: 3px solid [color]` on shift blocks and cards to indicate worker type.

### Shift Blocks

```css
.shift-block {
  padding: 6px 8px; border-radius: 6px; border-left: 3px solid;
  font-size: 12px; margin-bottom: 4px; cursor: pointer;
  transition: transform 0.15s ease, box-shadow 0.15s ease;
}
```

Show: worker name, time range, and a small status badge.

### AI Recommendations

When showing AI-generated insights:
- Show confidence scores (e.g., "92% confidence")
- Include specific numbers ("saves 12 min/worker/shift")
- Provide actionable buttons (Apply / Dismiss)
- Add operational context ("Based on last 30 days of camera data")
