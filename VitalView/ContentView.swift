//
//  ContentView.swift
//  VitalVu
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
    @State private var showingSettings = false
    
    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: BloodTestViewModel(context: context))
    }
    
    var body: some View {
        TabView {
            // Dashboard tab
            NavigationView {
                ZStack(alignment: .bottomTrailing) {
                    VStack(spacing: 0) {
                        // Header with blood drop and app title
                        ZStack {
                            Text("VitalVu")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            HStack {
                                AnimatedBloodDropView(size: 50, color: .red, isAnimating: true)
                                    .padding(.leading, 20)
                                Spacer()
                            }
                        }
                        .padding(.top)
                        .frame(maxWidth: .infinity)

                        HealthMetricsView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                            }
                        }
                    }

                    // Floating add button
                    Button(action: { showBloodTests = true }) {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                            .shadow(radius: 6)
                    }
                    .padding()
                    .sheet(isPresented: $showBloodTests) {
                        AddTestSheetView(isPresented: $showBloodTests)
                    }
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationView {
                        SettingsView(viewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
                    }
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "house.fill")
                Text("Dashboard")
            }

            // Trends tab
            NavigationView {
                TrendsTabView()
                    .navigationTitle("Trends")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Trends")
            }
        }
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
