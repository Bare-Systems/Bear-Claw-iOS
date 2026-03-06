import Foundation

struct FeatureFlags: Sendable, Equatable {
    var isPolarEnabled: Bool
    var isKoalaEnabled: Bool
    var isKodiakEnabled: Bool

    init(
        isPolarEnabled: Bool = false,
        isKoalaEnabled: Bool = false,
        isKodiakEnabled: Bool = false
    ) {
        self.isPolarEnabled = isPolarEnabled
        self.isKoalaEnabled = isKoalaEnabled
        self.isKodiakEnabled = isKodiakEnabled
    }
}
