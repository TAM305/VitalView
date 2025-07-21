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
                        Text("No cloud synchronization")
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
                        Text("No analytics or tracking")
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("Privacy")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 