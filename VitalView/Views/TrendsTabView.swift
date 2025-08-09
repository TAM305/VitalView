import SwiftUI

struct TrendsTabView: View {
    enum TrendsKind: String, CaseIterable { case health = "Health", blood = "Blood" }
    @State private var selected: TrendsKind = .health
    
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
                    TrendsChartView()
                } else {
                    BloodTestTrendsView(viewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
                }
            }
            .frame(maxWidth: 900)
            .padding(.horizontal)
            Spacer(minLength: 0)
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
}

#Preview {
    TrendsTabView()
}
