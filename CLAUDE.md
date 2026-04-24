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

### A clean build ≠ a correct layout

`xcodebuild … build` exiting `BUILD SUCCEEDED` proves the code compiles. It does **not** prove the UI is right. SwiftUI will happily let one view sit on top of another with no warning. Before committing any change that touches stacking, overlays, safe area, or nav-destination chrome: ask the owner to eyeball it on-device, not just accept a green build.

Concretely — when you need a floating element to stop at a container's edge (not the screen edge), apply `.overlay` to the container **before** `.safeAreaInset` or other modifiers that grow/shift it. Example from this repo:

```swift
// Wrong: FAB anchors to screen bottom, covers the tab bar.
ZStack(alignment: .bottomTrailing) {
    tabContent.safeAreaInset(edge: .bottom) { TabBar(…) }
    FAB(…).padding(.bottom, 24)
}

// Right: FAB anchors to tabContent's bottom = tab bar's top.
tabContent
    .overlay(alignment: .bottomTrailing) { FAB(…).padding(.bottom, 12) }
    .safeAreaInset(edge: .bottom) { TabBar(…) }
```

If the owner flags a layout bug, the first move is a modifier reorder, not a redesign. Don't propose swapping the pattern (dock the FAB, go liquid-glass, etc.) unless the geometry fix has already been tried.

### Animation: take the opportunity, favor bouncy springs

This is a native iOS app — **motion is the product's personality**. Every meaningful state change should feel animated, not teleported. When you touch a view that changes state, ask "would this feel more alive with motion?" before shipping. The answer is usually yes.

**Springs are the default timing.** All motion uses `Motion.spring` (response 0.38, damping 0.62) or `Motion.springFast`. The brand is playful. Don't use `.linear` or tight-damping springs for UI state. Press-collapse animations on buttons use `Motion.springFast`. Tab-icon scale uses `Motion.spring`. Reserve `.easeOut` for fade-only cases.

**Opportunities you should look for and act on:**
- **Rows entering or leaving a list** (filter changes, deletions, check-offs, section moves). Add `.transition(.asymmetric(insertion: .move(edge: X).combined(with: .opacity), removal: .move(edge: Y).combined(with: .opacity)))` on the row inside the `ForEach`. Think about directionality: forward progress slides trailing, going-back slides leading.
- **Filter-driven re-renders from `@Query`.** Wrap the triggering mutation in `withAnimation(Motion.spring) { … }` so SwiftUI animates the list rearrangement instead of snapping.
- **Sheet + navigation transitions.** iOS defaults are fine; don't override unless you have a reason.
- **Toggle state changes.** Reach for `.symbolEffect`, `.matchedGeometryEffect`, or a local spring — anything but a pop.
- **Expand / collapse.** `.transition(.opacity.combined(with: .move(edge: .top)))` on the disclosed content.
- **Tab / selection changes.** Scale + translate subtly; see `TabBar` active-icon scale for the pattern.

**The "predictive visual + delayed mutation + exit transition" template.** Used for task check-off; reuse the shape whenever a state change would otherwise feel too instant:
1. Flip a local `@State` flag (e.g. `justCompleted`) **immediately** on user action so the visual state is predictive (strikethrough, dimmed, whatever represents the new state).
2. Delay the actual model mutation ~400–600ms so the user sees the completed state register before the view leaves the hierarchy.
3. When the delay fires, commit inside `withAnimation(Motion.spring) { … }`.
4. A `.transition(...)` on the `ForEach` row handles the slide-out.

`TaskRow.handleToggle` is the reference implementation; see `Ploot/Components/TaskRow.swift`.

**Don't over-animate.** Tiny hover-ish jitters on every tap make the app feel busy. Animate *state transitions* — done/undone, filter in/out, push/pop, expand/collapse, appear/dismiss. Don't animate every paint tick.

**Clean builds still don't prove motion is right.** A green `xcodebuild` only means the animation compiles. Ask the owner to verify on-device whenever you add or change a motion — physical devices are where spring feel actually lives.

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

