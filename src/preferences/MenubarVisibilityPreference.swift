import Foundation

/// Persisted contract for an optional menu bar icon. Dependency-free because the Test target
/// compiles a stub `Preferences`, so the stored key and its default are pinned from here.
enum MenubarVisibilityPreference {
    /// Renaming this orphans the setting for every existing install, so tests pin it.
    static let key = "showMenubarIcon"

    /// String-backed like the rest of the registry, because `CachedUserDefaults.bool` reads
    /// through `UserDefaults.string(forKey:)`. An absent value means the icon is visible.
    static let defaultValue = "true"
}
