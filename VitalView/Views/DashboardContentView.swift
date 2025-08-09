import SwiftUI
import HealthKit

struct DashboardContentView: View {
    let isAuthorized: Bool
    let healthMetrics: [Metric]
    let authorizationAttempted: Bool
    let onRefresh: () -> Void
    let onAuthorize: () -> Void
    let onSelectMetric: (Metric) -> Void
    let onManualTemperatureEntry: (() -> Void)?
    
    @State private var animationStates: [String: Bool] = [:]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Health Metrics Dashboard")
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.horizontal, 12)
                    .padding(.top, 16)
                
                HStack {
                    Spacer()
                    Button(action: onRefresh) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 20))
                            Text("Refresh")
                                .font(.subheadline)
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.trailing, 12)
                }
                
                if !isAuthorized {
                    VStack(spacing: 12) {
                        Text("HealthKit Access Required")
                            .font(.headline)
                        
                        if HKHealthStore.isHealthDataAvailable() {
                            if authorizationAttempted {
                                Text("Authorization dialog should have appeared. If you didn't see it, please check your device settings or try again.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                HStack(spacing: 12) {
                                    Button("Try Again") {
                                        onAuthorize()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    
                                    Button("Force Authorization") {
                                        // Force HealthKit authorization
                                        onAuthorize()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .foregroundColor(.orange)
                                    
                                    Button("Continue Without HealthKit") {
                                        // Force continue without authorization
                                        // This will be handled by the parent view
                                    }
                                    .buttonStyle(.bordered)
                                }
                            } else {
                                Text("Please authorize access to your health data to view your metrics.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button("Authorize HealthKit") {
                                    onAuthorize()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Text("HealthKit is not available on this device. Please test on a physical iPhone to access health data.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button("Continue Without HealthKit") {
                                // Allow user to continue with manual data entry
                                onAuthorize() // This will be handled by the parent view
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
                } else {
                    Text("This dashboard displays your latest vital signs and health metrics from HealthKit.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 12)
                    
                    Spacer().frame(height: 32)
                    
                    GeometryReader { proxy in
                        let minCardWidth: CGFloat = (horizontalSizeClass == .regular) ? 220 : 160
                        let columns = [GridItem(.adaptive(minimum: minCardWidth), spacing: 12)]
                        let cardHeight: CGFloat = (horizontalSizeClass == .regular) ? 130 : 120

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(healthMetrics) { metric in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        if metric.title == "Temperature" && metric.value == "Tap to add" {
                                            onManualTemperatureEntry?()
                                        } else {
                                            onSelectMetric(metric)
                                        }
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: metric.icon)
                                                .foregroundColor(metric.color)
                                                .font(.title2)
                                                .scaleEffect(getIconScale(for: metric.title))
                                                .animation(getIconAnimation(for: metric.title), value: animationStates[metric.title] ?? false)
                                                .onAppear { startIconAnimation(for: metric) }
                                            Spacer()
                                            Text(metric.value)
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                        }
                                        Text(metric.title)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        Text(metric.unit)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.8)
                                        if let date = metric.date {
                                            Text(date, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, minHeight: cardHeight, alignment: .topLeading)
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(radius: 2)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    .frame(minHeight: 0, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(UIColor.systemBackground))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func getIconScale(for title: String) -> CGFloat {
        let isAnimating = animationStates[title] ?? false
        switch title {
        case "Heart Rate":
            return isAnimating ? 1.3 : 1.0
        case "Oxygen":
            return isAnimating ? 1.2 : 1.0
        case "Temperature":
            return isAnimating ? 1.25 : 1.0
        case "Blood Pressure":
            return isAnimating ? 1.2 : 1.0
        case "Respiratory Rate":
            return isAnimating ? 1.2 : 1.0
        case "Heart Rate Variability":
            return isAnimating ? 1.2 : 1.0
        case "Latest ECG":
            return isAnimating ? 1.25 : 1.0
        default:
            return isAnimating ? 1.15 : 1.0
        }
    }
    
    private func getIconAnimation(for title: String) -> Animation {
        switch title {
        case "Heart Rate":
            return .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
        case "Oxygen":
            return .easeInOut(duration: 1.5).repeatForever(autoreverses: true)
        case "Temperature":
            return .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        case "Blood Pressure":
            return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        case "Respiratory Rate":
            return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case "Heart Rate Variability":
            return .easeInOut(duration: 0.9).repeatForever(autoreverses: true)
        case "Latest ECG":
            return .easeInOut(duration: 1.1).repeatForever(autoreverses: true)
        default:
            return .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
        }
    }
    
    private func startIconAnimation(for metric: Metric) {
        // Start animation immediately
        animationStates[metric.title] = true
        
        // Create a continuous animation cycle
        Timer.scheduledTimer(withTimeInterval: Double.random(in: 2...4), repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                animationStates[metric.title] = false
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    animationStates[metric.title] = true
                }
            }
        }
    }
}
