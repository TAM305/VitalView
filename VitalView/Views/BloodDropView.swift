import SwiftUI

/// A reusable SwiftUI view that displays a blood drop using SF Symbols.
///
/// This view uses the same "drop.fill" SF Symbol that's used throughout the app
/// for consistency with the existing design language.
///
/// ## Usage
/// ```swift
/// BloodDropView(size: 60, color: .red)
/// ```
///
/// ## Features
/// - Customizable size and color
/// - Smooth scaling and rendering
/// - Consistent with app branding
/// - Supports dark and light mode
///
/// - Author: VitalVu Development Team
/// - Version: 1.0
struct BloodDropView: View {
    /// The size of the blood drop in points.
    let size: CGFloat
    
    /// The color to tint the blood drop. Defaults to red.
    let color: Color
    
    /// Whether to apply a subtle shadow effect.
    let showShadow: Bool
    
    /// Initializes a new blood drop view.
    /// - Parameters:
    ///   - size: The size of the blood drop in points. Defaults to 40.
    ///   - color: The color to tint the blood drop. Defaults to red.
    ///   - showShadow: Whether to apply a subtle shadow effect. Defaults to true.
    init(size: CGFloat = 40, color: Color = Color(red: 0.8, green: 0.1, blue: 0.1), showShadow: Bool = true) {
        self.size = size
        self.color = color
        self.showShadow = showShadow
    }
    
    var body: some View {
        Image(systemName: "drop.fill")
            .font(.system(size: size * 0.8))
            .foregroundColor(color)
            .shadow(color: showShadow ? color.opacity(0.3) : .clear, radius: 4, x: 0, y: 2)
            .accessibilityLabel("Blood drop")
            .onAppear {
                // Debug: Check if the symbol is available
                print("BloodDropView: Using drop.fill symbol with size \(size), color \(color)")
            }
    }
}

/// An animated version of the blood drop that includes a pulsing effect.
///
/// This view extends the basic BloodDropView with a subtle pulsing animation
/// that can be used to draw attention or indicate activity.
///
/// ## Usage
/// ```swift
/// AnimatedBloodDropView(size: 60, isAnimating: true)
/// ```
///
/// ## Features
/// - Customizable size and color
/// - Smooth scaling and rendering
/// - Consistent with app branding
/// - Supports dark and light mode
///
/// - Author: VitalVu Development Team
/// - Version: 1.0
struct AnimatedBloodDropView: View {
    /// The size of the blood drop in points.
    let size: CGFloat
    
    /// The color to tint the blood drop.
    let color: Color
    
    /// Whether the pulsing animation should be active.
    let isAnimating: Bool
    
    /// The animation state for the pulsing effect.
    @State private var isPulsing = false
    
    /// Initializes a new animated blood drop view.
    /// - Parameters:
    ///   - size: The size of the blood drop in points. Defaults to 40.
    ///   - color: The color to tint the blood drop. Defaults to red.
    ///   - isAnimating: Whether the pulsing animation should be active. Defaults to true.
    init(size: CGFloat = 40, color: Color = Color(red: 0.8, green: 0.1, blue: 0.1), isAnimating: Bool = true) {
        self.size = size
        self.color = color
        self.isAnimating = isAnimating
    }
    
    var body: some View {
        BloodDropView(size: size, color: color, showShadow: true)
            .scaleEffect(isAnimating && isPulsing ? 1.1 : 1.0)
            .animation(
                isAnimating ? 
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: true) : 
                    .default,
                value: isPulsing
            )
            .onAppear {
                if isAnimating {
                    isPulsing = true
                }
            }
    }
}

// MARK: - Preview
struct BloodDropView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            HStack(spacing: 20) {
                BloodDropView(size: 30, color: .red)
                BloodDropView(size: 40, color: .blue)
                BloodDropView(size: 50, color: .green)
            }
            
            HStack(spacing: 20) {
                AnimatedBloodDropView(size: 40, color: .red, isAnimating: true)
                AnimatedBloodDropView(size: 40, color: .blue, isAnimating: false)
            }
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
} 
