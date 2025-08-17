import SwiftUI

struct AnimatedSplashView: View {
    // MARK: - Performance Optimization
    @State private var bloodDropScale: CGFloat = 0.3
    @State private var bloodDropOpacity: Double = 0.0
    @State private var titleOpacity: Double = 0.0
    @State private var titleOffset: CGFloat = 30
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(.systemBackground),
                    Color(.systemGray6)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Animated blood drop
                ZStack {
                    // Blood drop shadow
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 120, height: 120)
                        .scaleEffect(bloodDropScale * 1.2)
                        .blur(radius: 20)
                    
                    // Main blood drop
                    Image(systemName: "drop.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.red)
                        .scaleEffect(bloodDropScale)
                        .opacity(bloodDropOpacity)
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
                                .frame(width: 40, height: 30)
                                .offset(x: -15, y: -15)
                                .scaleEffect(bloodDropScale * 0.7)
                                .blendMode(.overlay)
                        )
                }
                
                // App title with optimized animation
                VStack(spacing: 8) {
                    Text("VitalVu")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                    
                    Text("Health Monitoring")
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .opacity(titleOpacity)
                        .offset(y: titleOffset)
                }
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    // MARK: - Optimized Animation
    
    private func startAnimation() {
        guard !isAnimating else { return }
        isAnimating = true
        
        // Blood drop animation
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            bloodDropScale = 1.0
            bloodDropOpacity = 1.0
        }
        
        // Title animation
        withAnimation(.easeOut(duration: 0.6).delay(0.6)) {
            titleOpacity = 1.0
            titleOffset = 0
        }
        
        // Continuous subtle animation
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            bloodDropScale = 1.05
        }
    }
}

// MARK: - Preview
struct AnimatedSplashView_Previews: PreviewProvider {
    static var previews: some View {
        AnimatedSplashView()
            .preferredColorScheme(.light)
        
        AnimatedSplashView()
            .preferredColorScheme(.dark)
    }
}
