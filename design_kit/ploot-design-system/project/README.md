# Ploot Design System

> A warm, playful, witty task-management app. Clay-orange on cream. Fraunces serif meets Geist sans. Bold dark hairlines, stamped shadows, bouncy micro-animations.

**Project context:** this design system was invented from scratch for a task-management mobile app. No existing brand materials were provided — the user asked for a playful & human personality with witty-irreverent copy, and said they love micro-animations on mobile. Direction was chosen from visual vibes 3 & 4 (bold mono + warm clay blocks), primary = clay orange (`#ff6b35`), both light and dark themes.

**Brand name:** Ploot — short, friendly, a little absurd. Mascot is a round orange blob with a sprout-antenna holding a to-do list.

---

## Visual Foundations

**Color palette**
- **Clay** (`--ploot-clay-*`, 50→900): signature warm orange. `--ploot-clay-500 #ff6b35` is the primary accent.
- **Ink** (`--ploot-ink-*`): warm near-blacks. `--ploot-ink-800 #1a1410` is the signature dark-hairline border color — never pure black.
- **Forest** green: success, completed tasks.
- **Butter** yellow: highlights, stars, note cards, joyful moments.
- **Plum** magenta: urgent priority, danger.
- **Sky** blue: info, links, work-project accent.

Backgrounds are warm cream (`--ploot-ink-50 #faf8f5`), never stark white.

**Typography**
- **Fraunces** (variable, serif) — display, headings, detail-screen titles, dates with italic flourish. Uses `SOFT` axis for warmth.
- **Geist** (variable, sans) — UI, body, buttons, task titles.
- **JetBrains Mono** — eyebrows, meta counts, timestamps, labels. Always uppercase + wide tracking.

Display sizes go big (42–56px on detail screens). Body is 15px. Minimum text 11px eyebrows.

**Borders & shapes**
- Radii: 6 / 10 / 14 / 20 / 28 / full. Most UI uses 14 (cards, buttons, inputs) or 20 (big cards).
- Borders are **thick (2px) and dark** (`--border-ink`). This is the system's signature move — everything feels a little stamped.
- The **"pop" shadow** (`--shadow-pop: 0 2px 0 var(--border-ink)`) is a hard-edge offset, not a soft shadow. It looks like the element was stamped down onto the page. Press states collapse it (`translateY(2px)` + remove shadow).

**Motion**
- `--ease-spring: cubic-bezier(0.34, 1.56, 0.64, 1)` — springy overshoot. Used for check-marks, FAB press, tab icons.
- `--ease-out` for fades. Most animations 140–380ms.
- Checkbox check draws the tick stroke with a scale+rotate bounce and a success ring that expands & fades.
- Tab icons scale to 1.1 when active. Cards lift `translateY(-2px)` on hover.
- Nothing instant, nothing over 400ms.

**Surfaces**
- `--bg` cream → `--bg-elevated` pure white for cards → `--bg-sunken` slightly darker cream for inputs/meta bars.
- Cards always have a dark hairline border. Shadows stack: xs/sm/md/lg (soft) + pop (signature hard).

**Imagery**
- Hand-drawn SVG illustrations for empty states (all-done flag, napping cat on empty tray).
- Doodle pattern for brand backgrounds (checks, squiggles, sparkles).
- No photography in the current system.

**Transparency & blur**
- Used only for modal backdrops (`rgba(26,20,16,0.4)` + `blur(6px)`).
- Not used for glass nav bars; the bottom tab bar is opaque with a 2px ink top border.

**Hover & press**
- Hover: `translateY(-2px)` + larger pop shadow.
- Press: `translateY(+2px)` + collapse shadow to zero. Feels like a physical button being mashed.

---

## Content Fundamentals

**Tone:** witty, irreverent, human. Every empty state is a joke. Every meta line has personality.

**Voice rules**
- Second person. "What's next?" not "Add a new task."
- Contractions always. "You've earned it." "Don't break it."
- Parentheticals for warmth. "Buy more oat milk (again)." "Go for a walk (a real one)."
- Lowercase for casual meta ("3 of 6 crushed. Keep going."); Title Case only for screen titles.

**Examples**
- Today subtitle when list is empty: *"Nothing on the list. Suspicious."*
- All-done empty state: *"You finished today's list. Take a victory lap — you've earned it."*
- Streak card: *"7 day streak · don't break it"*
- Add-task sheet title: *"What's next?"*
- Placeholder: *"Water the mysterious plant"*
- Done tab subtitle: *"12 this week. Look at you go."*

**Emoji:** yes, but sparingly and purposefully. Project chips use emoji (💼 🏡 🚀 🛒 📚). Streak card uses 🔥. Task rows show 🔥 next to urgent items. Not used decoratively in body copy.

**Sentence endings:** short. Periods over exclamation points (we're confident, not desperate).

---

## Iconography

**Primary icon set: Lucide** — loaded from CDN (`https://unpkg.com/lucide@latest`). Stroke 2, 24px default grid. Used for all UI icons: tab bar, buttons, detail-row icons, field affixes.

⚠️ **Substitution flag:** no icon set was provided; Lucide was chosen as the closest match for the warm/rounded feel at stroke-2. If you have a preferred icon library, swap via `Icon` component in `Primitives.jsx`.

**Emoji** are used as project-category markers (inside colored project tiles) and as reactions (🔥 for urgent, streak). Not for generic UI.

**Custom SVG** is reserved for:
- Brand marks (`assets/logo-mark.svg`, `assets/logo-wordmark.svg`)
- Mascot (`assets/mascot-ploot.svg`)
- Empty-state illustrations (`assets/illo-*.svg`)
- Patterns (`assets/pattern-doodles.svg`)
- Inline checkmark animation (hand-drawn in `Primitives.jsx` for stroke-dash animation control)

**Unicode chars** are used for very small dividers (middle-dot `·`) in subtitles.

---

## Fonts — substitution note

⚠️ **All three fonts are Google Fonts.** No custom/licensed fonts were provided; these are the closest "warm + playful + readable" stack matches:
- **Fraunces** — variable serif with a SOFT axis, matches the playful-serif direction
- **Geist** — modern geometric sans, sharp but warm
- **JetBrains Mono** — for mono accents

If there's a preferred type system, drop woff2 files into `fonts/` and update `colors_and_type.css` `@font-face` blocks.

---

## Index — what's in this repo

**Root**
- `README.md` — this file
- `SKILL.md` — Claude Code / skill-compatible entry point
- `colors_and_type.css` — all CSS variables + base type scale

**`fonts/`** — woff2 variable files for Fraunces, Geist, JetBrains Mono

**`assets/`** — SVG logos, mascot, illustrations, pattern

**`ui_kits/mobile/`** — the interactive mobile app UI kit
- `index.html` — renders 4 device frames (Today, Projects, Calendar, Done)
- `App.jsx`, `Screens.jsx`, `Composites.jsx`, `Primitives.jsx` — components
- `ios-frame.jsx` — iOS device chrome

**`preview/`** — Design-System-tab preview cards (type, colors, shadows, radii, components, brand)
