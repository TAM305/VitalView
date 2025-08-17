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
    let size: CGFloat
    let color: Color
    let isAnimating: Bool
    
    // MARK: - Performance Optimization
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.8
    @State private var rotation: Double = 0.0
    @State private var glowIntensity: Double = 0.0
    
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(color.opacity(0.3))
                .frame(width: size * 1.5, height: size * 1.5)
                .scaleEffect(glowIntensity)
                .blur(radius: 8)
            
            // Main blood drop
            Image(systemName: "drop.fill")
                .font(.system(size: size))
                .foregroundColor(color)
                .scaleEffect(scale)
                .opacity(opacity)
                .rotationEffect(.degrees(rotation))
                .overlay(
                    // Shine effect using shape instead of duplicate icon
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: size * 0.4, height: size * 0.3)
                        .offset(x: -size * 0.15, y: -size * 0.15)
                        .blendMode(.overlay)
                )
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onChange(of: isAnimating) { oldValue, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    // MARK: - Optimized Animation
    
    private func startAnimation() {
        // Continuous pulsing animation
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            scale = 1.1
            opacity = 1.0
        }
        
        // Subtle rotation
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            rotation = 5.0
        }
        
        // Glow effect
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            glowIntensity = 1.2
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            scale = 1.0
            opacity = 0.8
            rotation = 0.0
            glowIntensity = 0.0
        }
    }
}

// MARK: - Static Blood Drop View
struct StaticBloodDropView: View {
    let size: CGFloat
    let color: Color
    
    var body: some View {
        Image(systemName: "drop.fill")
            .font(.system(size: size))
            .foregroundColor(color)
            .overlay(
                // Shine effect using shape instead of duplicate icon
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.white.opacity(0.5), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size * 0.4, height: size * 0.3)
                    .offset(x: -size * 0.15, y: -size * 0.15)
                    .blendMode(.overlay)
            )
    }
}

// MARK: - Preview
struct BloodDropView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            AnimatedBloodDropView(size: 50, color: .red, isAnimating: true)
            AnimatedBloodDropView(size: 40, color: .blue, isAnimating: false)
            StaticBloodDropView(size: 30, color: .green)
        }
        .padding()
    }
} 
