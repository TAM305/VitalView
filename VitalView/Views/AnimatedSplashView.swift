import SwiftUI

struct AnimatedSplashView: View {
    @State private var heartScale: CGFloat = 1.0
    @State private var opacity: Double = 0.0
    @State private var textOpacity: Double = 0.0
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 30) {
                // Animated Heart
                Image(systemName: "heart.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                    .scaleEffect(heartScale)
                    .opacity(opacity)
                    .animation(
                        Animation.easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true),
                        value: heartScale
                    )
                
                // App Name
                Text("VitalVu")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .opacity(textOpacity)
                    .animation(
                        Animation.easeIn(duration: 0.8).delay(0.3),
                        value: textOpacity
                    )
                
                // Subtitle
                Text("Your Health Companion")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)
                    .opacity(textOpacity)
                    .animation(
                        Animation.easeIn(duration: 0.8).delay(0.5),
                        value: textOpacity
                    )
            }
        }
        .onAppear {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        // Start heart pulsing
        withAnimation(.easeInOut(duration: 0.5)) {
            opacity = 1.0
        }
        
        // Start heart scale animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            heartScale = 1.2
        }
        
        // Show text
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            textOpacity = 1.0
        }
    }
}

#Preview {
    AnimatedSplashView()
}
