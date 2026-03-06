import Foundation

struct FeatureFlags: Sendable, Equatable {
    var isPolarEnabled: Bool
    var isKoalaEnabled: Bool
    var isBearClawEnabled: Bool

    init(
        isPolarEnabled: Bool = false,
        isKoalaEnabled: Bool = false,
        isBearClawEnabled: Bool = false
    ) {
        self.isPolarEnabled = isPolarEnabled
        self.isKoalaEnabled = isKoalaEnabled
        self.isBearClawEnabled = isBearClawEnabled
    }
}
