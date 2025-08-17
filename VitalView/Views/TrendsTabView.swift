import SwiftUI

struct TrendsTabView: View {
    enum TrendsKind: String, CaseIterable { case health = "Health", blood = "Blood" }
    @State private var selected: TrendsKind = .health
    @EnvironmentObject var bloodTestViewModel: BloodTestViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            Picker("Trends", selection: $selected) {
                ForEach(TrendsKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            
            Group {
                if selected == .health {
                    // Use the comprehensive HealthTrendsView
                    HealthTrendsView()
                } else {
                    BloodTestTrendsView(
                        viewModel: bloodTestViewModel,
                        onClose: { selected = .health }
                    )
                }
            }
            .frame(maxWidth: 900)
            .padding(.horizontal)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    TrendsTabView()
        .environmentObject(BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
}
