import SwiftUI

struct PrivacyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy & Data Storage")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom)
                
                Text(PrivacyInfo.privacyStatement)
                    .font(.body)
                    .lineSpacing(8)
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Data Location")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "iphone")
                            .foregroundColor(.blue)
                        Text("All data is stored locally on your device")
                    }
                    
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                        Text("Data is encrypted at rest")
                    }
                    
                    HStack {
                        Image(systemName: "xmark.shield")
                            .foregroundColor(.blue)
                        Text("No cloud synchronization or third‑party services")
                    }
                }
                
                Divider()
                    .padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Control")
                        .font(.headline)
                    
                    HStack {
                        Image(systemName: "trash")
                            .foregroundColor(.blue)
                        Text("Delete all data at any time")
                    }
                    
                    HStack {
                        Image(systemName: "hand.raised")
                            .foregroundColor(.blue)
                        Text("No automatic data sharing")
                    }
                    
                    HStack {
                        Image(systemName: "eye.slash")
                            .foregroundColor(.blue)
                        Text("No analytics, no tracking, no ads")
                    }
                }
                
                Divider().padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("HealthKit Usage")
                        .font(.headline)
                    Text("VitalVu reads select health data (e.g., heart rate, blood pressure, temperature) from Apple Health only after you grant permission. You can change permissions anytime in Settings > Health > Data Access & Devices.")
                    Text("We do not write data to Health unless explicitly initiated by you.")
                }
                
                Divider().padding(.vertical)
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Export & Import")
                        .font(.headline)
                    Text("You can export your data as JSON for personal backup and import it back securely. Exports occur locally and use the system share sheet. Imports use security‑scoped access and never leave your device.")
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 