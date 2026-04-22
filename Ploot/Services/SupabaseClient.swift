import Foundation
import Supabase

/// Shared Supabase client. Single instance reused across the app so the
/// SDK's built-in session cache (Keychain-backed) is shared between every
/// screen that needs auth or data.
enum Supa {
    static let client = SupabaseClient(
        supabaseURL: Secrets.supabaseURL,
        supabaseKey: Secrets.supabaseAnonKey
    )
}
