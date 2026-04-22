# Ploot

> A warm, playful, witty task-management app for iOS. Clay-orange on cream. Fraunces serif meets Geist sans. Bold dark hairlines, stamped shadows, bouncy micro-animations.

Ploot is a native iOS task manager built in SwiftUI with a hand-crafted design system. Two themes (Light cream canvas + Cocoa chocolate), variable fonts with custom axes (Fraunces SOFT + opsz, Geist wght), and a signature stamped-shadow visual language that makes every elevated surface feel pressed onto the page.

## Status

**Phase 2 complete.** All core screens and interactions are in. Tasks are held in memory via an `@Observable` store — no backend yet.

- Today, Projects, Calendar, Done, TaskDetail screens
- Hero checkbox with spring bounce + stroke-draw + success ring
- Bottom TabBar with springy active-icon scale
- FAB + QuickAdd bottom sheet (title, note, NLP hints, date/time/project/priority pickers, subtasks)
- Light + Cocoa themes, swap via Settings

## Requirements

- macOS with Xcode **16.0** or later (tested on Xcode 26.2)
- iOS **17.0** deployment target (uses `@Observable`, `.sensoryFeedback`, `.safeAreaInset`, `Layout` protocol)
- A free or paid Apple Developer account for on-device runs

## Getting started

```bash
git clone https://github.com/<your-user>/ploot.git
cd ploot
open Ploot.xcodeproj
```

In Xcode:

1. Select the **Ploot** target → **Signing & Capabilities** → tick **Automatically manage signing** and pick your team.
2. Change the bundle identifier to something unique (e.g. `com.yourname.ploot`) if Xcode complains it's taken.
3. Pick your iPhone or a simulator in the device picker.
4. Hit ⌘R.

On first launch on a physical device: Settings → General → VPN & Device Management → trust your developer certificate.

## Project structure

```
Ploot/
├── PlootApp.swift             # @main entry, registers fonts
├── Info.plist                 # UIAppFonts, launch config
│
├── DesignSystem/
│   ├── Theme.swift            # All CSS tokens → Swift: palette, radii, shadows, spacing, motion
│   ├── Typography.swift       # Fraunces/Geist/JetBrainsMono variable axes + text styles
│   └── Modifiers/
│       ├── StampedShadow.swift   # Signature hard-offset shadow (not SwiftUI's blurred shadow)
│       ├── CardStyle.swift        # bg fill + 2pt ink border + stamped shadow
│       └── PlootButtonStyle.swift # Primary/secondary/ghost/danger variants with press collapse
│
├── Components/
│   ├── PlootCheckbox.swift    # The hero interaction — spring bounce, stroke draw, success ring
│   ├── TaskRow.swift          # Checkbox + title + meta (due/project/tags) + urgent flame
│   ├── TabBar.swift           # 4-tab bottom nav with active-icon scale
│   ├── FAB.swift              # 60pt clay circle with press collapse
│   ├── ScreenFrame.swift      # Shared title/subtitle/leading/trailing header
│   ├── SectionHeader.swift    # Sticky mono eyebrow with count badge
│   ├── EmptyState.swift       # Illustration + title + subtitle
│   ├── Chip.swift             # Pill with 6 color palettes, theme-aware for legibility
│   ├── ProgressBar.swift      # Pill progress bar with ink hairline
│   └── PlootToggle.swift      # iOS toggle reshaped to match the kit
│
├── Screens/
│   ├── TodayScreen.swift      # Progress bar, overdue/today/later sections, empty state
│   ├── ProjectsScreen.swift   # Emoji-tile cards with mini progress bars
│   ├── CalendarScreen.swift   # Day scrubber + 5-slot timeline with tinted cards
│   ├── DoneScreen.swift       # Streak card, weekly bar chart, recent-crushed list
│   ├── TaskDetailScreen.swift # Big Fraunces title, chip flow, note card, subtasks, meta footer
│   └── TestScreen.swift       # Phase 1 design-token regression screen (accessible via Settings)
│
├── Features/
│   ├── Home/HomeView.swift    # NavigationStack root, TabBar, FAB, sheet wiring
│   └── QuickAdd/QuickAddSheet.swift  # Title+note, NLP hints, date/time/project/priority/subtasks
│
├── Models/
│   ├── Task.swift             # PlootTask, Subtask, Priority, TaskSection
│   ├── Project.swift          # PlootProject, ProjectTileColor (palette-resolving)
│   ├── TaskStore.swift        # @Observable store
│   └── DemoData.swift         # Seed tasks + projects
│
└── Resources/
    ├── Fonts/                 # Fraunces / Geist / JetBrainsMono variable TTFs
    └── Assets.xcassets/
```

## Design system

The design system lives in `design_kit/ploot-design-system/` in this repo (extracted from the original brief archive). When in doubt about a component's behavior or visual spec, open the matching `preview/*.html` or `ui_kits/mobile/*.jsx` — those are the source of truth.

### Signature moves

- **Stamped shadow** — `0 2px 0 var(--border-ink)`. A hard-edge color block offset down by 2pt, never a blur. Implemented via `RoundedRectangle.offset(y: 2)` behind the content. Press states collapse the offset to 0 and translate the element down 2pt.
- **Dark hairlines** — 2pt `borderInk` on every elevated surface. Warm near-black (`#1A1410`), never pure black.
- **Warm cream canvas** — `#FAF8F5` base in Light, `#3A2A20` chocolate in Cocoa.
- **Variable-font axes** — Fraunces `opsz` and (when available) `SOFT` set explicitly via `UIFontDescriptor` + `kCTFontVariationAttribute`. Display sizes use `SOFT 50, opsz 144` for playful warmth.
- **Bouncy, never stiff** — all motion uses spring animations with damping ~0.62. The brand is playful, not corporate.

### Tone

Witty, irreverent, human. Second person, contractions always, lowercase casual meta, period over exclamation point. Empty states are jokes.

## Tech

- **SwiftUI**, iOS 17+
- **`@Observable`** for state
- **`NavigationStack`** + `.navigationDestination(item:)`
- **`Layout` protocol** for custom flow wrapping (task detail chip row)
- **`.sensoryFeedback`** for haptics on every interactive element
- **Variable TTF fonts** registered via both `UIAppFonts` and `CTFontManagerRegisterFontsForURL` at runtime

## What's next

- Local persistence (SwiftData or Codable → Application Support)
- Real streak / weekly-count math
- Settings screen with full profile
- Onboarding flow
- Widgets (Home Screen + Lock Screen)
- iCloud sync

## Credits

Design system and brand (Ploot mascot, color palette, tone guide) were generated from a single creative brief and are shipped alongside the app code in `design_kit/`. Fonts are from Google Fonts (Fraunces, Geist, JetBrains Mono) — all under the SIL Open Font License.

## License

TBD — set this before pushing public.
