import Foundation

enum AppPreferences {
    static let forceMaxOpus46EffortKey = "forceMaxOpus46Effort"
    static let defaultForceMaxOpus46Effort = true

    static var forceMaxOpus46Effort: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: forceMaxOpus46EffortKey) != nil else {
            return defaultForceMaxOpus46Effort
        }
        return defaults.bool(forKey: forceMaxOpus46EffortKey)
    }
}
