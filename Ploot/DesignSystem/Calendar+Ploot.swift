import Foundation

/// Calendar instance that honors `Settings → Appearance → Week starts on`.
/// Use this anywhere the app cares about week boundaries (DoneScreen
/// dot row, Calendar grid, week-rollup helpers) so a single pref drives
/// every consumer.
///
/// Defaults to `Calendar.current.firstWeekday` when the user hasn't
/// picked a value, so the system locale's choice (Sunday in the US,
/// Monday across most of EU) carries through unmodified.
extension Calendar {
    static var ploot: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = UserPrefs.weekStartsOn
        return cal
    }
}
