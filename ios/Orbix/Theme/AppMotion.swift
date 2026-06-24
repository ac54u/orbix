import SwiftUI

enum AppMotion {
    static let standardCurve: Animation = .timingCurve(0.2, 0.8, 0.2, 1.0, duration: 0.35)

    static let fast: TimeInterval = 0.22
    static let medium: TimeInterval = 0.35
    static let slow: TimeInterval = 0.45

    static func fastAnim() -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: fast)
    }

    static func mediumAnim() -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: medium)
    }

    static func slowAnim() -> Animation {
        .timingCurve(0.2, 0.8, 0.2, 1.0, duration: slow)
    }

    static let skeletonCycle: TimeInterval = 1.4
}
