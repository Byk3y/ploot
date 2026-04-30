# AGENTS.md

Project instructions for Codex when working in this repository. Keep this file factual, current, and focused on decisions that would trip up a new coding session.

## What This Project Is

Ploot is a native iOS app built with SwiftUI for breaking projects into small achievable tasks. It is not meant to become a generic day-to-day calendar or life planner.

Brand feel: warm, playful, premium, and tactile. The visual language is clay orange on cream, Fraunces serif plus Geist sans, hard stamped shadows, 2 pt ink borders, bouncy springs, haptics, and two themes: Light cream and Cocoa warm chocolate.

The owner writes Expo/React Native day-to-day and is newer to native iOS, so explain native iOS tradeoffs clearly when they matter.

## Operating Principles

- Do the complete useful version of the requested work. Avoid leaving TODOs, dead branches, unused parameters, stale comments, or half-finished sibling cases.
- Fix the real cause when it is in scope. Do not present a workaround as the solution.
- Search before building. Use `rg`, open the existing component, and follow local patterns before adding a new abstraction.
- Treat `design_kit/` as the design source of truth. When unsure, open the matching `preview/*.html` or `ui_kits/mobile/*.jsx`.
- Build after Swift changes with the standard `xcodebuild` command below.
- A clean build is not a visual verification. For UI, layout, motion, safe-area, overlay, or navigation changes, ask the owner to verify on physical iPhone.
- Self-review non-trivial diffs before saying done. Trace callers, edge cases, repeated invocations, empty inputs, time zones, and reversed states.
- Do not reflexively delegate review work. Use subagents only when explicitly requested or when a genuinely parallel, bounded task materially helps.

## Repo Layout

```text
Ploot/
├── PlootApp.swift           @main, registers fonts
├── Info.plist               UIAppFonts + launch config
├── DesignSystem/            Tokens, typography, modifiers
├── Components/              Shared UI primitives
├── Screens/                 Full-screen views
├── Features/
│   ├── Home/HomeView.swift  Root NavigationStack, tabs, FAB, sheets
│   └── QuickAdd/
├── Models/                  SwiftData models, demo data
└── Resources/
    ├── Fonts/               Fraunces, Geist, JetBrains Mono variable TTFs
    └── Assets.xcassets/

design_kit/ploot-design-system/   Source-of-truth brief, CSS tokens, previews, React kit
supabase/functions/               Edge functions
supabase/migrations/              Checked-in database migrations
```

## Build And Run

- Xcode 16+; iOS 17.0 deployment target.
- Run this after Swift changes:

