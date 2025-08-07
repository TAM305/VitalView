import SwiftUI

struct AddTestSheetView: View {
    @Binding var isPresented: Bool
    @Binding var currentStep: Int
    @Binding var selectedTestType: String
    @Binding var testValues: [String: String]
    @Binding var testDate: Date
    @Binding var showTrends: Bool
    @Binding var testResults: [BloodTest]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Add Blood Test")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.top, 20)
                
                Text("This feature is coming soon!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 20)
            }
            .navigationTitle("Add Blood Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
