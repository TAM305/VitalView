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
    @State private var showingImport = false
    @State private var showingPDFImport = false
    
    // MARK: - Performance Optimization
    @State private var isFloatingButtonVisible = false
    @State private var floatingButtonScale: CGFloat = 0.8
    
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

                        // Lazy load HealthMetricsView for better performance
                        LazyView {
                            HealthMetricsView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle("Dashboard")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(action: { showingImport = true }) {
                                Image(systemName: "square.and.arrow.down")
                                    .font(.system(size: 20))
                            }
                        }
                        
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showingSettings = true }) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                            }
                        }
                    }

                    // Optimized floating add button with menu
                    if isFloatingButtonVisible {
                        FloatingActionButton(
                            showBloodTests: $showBloodTests,
                            showingImport: $showingImport,
                            showingPDFImport: $showingPDFImport
                        )
                        .scaleEffect(floatingButtonScale)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: floatingButtonScale)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .sheet(isPresented: $showBloodTests) {
                    AddTestSheetView(isPresented: $showBloodTests)
                }
                .sheet(isPresented: $showingSettings) {
                    NavigationView {
                        SettingsView(viewModel: BloodTestViewModel(context: PersistenceController.shared.container.viewContext))
                    }
                }
                .sheet(isPresented: $showingImport) {
                    ImportLabDataView(viewModel: viewModel)
                }
                .sheet(isPresented: $showingPDFImport) {
                    PDFImportView()
                        .environmentObject(viewModel)
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "house.fill")
                Text("Dashboard")
            }

            // Trends tab
            NavigationView {
                LazyView {
                    TrendsTabView()
                        .environmentObject(viewModel)
                        .navigationTitle("Trends")
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationViewStyle(StackNavigationViewStyle())
            .tabItem {
                Image(systemName: "chart.line.uptrend.xyaxis")
                Text("Trends")
            }
        }
        .onAppear {
            // Animate floating button appearance
            withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
                isFloatingButtonVisible = true
                floatingButtonScale = 1.0
            }
        }
    }
}

// MARK: - LazyView for Performance
struct LazyView<Content: View>: View {
    let build: () -> Content
    
    init(_ build: @escaping () -> Content) {
        self.build = build
    }
    
    var body: Content {
        build()
    }
}

// MARK: - Optimized Floating Action Button
struct FloatingActionButton: View {
    @Binding var showBloodTests: Bool
    @Binding var showingImport: Bool
    @Binding var showingPDFImport: Bool
    
    var body: some View {
        Menu {
            Button(action: { showBloodTests = true }) {
                Label("Add Test Manually", systemImage: "plus.circle")
            }
            
            Button(action: { showingImport = true }) {
                Label("Import Lab Data", systemImage: "square.and.arrow.down")
            }
            
            Button(action: { showingPDFImport = true }) {
                Label("Import from PDF", systemImage: "doc.text.magnifyingglass")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(radius: 6)
        }
        .padding()
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
