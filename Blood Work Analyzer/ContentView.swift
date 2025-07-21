//
//  ContentView.swift
//  VitalView
//
//  Created by Tony on 5/14/25.
//

import SwiftUI
import HealthKit
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var viewModel: BloodTestViewModel
    @State private var showBloodTests = false
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: BloodTestViewModel(context: context))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with blood drop and app title
                ZStack {
                    // Centered app title
                    Text("VitalView")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Blood drop icon positioned to the left
                    HStack {
                        AnimatedBloodDropView(size: 50, color: .red, isAnimating: true)
                            .padding(.leading, 20)
                        Spacer()
                    }
                }
                .padding(.top)
                .frame(maxWidth: .infinity)
                
                HealthMetricsView(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct TestRowView: View {
    let test: BloodTest
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(test.testType)
                .font(.headline)
            Text(test.date, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
    }
}