```bash
xcodebuild -project Ploot.xcodeproj -scheme Ploot -destination 'generic/platform=iOS Simulator' -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

- The owner verifies UI on a physical iPhone. Do not claim a visual or motion change is confirmed until the owner has tested it.

## Design System Rules

### Stamped Shadows

Never use SwiftUI `.shadow()` for cards, buttons, chips, FABs, or elevated brand surfaces. The brand shadow is a hard stamped offset: `0 2px 0 var(--border-ink)`. In Swift, use the existing stamped-shadow implementation built with an offset rounded rectangle behind the view.

Use soft `.shadow()` only for true soft elevation tiers such as menus or modals.

### Ink Borders

Every elevated surface uses a 2 pt `palette.borderInk` hairline, not system black. Cocoa mode still uses warm near-black, not pure black.

### Typography

Fraunces variable axes are set explicitly through `Typography.swift`. Do not use plain `.font(.custom("Fraunces", size:))`; use the existing `Font.fraunces(...)` helpers so weight, optical size, and softness stay correct.

Fonts are registered through both `UIAppFonts` and runtime registration in `PlootFonts.register()`. Duplicate registration logs are expected.

### Colors

Chip and timeline colors must be theme-aware. Light-mode pastel fills do not translate directly to Cocoa. Follow `Chip.resolvedPalette()` and `CalendarSlotTint` patterns.

Do not use `accent.opacity(0.22)` on cream surfaces for chips; it muddies the palette.

### SF Symbols

Filled variants are not universal. Use the existing `PlootTab.icon` pattern for inactive and active symbol names instead of assuming `"\(name).fill"` exists.

### Tab Bar And Safe Areas

`HomeView` attaches `TabBar` with `.safeAreaInset(edge: .bottom)`. The tab bar should add only minimal bottom padding. Avoid manual large bottom padding that stacks with the safe-area inset.

When a floating element should stop at a container edge rather than the screen edge, apply `.overlay` to the content container before `.safeAreaInset`.

## Motion

Motion is part of Ploot's product personality. Prefer native, tasteful spring motion for meaningful state changes.

- Default to `Motion.spring` or `Motion.springFast`.
- Avoid `.linear` and overly stiff springs for UI state.
- Animate state transitions: done/undone, filter in/out, expand/collapse, appear/dismiss, list insertion/removal.
- Do not animate every paint tick or every tap in a way that makes the app feel busy.
- For list removals after completion, prefer the existing predictive visual plus delayed mutation plus exit transition pattern used by `TaskRow.handleToggle`.
- Build success does not prove motion feels right. Ask the owner to check motion on-device.

Be careful with root-level animations on navigation or tab content. Local icon or row animations are good; animating full tab replacement can cause old screens to flash behind new ones.

## Content And Tone

Use the tone rules from `design_kit/README.md` for any user-facing copy:

- Second person.
- Use contractions.
- Lowercase casual meta text; reserve Title Case for screen titles.
- Prefer periods over exclamation points.
- Parentheticals are allowed for warmth.
- Emoji sparingly and purposefully.
- Empty states should feel witty and human.

## Haptics

Interactive elements should use `.sensoryFeedback` where appropriate.

- `.selection` for toggles and taps.
- `.impact(.light)` for normal button press.
- `.impact(.medium)` for FAB.
- `.success` for check-off.

## SwiftData And State

- Views use `@Query` directly where possible.
- Use `@Observable` for local state holders when needed; do not default to `ObservableObject`.
- Mutate SwiftData through `@Environment(\.modelContext)`.
- Seed demo data through `DemoData.seedIfNeeded(context:)`; it should remain idempotent.

### Adding Fields To Existing Models

For new fields on existing `@Model` types, prefer optional properties unless you also add an explicit migration plan. SwiftData lightweight migration can crash when a new non-optional column has no value for existing rows.

Set defaults in initializers for fresh rows, and treat `nil` as "not set before this field existed" at read time.

## Supabase

Project ref: `rnlzqlocipeecbejyutv`.

- Migrations live in `supabase/migrations/*.sql`.
- Edge functions live in `supabase/functions/`.
- If you add or change a SwiftData model field that is synced to Supabase, also add the matching database migration.
- DB uses `snake_case`; Swift uses `camelCase`. Bridge with Codable coding keys or client configuration.
- RLS is expected on `public.*` tables. Service-role inspection can see more than the iOS app can.
- Do not log or echo Supabase tokens.

Use MCP read inspection freely when available. For schema writes, use migrations and keep the repo SQL in sync. For real data writes, ask for explicit owner confirmation.

## RevenueCat

RevenueCat project: `Ploot` (`proj4bf2b770`). iOS app bundle id: `app.ploot.Ploot`. Entitlement: `pro`. Current offering: `default`.

- Package IDs and product IDs must stay aligned with `SubscriptionManager`.
- Do not rename store identifiers lightly.
- Do not echo RevenueCat API keys.
- Writes to products, offerings, or entitlements require explicit owner approval.
- If offerings are empty on-device, first check that the default offering is current and has the expected packages.

## Sandbox IAP Testing

- Primary sandbox tester: `francis-test-ng@brigo.ai`.
- Clean-slate sandbox tester: `plootsandbox@test.com`.
- Sign in through Settings -> Developer -> Sandbox Apple Account, not the real Apple ID slot.
- Sandbox durations are compressed: 1 month is about 5 minutes, 1 year is about 1 hour.
- The StoreKit sheet should show a Sandbox marker during sandbox purchase flows.

## Git And Commits

- Never commit code before the owner has tested user-visible changes on-device.
- After a clean build, ask the owner to run the app on their phone before committing UI/runtime changes.
- If the owner approves, ask whether to commit if they have not already asked.
- Documentation-only edits may be committed without on-device testing if requested.
- Use small, scoped commits with conventional prefixes: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`.
- Do not rewrite history on commits the owner wrote.
- Use `git revert <sha>` for reversions instead of force-pushing.

## Useful Commands

Fast build check:

```bash
xcodebuild -project Ploot.xcodeproj -scheme Ploot \
  -destination 'generic/platform=iOS Simulator' \
  -configuration Debug CODE_SIGNING_ALLOWED=NO build
```

Find files quickly:

```bash
rg --files
```

## When In Doubt

1. Open the matching file in `design_kit/ploot-design-system/project/preview/` or `ui_kits/mobile/`.
2. Match the design spec before inventing a new UI pattern.
3. Prefer native SwiftUI constructs: `NavigationStack`, `.sheet`, `.safeAreaInset`, SwiftData queries, and existing design-system components.
4. If a backend behavior depends on Supabase deployment or edge function redeployment, say that explicitly.
