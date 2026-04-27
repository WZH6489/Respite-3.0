import SwiftUI
#if canImport(UIKit)
import UIKit
import AudioToolbox
#endif

enum InteractionFeedback {
    static func tap() {
#if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.8)
        AudioServicesPlaySystemSound(1104)
#endif
    }

    static func success() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1113)
#endif
    }

    static func warning() {
#if canImport(UIKit)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        AudioServicesPlaySystemSound(1102)
#endif
    }
}
