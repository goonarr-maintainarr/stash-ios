import UIKit

/// Manages haptic feedback throughout the app using reused generators for performance.
enum HapticManager {
    
    // MARK: - Reused Generators
    
    private static let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private static let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private static let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    private static let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Public Methods
    
    /// Light impact for subtle interactions (e.g., button taps, selections)
    static func lightImpact() {
        lightImpactGenerator.prepare()
        lightImpactGenerator.impactOccurred()
    }
    
    /// Medium impact for standard interactions (e.g., navigation, toggles)
    static func mediumImpact() {
        mediumImpactGenerator.prepare()
        mediumImpactGenerator.impactOccurred()
    }
    
    /// Heavy impact for significant interactions (e.g., destructive actions)
    static func heavyImpact() {
        heavyImpactGenerator.prepare()
        heavyImpactGenerator.impactOccurred()
    }
    
    /// Selection feedback for picker-style interactions
    static func selection() {
        selectionGenerator.prepare()
        selectionGenerator.selectionChanged()
    }
    
    /// Success notification (e.g., successful save, completion)
    static func success() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.success)
    }
    
    /// Warning notification
    static func warning() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.warning)
    }
    
    /// Error notification
    static func error() {
        notificationGenerator.prepare()
        notificationGenerator.notificationOccurred(.error)
    }
}