- `TaskStore` was removed in Phase 3a — views use `@Query` directly. `@Observable` remains the right macro when we need local view-state holders; don't reach for `ObservableObject`.
- Pass SwiftData mutations via `@Environment(\.modelContext)`. Queries use `@Query`, optionally with sort descriptors.
- Seed data in `DemoData.seedIfNeeded(context:)` — idempotent, only inserts when both tasks and projects tables are empty.

### Adding fields to an existing @Model — use Optional

SwiftData's automatic lightweight migration refuses to load an on-device store if a new *non-optional* column has no value for existing rows. The crash looks like:

```
NSCocoaErrorDomain 134110 — missing attribute values on mandatory destination attribute
```

Default to `Optional` types for every new field on an existing model:

```swift
// Wrong — crashes on the first on-device launch that has the old schema.
var updatedAt: Date

// Right — nil is a valid value for rows that predate the column.
var updatedAt: Date?
```

Set the field to its default (`Date()` etc.) in the `init` so fresh rows still get values. Treat nil as "never set since the column arrived" at read time.

If the field truly must be non-optional, ship an explicit `SchemaMigrationPlan` with a `.lightweight` or `.custom` stage that supplies a default.

During rapid iteration, "delete + reinstall" is a valid dev workflow when you've already shipped a non-optional field. Once real users exist, every schema change needs a migration plan.

## Supabase MCP access

The owner has the **Supabase MCP server** wired up in `.mcp.json` (gitignored — contains a personal access token). When you open this repo in Claude Code, you have direct access to the project's Postgres database via `mcp__supabase__*` tools.

- **Project ref:** `rnlzqlocipeecbejyutv` — URL: https://rnlzqlocipeecbejyutv.supabase.co
- **Dashboard:** https://supabase.com/dashboard/project/rnlzqlocipeecbejyutv
- **Migrations live at:** `supabase/migrations/*.sql` (numbered, checked in)

### What to use, when

- **Read inspection** (tables, columns, indexes, RLS state, row counts): `list_tables`, `list_extensions`, `list_migrations`, `execute_sql` with a SELECT. Use these freely — they're the fastest way to verify what's actually deployed.
- **Writes (DDL)**: `apply_migration` for schema changes. Always also save the same SQL to `supabase/migrations/000N_<name>.sql` so the repo reflects DB state. Don't do schema changes as ad-hoc `execute_sql` — they'd be invisible in the repo.
- **Writes (DML)**: `execute_sql` for INSERT/UPDATE/DELETE on real data. Gate on user confirmation for anything touching their rows.
- **Health checks**: `get_advisors` surfaces RLS misconfigurations, missing indexes, policy overlaps. Run after any schema change.
- **Runtime debugging**: `get_logs` pulls Postgres/Auth/Realtime logs for the last 24h.
- **Types**: `generate_typescript_types` if we ever need a JS/TS client; not relevant for the iOS app directly.
- **Docs**: `search_docs` hits Supabase's official docs in-session — prefer over web search for Supabase questions.

### Operating rules

- **Read-only vs read-write**: `.mcp.json` controls this via a `&read_only=true` URL flag. Default stance is read-only; the owner flips it off only when migrations/writes are planned. If a write tool errors with "Cannot apply migration in read-only mode", ask the owner to flip the flag and reconnect (`/mcp` → reconnect).
- **RLS is on for every `public.*` table.** Direct `execute_sql` reads as the MCP service role bypass RLS, so you see all rows. In app code, the iOS client will only see its own rows via `auth.uid()`. Don't be confused when a table shows many rows via MCP but an authed query returns only the owner's.
- **Never log or echo the access token.** It's in `.mcp.json` (gitignored). Don't paste it into commits, comments, error messages, or chat.
- **Match SwiftData model shapes.** DB uses `snake_case`; Swift uses `camelCase`. Bridge with Supabase SDK config or `CodingKeys`. Columns mirror SwiftData fields 1:1 — if you add a field to a `@Model`, also write a migration for the corresponding column.

## RevenueCat MCP access

The owner has the **RevenueCat MCP server** wired up in `.mcp.json`. When you open this repo in Claude Code, you have direct access to the Ploot RC project via `mcp__revenuecat__*` tools.

