# Claude Code — working notes for Ploot

This file is loaded into Claude's context whenever it opens this repo. Keep it short, factual, and focused on things that would trip up a new session.

## What this project is

Native iOS task manager in **SwiftUI**, iOS 17+. Warm/playful brand: clay orange on cream, Fraunces serif + Geist sans, stamped shadows, bouncy springs. Two themes — **Light** (cream) and **Cocoa** (warm chocolate, not black). Owner writes Expo/React Native day-to-day and is new to native iOS.

## Repo layout

```
Ploot/
├── PlootApp.swift           @main, registers fonts
├── Info.plist               UIAppFonts + launch config
├── DesignSystem/            Tokens (Theme.swift, Typography.swift) + modifiers
├── Components/              Shared UI primitives (Checkbox, TaskRow, TabBar, FAB, Chip, ...)
├── Screens/                 Full-screen views (Today/Projects/Calendar/Done/TaskDetail + TestScreen)
├── Features/
│   ├── Home/HomeView.swift  Root NavigationStack + tab + FAB + sheets
│   └── QuickAdd/
├── Models/                  PlootTask, PlootProject, TaskStore (@Observable), DemoData
└── Resources/
    ├── Fonts/               Fraunces / Geist / JetBrainsMono variable TTFs
    └── Assets.xcassets/

design_kit/ploot-design-system/   Source-of-truth brief: CSS tokens, preview HTMLs, React kit
```

`design_kit/` is the **spec**. When unsure about a component's visual or behavior, open the matching `preview/*.html` or `ui_kits/mobile/*.jsx` — don't guess.

## Build + run

- Xcode 16+ (tested on 26.2). iOS 17.0 deployment target.
- `xcodebuild -project Ploot.xcodeproj -scheme Ploot -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build` — the standard non-signing check; run this after any Swift change.
- On-device runs use free Apple ID signing. Owner uses physical iPhone, not simulator (Mac is slow under simulator load). UI verification happens on-device.

## Non-obvious design-system rules

These bite you if you don't know them.

### The stamped shadow is NOT `.shadow(…)`

`.shadow()` blurs — never use it for elevated surfaces. The brand signature is `box-shadow: 0 2px 0 var(--border-ink)` — a hard-edge block of the border-ink color offset 2pt below. Implementation lives in `StampedShadow.swift` and uses a `RoundedRectangle.offset(y: 2)` behind the view. Press states collapse the offset to 0 *and* translate the view down 2pt so the lip disappears underneath.

Use the soft `.shadow()` modifier **only** for the `shadow-xs/sm/md/lg` tiers (menus, modals) — never on cards/buttons/chips. Those are always stamped.

### Every elevated surface has a 2pt ink hairline

`palette.borderInk`, not system black. On cocoa it's `#1A1008` — still a warm near-black. Cards, buttons, FAB, tiles, pickers — all 2pt `.strokeBorder` outside, stamped shadow behind.

### Variable-font axes are set explicitly

Fraunces is registered with `opsz` + `wght` (and `SOFT` when the shipping TTF exposes it). Set via `UIFontDescriptor` + `kCTFontVariationAttribute` in `Typography.swift`. Don't use `.font(.custom("Fraunces", size:))` — that loses the axis control and makes display sizes look flat. Use `Font.fraunces(size:weight:opsz:soft:)`.

The Google-Fonts woff2 that ships in `design_kit/fonts/` is the **subsetted** Fraunces — only `wght` + `opsz` axes. `SOFT` is silently ignored by CoreText. If the kit ever swaps in full Fraunces, SOFT lights up automatically.

### Fonts register twice on purpose

`UIAppFonts` in `Info.plist` + runtime `CTFontManagerRegisterFontsForURL` in `PlootFonts.register()`. The runtime call is the backstop for SwiftUI Previews and snapshot tests where `UIAppFonts` doesn't always kick in. The duplicate produces a `GSFont: file already registered` log — that's expected; don't "fix" it by removing one.

### Chip colors must be theme-aware

