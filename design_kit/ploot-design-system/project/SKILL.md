---
name: ploot-design
description: Use this skill to generate well-branded interfaces and assets for Ploot, either for production or throwaway prototypes/mocks/etc. Contains essential design guidelines, colors, type, fonts, assets, and UI kit components for prototyping.
user-invocable: true
---

Read the README.md file within this skill, and explore the other available files.

Ploot is a warm, playful, witty task-management mobile app. The system is built around:
- Clay-orange primary (`#ff6b35`) on warm cream backgrounds
- Bold 2px dark-ink hairlines everywhere — nothing pure black
- Signature "pop" shadow (`0 2px 0 ink`) that collapses on press
- Fraunces serif for display, Geist sans for UI, JetBrains Mono for meta
- Springy micro-animations (cubic-bezier(0.34, 1.56, 0.64, 1))
- Witty-irreverent copy — second person, contractions, parentheticals

**Essential files to read:**
- `README.md` — brand voice, visual foundations, iconography, content rules
- `colors_and_type.css` — all CSS variables (colors, radii, shadows, spacing, motion, type)
- `ui_kits/mobile/` — interactive React JSX components you can copy/adapt
- `assets/` — logo, mascot, illustrations, pattern

**When creating visual artifacts** (slides, mocks, throwaway prototypes):
- Link `colors_and_type.css` and use the CSS variables (`var(--primary)`, `var(--fg1)`, `var(--shadow-pop)` etc.)
- Copy needed SVGs out of `assets/` into your output folder
- Follow the voice rules: lowercase casual meta, witty empty states, period over exclamation point

**When working on production code:**
- Mirror the component patterns in `ui_kits/mobile/Primitives.jsx` (Button, Checkbox, Field, Card, Chip)
- Keep 2px ink borders + pop shadow for anything tappable
- Use Lucide icons at stroke 2

**If the user invokes this skill without guidance:** ask them what they want to build or design, ask a couple of clarifying questions (audience, surface, level of fidelity), then act as an expert designer who outputs HTML artifacts or production code depending on the need.
