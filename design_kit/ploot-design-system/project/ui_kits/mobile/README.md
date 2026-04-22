# Ploot Mobile — UI Kit

A working, interactive prototype of the Ploot task-management app. Open `index.html` to see four device frames (Today, Projects, Calendar, Done), each fully clickable.

## Files
- `index.html` — composed demo, renders 4 iOS device frames
- `App.jsx` — root app component, state, seed data
- `Screens.jsx` — Today, Projects, TaskDetail, Calendar, Done, QuickAddSheet
- `Composites.jsx` — TaskRow, ScreenFrame, TabBar, FAB, SectionHeader, Empty
- `Primitives.jsx` — Button, Checkbox, Chip, Field, Avatar, Card, Icon
- `ios-frame.jsx` — iOS device chrome (starter component)

## What's included
- Tap the round checkboxes → springy check-animation with success ring
- Tap the ＋ (FAB) → quick-add bottom sheet with chips
- Swap bottom tabs → animated icon scale
- Tap a task row → detail screen with subtasks, note card, meta rows
- Calendar shows a horizontal day scrubber + timed blocks
- Done shows a streak card + weekly chart

## What's left blank (intentionally)
- Settings / profile — not in scope per the brief
- Onboarding flow — not in scope per the brief
- Real data / backend — all demo state