Light-mode pastel fills (`clay100` etc.) look correct on cream but collapse into the cocoa chocolate canvas. `Chip.resolvedPalette()` branches on `@Environment(\.plootTheme)` — light uses prebuilt `-100` tokens; cocoa uses a ~20–25% opacity wash of the saturated accent with the `-100`/`-300` shade as foreground. `CalendarSlotTint` in `CalendarScreen.swift` follows the same pattern. **Never use `accent.opacity(0.22)` on cream** — it muddies to brown.

### SF Symbol filled variants aren't universal

Some symbols (e.g. `calendar`) have no `.fill` variant. The `PlootTab.icon` helper returns `(inactive, active)` name pairs so we can substitute `calendar.circle.fill` etc. Don't assume `"\(name).fill"` works — check on Apple's SF Symbols app first.

### TabBar uses `.safeAreaInset`, not manual bottom padding

`HomeView` attaches TabBar via `.safeAreaInset(edge: .bottom)`. TabBar itself should add minimal bottom padding (`Spacing.s1`), NOT 24pt — otherwise it stacks with the inset and floats too high on the home indicator.

### Springs: bouncy, not stiff

All motion uses `Motion.spring` (response 0.38, damping 0.62) or `Motion.springFast`. The brand is playful; do not use `.linear` or tight-damping springs for UI state. Press-collapse animations on buttons use `Motion.springFast`. Tab-icon scale uses `Motion.spring`.

## Content + tone rules

These come from `design_kit/README.md` and must be honored in any user-facing copy generated for this app:

- **Second person.** "What's next?" not "Add a new task."
- **Contractions always.** "You've earned it." "Don't break it."
- **Lowercase casual meta** ("3 of 6 crushed. keep going."). Title Case only for screen titles.
- **Period over exclamation point.** Confident, not desperate.
- **Parentheticals for warmth.** "Buy more oat milk (again)." "Go for a walk (a real one)."
- **Emoji sparingly, purposefully.** Projects use emoji 💼🏡🚀🛒📚. Urgent tasks show 🔥. Streak card is 🔥. Not decorative.
- **Empty states are jokes.** "Nothing on the list. Suspicious." "Take a victory lap — you've earned it."

## Haptics

Every interactive element gets `.sensoryFeedback` — not optional. Use `.selection` for toggles/taps, `.impact(.light)` for button press, `.impact(.medium)` for FAB, `.success` for check-off. This is part of the brand feel.

## Models + state

- `TaskStore` is `@Observable` (iOS 17 macro, not `ObservableObject`). Views hold it via `@Bindable var store: TaskStore`.
- Pass the store down as a parameter, not via `@EnvironmentObject`. Screens are explicitly typed on what they need.
- No persistence yet — seed data in `DemoData.swift`. TODO: SwiftData when that lands.

## Things deliberately not in scope yet

- Persistence (SwiftData)
- Real auth / iCloud sync
- Onboarding flow
- Widgets
- Settings beyond theme switcher + test-screen link
- Reminders system integration
- Push notifications

Don't add scaffolding for these speculatively. Add them when the user asks.

## Git + commits

- Small, scoped commits with conventional-commit prefixes: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`. See existing log for style.
- `main` is the working branch. Push to `origin main` on github.com/Byk3y/ploot.
- Do **not** rewrite history on commits the owner wrote (e.g. the original `Initial Commit`). Layer on top.

## Useful one-liners

```bash
# Fast build check (no signing)
xcodebuild -project Ploot.xcodeproj -scheme Ploot \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build 2>&1 | grep -E "(error:|BUILD )" | head -10

# Re-convert fonts from the kit (if design_kit/fonts/ changes)
python3 -c "
from fontTools.ttLib import TTFont
for f in ['Fraunces-Variable','Geist-Variable','JetBrainsMono-Variable']:
    t = TTFont(f'design_kit/ploot-design-system/project/fonts/{f}.woff2')
    t.flavor = None
    t.save(f'Ploot/Resources/Fonts/{f}.ttf')
"
```

## When in doubt

1. Open the matching file in `design_kit/ploot-design-system/project/preview/` (static HTML) or `ui_kits/mobile/*.jsx` (interactive React).
2. Match the CSS spec exactly — radii, padding, border widths, animation durations.
3. Prefer native SwiftUI patterns over re-inventing web idioms. The sheet is `.sheet` with `presentationCornerRadius`, not an absolute overlay. Nav is `NavigationStack`, not custom transitions.