- **Project:** `Ploot` (`proj4bf2b770`) — [Dashboard](https://app.revenuecat.com/projects/proj4bf2b770)
- **iOS app:** `Ploot iOS` (`app118ca9abd3`), bundle id `app.ploot.Ploot`
- **Entitlement:** `pro` (`entl7ca39e2679`) — gates the whole app. SubscriptionManager reads it as `Self.entitlementID`.
- **Offering:** `default` (current), with `$rc_monthly` → `ploot.pro.monthly` and `$rc_annual` → `ploot.pro.yearly`. Package id constants in `SubscriptionManager` must stay aligned.

### What to use, when

- **Read inspection**: `list-projects`, `list-apps`, `list-products`, `list-offerings`, `list-entitlements`, `get-customer`, `get-subscription`, `list-purchases`. Safe, fast — prefer these over the dashboard for quick checks.
- **Debugging a specific user**: `get-customer` with the App User ID (our Supabase user id once aliased by `identify(userId:)`). Shows entitlements, active subscriptions, and purchase history.
- **Metrics**: `get-overview-metrics`, `get-chart-data` for MRR / conversion / churn snapshots.
- **Writes** (create/update/archive products, offerings, entitlements): only with explicit owner approval. A wrong archive will silently break paywall offerings on-device.

### Operating rules

- **Never echo the RC v2 API key** from `.mcp.json`. Separate concept from the in-app **public** key (`appl_…` in `Secrets.swift`), which is safe to ship.
- Product `store_identifier` values (`ploot.pro.monthly`, `ploot.pro.yearly`) are tied to ASC — don't rename them lightly. RC is downstream of ASC; ASC is the source of truth for product ids.
- If `Purchases.shared.offerings()` returns empty on-device, first check via MCP that the default offering is_current and has both packages attached before digging into the SDK.

## Sandbox IAP testing

- **Primary sandbox tester (on-device):** `francis-test-ng@brigo.ai` — already signed into the iPhone's Sandbox Apple Account slot. Use this one for day-to-day testing runs.
- **Clean-slate sandbox tester:** `plootsandbox@test.com` / `Pl@247200` (US territory). Use when you need a never-subscribed account to re-exercise trial-eligibility / fresh-paywall UX after the primary has consumed its trial.
- Sandbox testers can't purchase on the real store, can't access real data, and are scoped to this app's IAPs — creating more is cheap.
- Sign in on the iPhone at **Settings → Developer → Sandbox Apple Account** (iOS 17+). Do NOT sign this into the real Apple ID slot — the phone supports a separate sandbox account and expects it to be kept separate.
- Sandbox subscription durations are **compressed**: 1 month = 5 minutes, 1 year = 1 hour. Great for exercising trial-end → lockscreen path. `ReminderService.scheduleTrialEndingReminder` and `TrialEndingBanner` both read real dates from RC, so they just fire faster on the compressed clock.
- The first sandbox purchase surfaces the `[Sandbox]` tag in the StoreKit sheet. If you don't see it, you're signed into the real App Store — stop, sign out, re-sign into sandbox slot.

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

- **Never commit before the owner has tested the change on-device.** The owner runs the app on a physical iPhone and is the sole authority on whether a change is correct. When you finish a change that affects UI, runtime behavior, or anything user-visible, stop and ask the owner to test it. Phrase it like: *"Build's clean — please run on your phone and tell me how it looks before I commit."* Only commit after explicit approval ("looks good," "ship it," "commit this," etc.).
- After the owner confirms the change works, remind them if they forget: *"Want me to commit this now?"* Don't commit silently.
- Exceptions where you can commit without asking:
  - Pure documentation edits (`README.md`, `CLAUDE.md`, comments) with no code behavior change.
  - `.gitignore` or `.env.example` additions.
  - Reverts that the owner has just explicitly requested.
- Small, scoped commits with conventional-commit prefixes: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`. See existing log for style.
- `main` is the working branch. Push to `origin main` on github.com/Byk3y/ploot.
- Do **not** rewrite history on commits the owner wrote (e.g. the original `Initial Commit`). Layer on top.
- If a change needs reverting because it looks wrong on-device, use `git revert <sha>` — keep the paper trail, don't force-push.

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
