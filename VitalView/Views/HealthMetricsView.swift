import SwiftUI
import HealthKit
import UIKit
import CoreData
import Charts  // Add Charts import

struct HealthMetricsView: View {
    @ObservedObject var viewModel: BloodTestViewModel
    @State private var heartRate: (value: Double?, date: Date?) = (nil, nil)
    @State private var bloodPressure: (systolic: Double?, diastolic: Double?, date: Date?) = (nil, nil, nil)
    @State private var oxygenSaturation: (value: Double?, date: Date?) = (nil, nil)
    @State private var temperature: (value: Double?, date: Date?) = (nil, nil)
    @State private var respiratoryRate: (value: Double?, date: Date?) = (nil, nil)
    @State private var heartRateVariability: (value: Double?, date: Date?) = (nil, nil)
    @State private var ecgData: [(date: Date, value: Double)] = []
    @State private var isAuthorized = false
    @State private var showingAddTest = false
    @State private var showingTrends = false
    @State private var selectedTestType: String? = nil
    @State private var testDate = Date()
    @State private var currentStep = 1
    @State private var showingSettings = false
    
    // CBC Fields
    @State private var wbc: String = ""
    @State private var neutrophilsPercent: String = ""
    @State private var neutrophilsAbsolute: String = ""
    @State private var lymphocytesPercent: String = ""
    @State private var lymphocytesAbsolute: String = ""
    @State private var monocytesPercent: String = ""
    @State private var monocytesAbsolute: String = ""
    @State private var eosinophilsPercent: String = ""
    @State private var eosinophilsAbsolute: String = ""
    @State private var basophilsPercent: String = ""
    @State private var basophilsAbsolute: String = ""
    @State private var rbc: String = ""
    @State private var hgb: String = ""
    @State private var hct: String = ""
    @State private var mcv: String = ""
    @State private var mch: String = ""
    @State private var mchc: String = ""
    @State private var rdw: String = ""
    @State private var plt: String = ""
    @State private var mpv: String = ""
    
    // CMP/BMP Fields
    @State private var glucose: String = ""
    @State private var calcium: String = ""
    @State private var sodium: String = ""
    @State private var potassium: String = ""
    @State private var chloride: String = ""
    @State private var bicarbonate: String = ""
    @State private var bun: String = ""
    @State private var creatinine: String = ""
    @State private var alt: String = ""
    @State private var ast: String = ""
    @State private var alp: String = ""
    @State private var bilirubin: String = ""
    @State private var albumin: String = ""
    
    // Lipid Panel Fields
    @State private var totalCholesterol: String = ""
    @State private var hdl: String = ""
    @State private var ldl: String = ""
    @State private var triglycerides: String = ""
    
    // Hemoglobin A1c Field
    @State private var hba1c: String = ""
    
    // Thyroid Function Fields
    @State private var tsh: String = ""
    @State private var t3: String = ""
    @State private var t4: String = ""
    
    // Vitamin D Field
    @State private var vitaminD: String = ""
    
    // CRP Fields
    @State private var crp: String = ""
    @State private var hsCrp: String = ""
    
    // Iron Studies Fields
    @State private var iron: String = ""
    @State private var ferritin: String = ""
    
    // PSA Field
    @State private var psa: String = ""
    
    // Kidney Function Fields
    @State private var totalProtein: String = ""
    
    // Urinalysis Fields
    @State private var urineColor: String = ""
    @State private var urineClarity: String = ""
    @State private var urineGlucose: String = ""
    @State private var urineKetones: String = ""
    @State private var urineBlood: String = ""
    @State private var urineBilirubin: String = ""
    @State private var urineBacteria: String = ""
    @State private var squamousCells: String = ""
    @State private var specificGravity: String = ""
    
    // Add state for trend data
    @State private var trendData: [String: [(date: Date, value: Double)]] = [:]
    @State private var isLoadingTrends = false
    @State private var selectedMetric = "Heart Rate"
    @State private var trendAnalysis: [String: TrendAnalysis] = [:]
    
    // Add state for trend tracking in Add Blood Test
    @State private var showingTrendTracking = false
    @State private var trendTrackingEnabled = false
    @State private var enableNotifications = false
    @State private var enableCharts = false
    @State private var enableGoals = false
    
    private let healthStore = HKHealthStore()
    
    // Add TrendAnalysis struct
    struct TrendAnalysis {
        let direction: TrendDirection
        let rateOfChange: Double
        let healthStatus: HealthStatus
        let recommendation: String
        let confidence: Double
    }
    
    enum TrendDirection {
        case improving, declining, stable, fluctuating
        
        var description: String {
            switch self {
            case .improving: return "Improving"
            case .declining: return "Declining"
            case .stable: return "Stable"
            case .fluctuating: return "Fluctuating"
            }
        }
        
        var icon: String {
            switch self {
            case .improving: return "arrow.up.circle.fill"
            case .declining: return "arrow.down.circle.fill"
            case .stable: return "minus.circle.fill"
            case .fluctuating: return "arrow.up.arrow.down.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .improving: return .green
            case .declining: return .red
            case .stable: return .blue
            case .fluctuating: return .orange
            }
        }
    }
    
    enum HealthStatus {
        case excellent, good, fair, poor, critical
        
        var description: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            case .critical: return "Critical"
            }
        }
        
        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return .red
            case .critical: return .purple
            }
        }
    }
    
    struct Metric: Identifiable {
        let id = UUID()
        let title: String
        let value: String
        let unit: String
        let icon: String
        let color: Color
        let date: Date? // Add optional date parameter
    }
    
    // Computed property for metrics to avoid complex expressions in body
    private var healthMetrics: [Metric] {
        let heartRateMetric = Metric(
            title: "Heart Rate",
            value: heartRate.value.map { "\(Int($0))" } ?? "--",
            unit: "BPM",
            icon: "heart.fill",
            color: .red,
            date: heartRate.date
        )
        
        let bloodPressureValue: String
        if let systolic = bloodPressure.systolic, let diastolic = bloodPressure.diastolic {
            bloodPressureValue = "\(Int(systolic))/\(Int(diastolic))"
        } else {
            bloodPressureValue = "--/--"
        }
        let bloodPressureMetric = Metric(
            title: "Blood Pressure",
            value: bloodPressureValue,
            unit: "mmHg",
            icon: "waveform.path.ecg",
            color: .blue,
            date: bloodPressure.date
        )
        
        let oxygenMetric = Metric(
            title: "Oxygen",
            value: oxygenSaturation.value.map { "\(Int($0))" } ?? "--",
            unit: "%",
            icon: "lungs.fill",
            color: .green,
            date: oxygenSaturation.date
        )
        
        let temperatureMetric = Metric(
            title: "Temperature",
            value: temperature.value.map { String(format: "%.1f", $0) } ?? "--",
            unit: "°F",
            icon: "thermometer",
            color: .orange,
            date: temperature.date
        )
        
        let respiratoryRateMetric = Metric(
            title: "Respiratory Rate",
            value: respiratoryRate.value.map { String(format: "%.1f", $0) } ?? "--",
            unit: "breaths/min",
            icon: "lungs",
            color: .purple,
            date: respiratoryRate.date
        )
        
        let hrvMetric = Metric(
            title: "Heart Rate Variability",
            value: heartRateVariability.value.map { String(format: "%.1f", $0) } ?? "--",
            unit: "ms",
            icon: "waveform.path.ecg.rectangle",
            color: .purple,
            date: heartRateVariability.date
        )
        
        let ecgValue: String
        if !ecgData.isEmpty, let firstECG = ecgData.first {
            ecgValue = String(format: "%.1f", firstECG.value)
        } else {
            ecgValue = "--"
        }
        let ecgMetric = Metric(
            title: "Latest ECG",
            value: ecgValue,
            unit: "mV",
            icon: "waveform.path.ecg",
            color: .red,
            date: ecgData.first?.date
        )
        
        return [
            heartRateMetric,
            bloodPressureMetric,
            oxygenMetric,
            temperatureMetric,
            respiratoryRateMetric,
            hrvMetric,
            ecgMetric
        ]
    }
    
    var body: some View {
        ZStack {
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
                        Button(action: { 
                            print("\n=== Manual Refresh Triggered ===")
                            fetchLatestVitalSigns() 
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 20))
                                Text("Refresh")
                                    .font(.subheadline)
                            }
                            .foregroundColor(.blue)
                        }
                        .padding(.trailing, 12)
                    }
                    
                    if !isAuthorized {
                        VStack(spacing: 12) {
                            Text("HealthKit Access Required")
                                .font(.headline)
                            Text("Please authorize access to your health data to view your metrics.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Button("Authorize HealthKit") {
                                requestHealthKitAuthorization()
                            }
                            .buttonStyle(.borderedProminent)
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
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(healthMetrics) { metric in
                                MetricCard(
                                    title: metric.title,
                                    value: metric.value,
                                    unit: metric.unit,
                                    icon: metric.icon,
                                    color: metric.color,
                                    date: metric.date
                                )
                                .frame(height: 110)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .background(Color(UIColor.systemBackground))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            VStack {
                Spacer()
                HStack {
                    Button(action: { showingTrends = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.blue)
                            Text("Trend")
                                .font(.headline)
                                .foregroundColor(.blue)
                        }
                    }
                    Spacer()
                    Button(action: { showingAddTest = true }) {
                        HStack(spacing: 6) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.red)
                            Text("Add Blood Test")
                                .font(.headline)
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 36)
                .padding(.vertical, 12)
                .padding(.bottom, 24)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showingAddTest) {
            NavigationView {
                VStack(spacing: 0) {
                    // Progress indicator with labels
                    VStack(spacing: 8) {
                        HStack(spacing: 4) {
                            ForEach(1...6, id: \.self) { step in
                                Circle()
                                    .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                                    .frame(width: 12, height: 12)
                                if step < 6 {
                                    Rectangle()
                                        .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                        .frame(height: 2)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Step labels
                        HStack {
                            Text("Choose Test")
                                .font(.caption)
                                .foregroundColor(currentStep == 1 ? .blue : .gray)
                            Spacer()
                            Text("Enter Values")
                                .font(.caption)
                                .foregroundColor(currentStep == 2 ? .blue : .gray)
                            Spacer()
                            Text("Select Date")
                                .font(.caption)
                                .foregroundColor(currentStep == 3 ? .blue : .gray)
                            Spacer()
                            Text("Review")
                                .font(.caption)
                                .foregroundColor(currentStep == 4 ? .blue : .gray)
                            Spacer()
                            Text("Track Trends")
                                .font(.caption)
                                .foregroundColor(currentStep == 5 ? .blue : .gray)
                            Spacer()
                            Text("Final Save")
                                .font(.caption)
                                .foregroundColor(currentStep == 6 ? .blue : .gray)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 16)
                    
                    // Step content
                    TabView(selection: $currentStep) {
                        // Step 1: Test Type Selection
                        VStack(spacing: 20) {
                            Text("Choose Test Type")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            Text("Select the type of blood test you want to add")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.flexible())], spacing: 12) {
                                    ForEach([
                                        ("Complete Blood Count (CBC)", "Checks red blood cells, white blood cells, hemoglobin, hematocrit, and platelets.", "CBC"),
                                        ("Comprehensive Metabolic Panel (CMP)", "Measures glucose, electrolytes, kidney function, and liver enzymes.", "CMP"),
                                        ("Lipid Panel", "Evaluates cholesterol levels and triglycerides.", "Lipid"),
                                        ("Hemoglobin A1c", "Measures average blood sugar levels over 2-3 months.", "A1c"),
                                        ("Thyroid Function Tests", "Measures TSH, T3, and T4 levels.", "Thyroid"),
                                        ("Vitamin D Test", "Measures 25-hydroxyvitamin D levels.", "VitaminD"),
                                        ("C-Reactive Protein (CRP)", "Measures inflammation levels in the body.", "CRP"),
                                        ("Liver Function Tests", "Evaluates liver health through various enzymes.", "Liver"),
                                        ("Iron Studies", "Measures iron levels and storage.", "Iron"),
                                        ("Prostate-Specific Antigen (PSA)", "Measures PSA levels for prostate health screening.", "PSA"),
                                        ("Urinalysis", "Assesses kidney health, hydration, and signs of infection or diabetes.", "Urinalysis"),
                                        ("Kidney Function Tests", "Evaluates kidney function and protein levels.", "Kidney")
                                    ], id: \.0) { test in
                                        TestTypeButton(
                                            title: test.0,
                                            description: test.1,
                                            action: {
                                                selectedTestType = test.2
                                                withAnimation {
                                                    currentStep = 2
                                                }
                                            }
                                        )
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .tag(1)
                        
                        // Step 2: Test Results
                        VStack(spacing: 20) {
                            Text("Enter Test Results")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            if let testType = selectedTestType {
                                ScrollView {
                                    VStack(spacing: 16) {
                                        Text("Please enter your \(testType) test results below")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal)
                                        
                                        switch testType {
                                        case "CBC":
                                            CBCForm(wbc: $wbc, neutrophilsPercent: $neutrophilsPercent, neutrophilsAbsolute: $neutrophilsAbsolute, lymphocytesPercent: $lymphocytesPercent, lymphocytesAbsolute: $lymphocytesAbsolute, monocytesPercent: $monocytesPercent, monocytesAbsolute: $monocytesAbsolute, eosinophilsPercent: $eosinophilsPercent, eosinophilsAbsolute: $eosinophilsAbsolute, basophilsPercent: $basophilsPercent, basophilsAbsolute: $basophilsAbsolute, rbc: $rbc, hgb: $hgb, hct: $hct, mcv: $mcv, mch: $mch, mchc: $mchc, rdw: $rdw, plt: $plt, mpv: $mpv)
                                        case "CMP":
                                            CMPForm(glucose: $glucose, calcium: $calcium, sodium: $sodium, potassium: $potassium,
                                                   chloride: $chloride, bicarbonate: $bicarbonate, bun: $bun, creatinine: $creatinine,
                                                   alt: $alt, ast: $ast, alp: $alp, bilirubin: $bilirubin, albumin: $albumin)
                                        case "Lipid":
                                            LipidForm(totalCholesterol: $totalCholesterol, hdl: $hdl, ldl: $ldl, triglycerides: $triglycerides)
                                        case "A1c":
                                            A1cForm(hba1c: $hba1c)
                                        case "Thyroid":
                                            ThyroidForm(tsh: $tsh, t3: $t3, t4: $t4)
                                        case "VitaminD":
                                            VitaminDForm(vitaminD: $vitaminD)
                                        case "CRP":
                                            CRPForm(crp: $crp, hsCrp: $hsCrp)
                                        case "Liver":
                                            LiverForm(alt: $alt, ast: $ast, alp: $alp, bilirubin: $bilirubin, albumin: $albumin)
                                        case "Iron":
                                            IronForm(iron: $iron, ferritin: $ferritin)
                                        case "PSA":
                                            PSAForm(psa: $psa)
                                        case "Urinalysis":
                                            UrinalysisForm(urineColor: $urineColor, urineClarity: $urineClarity, urineGlucose: $urineGlucose, urineKetones: $urineKetones, urineBlood: $urineBlood, urineBilirubin: $urineBilirubin, urineBacteria: $urineBacteria, squamousCells: $squamousCells, specificGravity: $specificGravity)
                                        case "Kidney":
                                            KidneyFunctionForm(totalProtein: $totalProtein, bun: $bun, creatinine: $creatinine)
                                        default:
                                            EmptyView()
                                        }
                                    }
                                    .padding()
                                }
                            }
                        }
                        .tag(2)
                        
                        // Step 3: Test Date
                        VStack(spacing: 20) {
                            Text("Select Test Date")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            Text("When was this test performed?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            DatePicker("", selection: $testDate, displayedComponents: [.date])
                                .datePickerStyle(.graphical)
                                .padding()
                                .frame(minHeight: 400)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                        }
                        .tag(3)
                        
                        // Step 4: Review and Save
                        VStack(spacing: 20) {
                            Text("Review and Save")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            if let testType = selectedTestType {
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 16) {
                                        // Test Type and Date
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label("Test Type", systemImage: "drop.fill")
                                                .font(.headline)
                                            Text(testType)
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Divider()
                                        
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label("Test Date", systemImage: "calendar")
                                                .font(.headline)
                                            Text(testDate.formatted(date: .long, time: .omitted))
                                                .font(.title3)
                                                .foregroundColor(.blue)
                                        }
                                        
                                        Divider()
                                        
                                        // Test Results
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label("Test Results", systemImage: "list.bullet")
                                                .font(.headline)
                                            
                                            // Show entered values based on test type
                                            if testType == "CBC" {
                                                ResultRow(title: "WBC", value: wbc, unit: "K/µL")
                                                ResultRow(title: "RBC", value: rbc, unit: "M/µL")
                                                ResultRow(title: "HGB", value: hgb, unit: "g/dL")
                                                ResultRow(title: "HCT", value: hct, unit: "%")
                                                ResultRow(title: "PLT", value: plt, unit: "K/µL")
                                            }
                                            // Add other test types here...
                                        }
                                        
                                        Divider()
                                        
                                        // Track Trends Section
                                        VStack(alignment: .leading, spacing: 8) {
                                            Label("Track Trends", systemImage: "chart.line.uptrend.xyaxis")
                                                .font(.headline)
                                            
                                            Text("Would you like to track trends for this test type?")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            HStack {
                                                Button(action: {
                                                    // Enable trend tracking and navigate to step 5
                                                    trendTrackingEnabled = true
                                                    withAnimation {
                                                        currentStep = 5
                                                    }
                                                }) {
                                                    HStack {
                                                        Image(systemName: "chart.line.uptrend.xyaxis")
                                                        Text("Enable Trend Tracking")
                                                    }
                                                    .padding()
                                                    .foregroundColor(.white)
                                                    .background(Color.green)
                                                    .cornerRadius(8)
                                                }
                                                
                                                Spacer()
                                                
                                                Button(action: {
                                                    // Skip trend tracking and proceed to save
                                                    trendTrackingEnabled = false
                                                }) {
                                                    Text("Skip")
                                                        .padding()
                                                        .foregroundColor(.secondary)
                                                        .background(Color(.systemGray5))
                                                        .cornerRadius(8)
                                                }
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(UIColor.systemBackground))
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                                }
                            }
                        }
                        .tag(4)
                        
                        // Step 5: Trend Tracking Setup (New Step)
                        VStack(spacing: 20) {
                            Text("Track Trends")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            Text("Set up trend tracking for your \(selectedTestType ?? "test") results")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Trend Tracking Options
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Tracking Options")
                                            .font(.headline)
                                        
                                        VStack(spacing: 12) {
                                            HStack {
                                                Image(systemName: "bell.fill")
                                                    .foregroundColor(.blue)
                                                VStack(alignment: .leading) {
                                                    Text("Notifications")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                    Text("Get alerts when values change significantly")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Toggle("", isOn: $enableNotifications)
                                            }
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            
                                            HStack {
                                                Image(systemName: "chart.bar.fill")
                                                    .foregroundColor(.green)
                                                VStack(alignment: .leading) {
                                                    Text("Progress Charts")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                    Text("Visualize your test results over time")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Toggle("", isOn: $enableCharts)
                                            }
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                            
                                            HStack {
                                                Image(systemName: "target")
                                                    .foregroundColor(.orange)
                                                VStack(alignment: .leading) {
                                                    Text("Goal Setting")
                                                        .font(.subheadline)
                                                        .fontWeight(.medium)
                                                    Text("Set target ranges for your values")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Toggle("", isOn: $enableGoals)
                                            }
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                        }
                                    }
                                    
                                    // Historical Data Preview
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Historical Data")
                                            .font(.headline)
                                        
                                        if let testType = selectedTestType {
                                            Text("You have \(getHistoricalTestCount(for: testType)) previous \(testType) tests")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            
                                            if getHistoricalTestCount(for: testType) > 0 {
                                                Text("Trend tracking will analyze these results to show patterns and changes over time.")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                            } else {
                                                Text("This will be your first \(testType) test. Future tests will be tracked for trends.")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                                    .padding(.top, 4)
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                }
                                .padding()
                            }
                        }
                        .tag(5)
                        
                        // Step 6: Final Save
                        VStack(spacing: 20) {
                            Text("Save Test")
                                .font(.title2)
                                .fontWeight(.bold)
                                .padding(.top, 20)
                            
                            Text("Review your test information and save to your health records")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            ScrollView {
                                VStack(alignment: .leading, spacing: 16) {
                                    // Test Summary
                                    VStack(alignment: .leading, spacing: 8) {
                                        Label("Test Summary", systemImage: "doc.text")
                                            .font(.headline)
                                        
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Type: \(selectedTestType ?? "Unknown")")
                                                .font(.subheadline)
                                            Text("Date: \(testDate.formatted(date: .long, time: .omitted))")
                                                .font(.subheadline)
                                            if trendTrackingEnabled {
                                                Text("Trend Tracking: Enabled")
                                                    .font(.subheadline)
                                                    .foregroundColor(.green)
                                            }
                                        }
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                    
                                    // Save Button
                                    Button(action: {
                                        // Create test results based on the selected test type
                                        var results: [TestResult] = []
                                        
                                        switch selectedTestType {
                                        case "CBC":
                                            if let wbcValue = Double(wbc) {
                                                results.append(TestResult(
                                                    name: "White Blood Cells",
                                                    value: wbcValue,
                                                    unit: "K/µL",
                                                    referenceRange: "4.5-11.0",
                                                    explanation: "Measures immune cells. High levels may indicate infection or inflammation; low levels may suggest immune suppression."
                                                ))
                                            }
                                            if let rbcValue = Double(rbc) {
                                                results.append(TestResult(
                                                    name: "Red Blood Cells",
                                                    value: rbcValue,
                                                    unit: "M/µL",
                                                    referenceRange: "4.5-5.5",
                                                    explanation: "Carries oxygen. Low levels = anemia; high levels = dehydration or other conditions."
                                                ))
                                            }
                                            if let hgbValue = Double(hgb) {
                                                results.append(TestResult(
                                                    name: "Hemoglobin",
                                                    value: hgbValue,
                                                    unit: "g/dL",
                                                    referenceRange: "13.5-17.5",
                                                    explanation: "Protein in RBCs that carries oxygen. Low = anemia."
                                                ))
                                            }
                                            if let hctValue = Double(hct) {
                                                results.append(TestResult(
                                                    name: "Hematocrit",
                                                    value: hctValue,
                                                    unit: "%",
                                                    referenceRange: "41-50",
                                                    explanation: "% of blood volume made of RBCs. Reflects hydration and oxygen-carrying capacity."
                                                ))
                                            }
                                            if let pltValue = Double(plt) {
                                                results.append(TestResult(
                                                    name: "Platelets",
                                                    value: pltValue,
                                                    unit: "K/µL",
                                                    referenceRange: "150-450",
                                                    explanation: "Platelets help with clotting. Low = bleeding risk; high = clotting risk."
                                                ))
                                            }
                                            
                                        case "CMP":
                                            if let glucoseValue = Double(glucose) {
                                                results.append(TestResult(
                                                    name: "Glucose",
                                                    value: glucoseValue,
                                                    unit: "mg/dL",
                                                    referenceRange: "70-100",
                                                    explanation: "Measures blood sugar levels"
                                                ))
                                            }
                                            if let calciumValue = Double(calcium) {
                                                results.append(TestResult(
                                                    name: "Calcium",
                                                    value: calciumValue,
                                                    unit: "mg/dL",
                                                    referenceRange: "8.5-10.5",
                                                    explanation: "Essential for bone health and muscle function"
                                                ))
                                            }
                                            // Add other CMP results...
                                            
                                        case "Lipid":
                                            if let totalCholValue = Double(totalCholesterol) {
                                                results.append(TestResult(
                                                    name: "Total Cholesterol",
                                                    value: totalCholValue,
                                                    unit: "mg/dL",
                                                    referenceRange: "<200",
                                                    explanation: "Total cholesterol level. High levels increase heart disease risk."
                                                ))
                                            }
                                            // Add other lipid results...
                                            
                                        default:
                                            break
                                        }
                                        
                                        // Create the blood test
                                        let test = BloodTest(
                                            testType: selectedTestType ?? "Unknown",
                                            testDate: testDate,
                                            results: results
                                        )
                                        
                                        // Save to Core Data
                                        let context = PersistenceController.shared.container.viewContext
                                        let testEntity = BloodTestEntity(context: context)
                                        testEntity.id = test.id
                                        testEntity.testType = test.testType
                                        testEntity.testDate = test.testDate
                                        
                                        // Save results
                                        for result in test.results {
                                            let resultEntity = TestResultEntity(context: context)
                                            resultEntity.id = result.id
                                            resultEntity.name = result.name
                                            resultEntity.value = result.value
                                            resultEntity.unit = result.unit
                                            resultEntity.referenceRange = result.referenceRange
                                            resultEntity.explanation = result.explanation
                                            resultEntity.setValue(testEntity, forKey: "test")
                                        }
                                        
                                        // Save to Core Data
                                        do {
                                            try context.save()
                                            
                                            // If trend tracking is enabled, set up tracking
                                            if trendTrackingEnabled {
                                                setupTrendTracking(for: test)
                                            }
                                            
                                            showingAddTest = false
                                        } catch {
                                            print("Failed to save test: \(error.localizedDescription)")
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                            Text("Save Test")
                                        }
                                        .padding()
                                        .foregroundColor(.white)
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                    }
                                }
                                .padding()
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                        }
                        .tag(6)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    // Navigation buttons
                    HStack {
                        if currentStep > 1 {
                            Button(action: {
                                withAnimation {
                                    currentStep -= 1
                                }
                            }) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Back")
                                }
                                .padding()
                                .foregroundColor(.blue)
                            }
                        }
                        
                        Spacer()
                        
                        if currentStep < 6 {
                            Button(action: {
                                withAnimation {
                                    currentStep += 1
                                }
                            }) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .padding()
                                .foregroundColor(.white)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                        } else {
                            // Step 6 is the final step, no next button needed
                            EmptyView()
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                }
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingAddTest = false
                        }
                    }
                }
            }
        }
        .onAppear {
            requestHealthKitAuthorization()
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingSettings = true }) {
                    Image(systemName: "gear")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            NavigationView {
                SettingsView(viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingTrends) {
            NavigationView {
                VStack {
                    // Metric selector with improved accessibility
                    Picker("Select Metric", selection: $selectedMetric) {
                        Text("Heart Rate").tag("Heart Rate")
                        Text("Heart Rate Variability").tag("Heart Rate Variability")
                        Text("Oxygen Saturation").tag("Oxygen Saturation")
                        Text("Respiratory Rate").tag("Respiratory Rate")
                        Text("Body Temperature").tag("Body Temperature")
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    .accessibilityLabel("Select health metric to view trends")
                    
                    if isLoadingTrends {
                        ProgressView("Loading trends...")
                            .accessibilityLabel("Loading health data trends")
                    } else if let data = trendData[selectedMetric], !data.isEmpty {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                // Chart visualization with enhanced accessibility
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Trend")
                                        .font(.headline)
                                    
                                    Chart {
                                        ForEach(data.sorted(by: { $0.date < $1.date }), id: \.date) { reading in
                                            LineMark(
                                                x: .value("Time", reading.date),
                                                y: .value("Value", reading.value)
                                            )
                                            .foregroundStyle(Color.blue)
                                            .interpolationMethod(.catmullRom)
                                            
                                            PointMark(
                                                x: .value("Time", reading.date),
                                                y: .value("Value", reading.value)
                                            )
                                            .foregroundStyle(Color.blue)
                                            .accessibilityLabel("\(reading.date.formatted()) - \(String(format: "%.1f", reading.value))")
                                        }
                                    }
                                    .frame(height: 200)
                                    .chartXAxis {
                                        AxisMarks(values: .stride(by: .day)) { value in
                                            AxisGridLine()
                                            AxisValueLabel(format: .dateTime.month().day())
                                        }
                                    }
                                    .chartYAxis {
                                        AxisMarks { value in
                                            AxisGridLine()
                                            AxisValueLabel {
                                                if let doubleValue = value.as(Double.self) {
                                                    Text(String(format: "%.1f", doubleValue))
                                                }
                                            }
                                        }
                                    }
                                    .accessibilityElement(children: .combine)
                                    .accessibilityLabel("\(selectedMetric) trend over the last 7 days")
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                                
                                // Trend Analysis Section
                                if let analysis = trendAnalysis[selectedMetric] {
                                    VStack(alignment: .leading, spacing: 12) {
                                        Text("Trend Analysis")
                                            .font(.headline)
                                        
                                        VStack(spacing: 16) {
                                            // Trend Direction
                                            HStack {
                                                Image(systemName: analysis.direction.icon)
                                                    .foregroundColor(analysis.direction.color)
                                                    .font(.title2)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Direction")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Text(analysis.direction.description)
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(analysis.direction.color)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text("Confidence")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Text("\(Int(analysis.confidence * 100))%")
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                            .padding()
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                            .shadow(radius: 1)
                                            
                                            // Health Status
                                            HStack {
                                                Circle()
                                                    .fill(analysis.healthStatus.color)
                                                    .frame(width: 12, height: 12)
                                                
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text("Health Status")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Text(analysis.healthStatus.description)
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(analysis.healthStatus.color)
                                                }
                                                
                                                Spacer()
                                                
                                                VStack(alignment: .trailing, spacing: 4) {
                                                    Text("Rate of Change")
                                                        .font(.subheadline)
                                                        .foregroundColor(.secondary)
                                                    Text(String(format: "%.1f%%", analysis.rateOfChange * 100))
                                                        .font(.title3)
                                                        .fontWeight(.semibold)
                                                }
                                            }
                                            .padding()
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                            .shadow(radius: 1)
                                            
                                            // Recommendation
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Recommendation")
                                                    .font(.subheadline)
                                                    .foregroundColor(.secondary)
                                                Text(analysis.recommendation)
                                                    .font(.body)
                                                    .foregroundColor(.primary)
                                                    .lineSpacing(2)
                                            }
                                            .padding()
                                            .background(Color(.systemBackground))
                                            .cornerRadius(12)
                                            .shadow(radius: 1)
                                        }
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(radius: 2)
                                }
                                
                                // Summary statistics with enhanced descriptions
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Summary")
                                        .font(.headline)
                                    
                                    let values = data.map { $0.value }
                                    let average = values.reduce(0, +) / Double(values.count)
                                    let min = values.min() ?? 0
                                    let max = values.max() ?? 0
                                    
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text("Average")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.1f", average))
                                                .font(.title2)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Average \(selectedMetric): \(String(format: "%.1f", average))")
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading) {
                                            Text("Min")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.1f", min))
                                                .font(.title2)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Minimum \(selectedMetric): \(String(format: "%.1f", min))")
                                        
                                        Spacer()
                                        
                                        VStack(alignment: .leading) {
                                            Text("Max")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Text(String(format: "%.1f", max))
                                                .font(.title2)
                                        }
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("Maximum \(selectedMetric): \(String(format: "%.1f", max))")
                                    }
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .cornerRadius(12)
                                    .shadow(radius: 2)
                                }
                                
                                // Recent readings with enhanced accessibility
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Recent Readings")
                                        .font(.headline)
                                    
                                    ForEach(data.prefix(10), id: \.date) { reading in
                                        HStack {
                                            Text(reading.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text(String(format: "%.1f", reading.value))
                                                .font(.subheadline)
                                                .bold()
                                        }
                                        .padding(.vertical, 4)
                                        .accessibilityElement(children: .combine)
                                        .accessibilityLabel("\(reading.date.formatted()) - \(String(format: "%.1f", reading.value))")
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(12)
                                .shadow(radius: 2)
                            }
                            .padding()
                        }
                    } else {
                        Text("No data available")
                            .foregroundColor(.secondary)
                            .accessibilityLabel("No \(selectedMetric) data available")
                    }
                }
                .navigationTitle("Health Trends")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingTrends = false
                        }
                        .accessibilityLabel("Close trends view")
                    }
                }
                .onAppear {
                    fetchTrendData()
                }
                .onChange(of: selectedMetric) { oldValue, newValue in
                    fetchTrendData()
                }
            }
        }
    }
    
    // Helper function to get historical test count
    private func getHistoricalTestCount(for testType: String) -> Int {
        let context = PersistenceController.shared.container.viewContext
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: "BloodTestEntity")
        fetchRequest.predicate = NSPredicate(format: "testType == %@", testType)
        
        do {
            let results = try context.fetch(fetchRequest)
            return results.count
        } catch {
            print("Error fetching historical tests: \(error.localizedDescription)")
            return 0
        }
    }
    
    // Helper function to setup trend tracking
    private func setupTrendTracking(for test: BloodTest) {
        // Store trend tracking preferences
        UserDefaults.standard.set(enableNotifications, forKey: "trendTracking_notifications_\(test.testType)")
        UserDefaults.standard.set(enableCharts, forKey: "trendTracking_charts_\(test.testType)")
        UserDefaults.standard.set(enableGoals, forKey: "trendTracking_goals_\(test.testType)")
        
        print("Trend tracking enabled for \(test.testType)")
        print("- Notifications: \(enableNotifications)")
        print("- Charts: \(enableCharts)")
        print("- Goals: \(enableGoals)")
    }
    
    private func requestHealthKitAuthorization() {
        // Define the types we want to read from HealthKit
        var typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!,
            HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!,
            HKObjectType.quantityType(forIdentifier: .oxygenSaturation)!,
            HKObjectType.quantityType(forIdentifier: .bodyTemperature)!,
            HKObjectType.quantityType(forIdentifier: .respiratoryRate)!,
            HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
            HKObjectType.electrocardiogramType()
        ]
        
        // Add basal body temperature if available
        if let basalTemperatureType = HKObjectType.quantityType(forIdentifier: .basalBodyTemperature) {
            typesToRead.insert(basalTemperatureType)
        }
        
        // Request authorization
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
            DispatchQueue.main.async {
                if success {
                    isAuthorized = true
                    fetchLatestVitalSigns()
                } else {
                    print("HealthKit authorization failed: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
    
    private func fetchLatestVitalSigns() {
        guard isAuthorized else { return }
        
        // Use a background queue for data fetching
        DispatchQueue.global(qos: .userInitiated).async {
            // Function to process HRV samples
            func processHRVSamples(samples: [HKSample], type: String) {
                guard !samples.isEmpty else {
                    print("⚠️ No \(type) HRV samples found in the last 48 hours")
                    return
                }
                
                print("\nAvailable \(type) HRV samples:")
                var totalValue: Double = 0
                var count: Int = 0
                var validReadings: [(value: Double, date: Date)] = []
                
                // HRV validation ranges (in milliseconds)
                let minValidHRV: Double = 5.0  // Minimum reasonable HRV
                let maxValidHRV: Double = 200.0 // Maximum reasonable HRV
                
                for (index, sample) in samples.enumerated() {
                    if let hrvSample = sample as? HKQuantitySample {
                        let value = hrvSample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli))
                        let date = hrvSample.endDate
                        let source = hrvSample.sourceRevision.source.name
                        let device = hrvSample.device?.name ?? "Unknown device"
                        let sourceVersion = hrvSample.sourceRevision.version
                        let sourceProductType = hrvSample.sourceRevision.productType ?? "Unknown"
                        
                        // Validate the reading
                        let isValid = value >= minValidHRV && value <= maxValidHRV
                        if isValid {
                            totalValue += value
                            count += 1
                            validReadings.append((value: value, date: date))
                        }
                        
                        print("\nSample \(index + 1):")
                        print("   - Value: \(String(format: "%.1f", value)) ms")
                        print("   - Date: \(date.formatted())")
                        print("   - Source: \(source)")
                        print("   - Device: \(device)")
                        print("   - Source Version: \(String(describing: sourceVersion))")
                        print("   - Product Type: \(sourceProductType)")
                        print("   - Time since reading: \(Int(-date.timeIntervalSinceNow/60)) minutes ago")
                        print("   - Quality: \(isValid ? "✅ Valid" : "⚠️ Outside normal range")")
                    }
                }
                
                if count > 0 {
                    let average = totalValue / Double(count)
                    print("\n📊 \(type) HRV Statistics:")
                    print("   - Number of readings: \(count)")
                    print("   - Average value: \(String(format: "%.1f", average)) ms")
                    
                    // Calculate reading quality
                    if let firstReading = validReadings.first {
                        let timeSinceLastReading = -firstReading.date.timeIntervalSinceNow
                        let readingQuality: String
                        if timeSinceLastReading < 30 * 60 { // Less than 30 minutes
                            readingQuality = "✅ Very Recent"
                        } else if timeSinceLastReading < 2 * 60 * 60 { // Less than 2 hours
                            readingQuality = "✅ Recent"
                        } else if timeSinceLastReading < 6 * 60 * 60 { // Less than 6 hours
                            readingQuality = "⚠️ Somewhat Old"
                        } else {
                            readingQuality = "❌ Outdated"
                        }
                        
                        print("   - Reading Quality: \(readingQuality)")
                        print("   - Time since last reading: \(Int(timeSinceLastReading/60)) minutes")
                        
                        print("\n✅ Using most recent \(type) HRV reading:")
                        print("   - Value: \(String(format: "%.1f", firstReading.value)) ms")
                        print("   - Date: \(firstReading.date.formatted())")
                        print("   - Time since reading: \(Int(timeSinceLastReading/60)) minutes ago")
                        
                        DispatchQueue.main.async {
                            self.heartRateVariability = (firstReading.value, firstReading.date)
                        }
                    }
                }
            }
            
            // Create a dispatch group to coordinate multiple queries
            let group = DispatchGroup()
            
            // Fetch heart rate
            group.enter()
            if let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) {
                self.fetchLatestValue(for: heartRateType, unit: HKUnit.count().unitDivided(by: .minute())) { value, date in
                    DispatchQueue.main.async {
                        self.heartRate = (value, date)
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
            
            // Fetch blood pressure
            group.enter()
            self.fetchLatestBloodPressure()
            group.leave()
            
            // Fetch oxygen saturation
            group.enter()
            if let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) {
                self.fetchLatestValue(for: oxygenType, unit: HKUnit.percent()) { value, date in
                    DispatchQueue.main.async {
                        self.oxygenSaturation = (value != nil ? value! * 100 : nil, date)
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
            
            // Fetch temperature
            group.enter()
            self.fetchLatestTemperature()
            group.leave()
            
            // Fetch respiratory rate
            group.enter()
            if let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) {
                self.fetchLatestValue(for: respiratoryType, unit: HKUnit.count().unitDivided(by: .minute())) { value, date in
                    DispatchQueue.main.async {
                        self.respiratoryRate = (value, date)
                    }
                    group.leave()
                }
            } else {
                group.leave()
            }
            
            // Fetch heart rate variability
            group.enter()
            print("\n=== Fetching Heart Rate Variability ===")
            let startDate = Date().addingTimeInterval(-48*60*60)
            let endDate = Date()
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            
            print("Time window: \(startDate) to \(endDate)")
            
            if let sdnnType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) {
                print("\n--- SDNN HRV ---")
                let sdnnQuery = HKSampleQuery(sampleType: sdnnType, predicate: predicate, limit: 10, sortDescriptors: [sortDescriptor]) { _, samples, error in
                    if let error = error {
                        print("❌ Error fetching SDNN HRV: \(error.localizedDescription)")
                    } else {
                        processHRVSamples(samples: samples ?? [], type: "SDNN")
                    }
                    group.leave()
                }
                self.healthStore.execute(sdnnQuery)
            } else {
                group.leave()
            }
            
            // Fetch ECG
            group.enter()
            self.fetchLatestECG()
            group.leave()
            
            // Wait for all queries to complete
            group.notify(queue: .main) {
                print("All health data queries completed")
            }
        }
    }

    // Fetch Blood Pressure as correlation
    private func fetchLatestBloodPressure() {
        guard let bloodPressureType = HKObjectType.correlationType(forIdentifier: .bloodPressure) else { return }
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: bloodPressureType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            guard let sample = samples?.first as? HKCorrelation else {
                DispatchQueue.main.async {
                    self.bloodPressure = (nil, nil, nil)
                }
                return
            }
            let systolicSample = sample.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic)!).first as? HKQuantitySample
            let diastolicSample = sample.objects(for: HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic)!).first as? HKQuantitySample
            let systolic = systolicSample?.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
            let diastolic = diastolicSample?.quantity.doubleValue(for: HKUnit.millimeterOfMercury())
            let date = sample.endDate
            DispatchQueue.main.async {
                self.bloodPressure = (systolic, diastolic, date)
            }
        }
        healthStore.execute(query)
    }

    // Fetch ECG
    private func fetchLatestECG() {
        if #available(iOS 14.0, *) {
            let ecgType = HKObjectType.electrocardiogramType()
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: ecgType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                guard let sample = samples?.first as? HKElectrocardiogram else {
                    DispatchQueue.main.async {
                        self.ecgData = []
                    }
                    return
                }
                let value = sample.averageHeartRate?.doubleValue(for: HKUnit.count().unitDivided(by: .minute())) ?? 0.0
                let date = sample.endDate
                DispatchQueue.main.async {
                    self.ecgData = [(date: date, value: value)]
                }
            }
            healthStore.execute(query)
        }
    }
    
    private func fetchLatestValue(for quantityType: HKQuantityType, unit: HKUnit, completion: @escaping (Double?, Date?) -> Void) {
        // Extend the time window to 7 days instead of 24 hours
        let startDate = Date().addingTimeInterval(-7*24*60*60)
        let endDate = Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        print("\n=== Fetching \(quantityType.identifier) ===")
        print("Time window: \(startDate) to \(endDate)")
        
        let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("❌ Error fetching \(quantityType.identifier): \(error.localizedDescription)")
                completion(nil, nil)
                return
            }
            
            guard let sample = samples?.first as? HKQuantitySample else {
                print("⚠️ No samples found for \(quantityType.identifier) in the last 7 days")
                completion(nil, nil)
                return
            }
            
            let value = sample.quantity.doubleValue(for: unit)
            let date = sample.endDate
            let source = sample.sourceRevision.source.name
            let device = sample.device?.name ?? "Unknown device"
            
            print("✅ Found \(quantityType.identifier):")
            print("   - Value: \(value) \(unit)")
            print("   - Date: \(date)")
            print("   - Source: \(source)")
            print("   - Device: \(device)")
            print("   - Time since reading: \(Int(-date.timeIntervalSinceNow/60)) minutes ago")
            
            completion(value, date)
        }
        
        healthStore.execute(query)
    }

    private func fetchLatestTemperature() {
        // Try body temperature first
        if let temperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: temperatureType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let sample = samples?.first as? HKQuantitySample {
                    let celsius = sample.quantity.doubleValue(for: HKUnit.degreeCelsius())
                    let fahrenheit = (celsius * 9.0 / 5.0) + 32.0
                    let date = sample.endDate
                    print("Fetched body temperature: \(celsius)°C, \(fahrenheit)°F at \(date)")
                    DispatchQueue.main.async {
                        self.temperature = (fahrenheit, date)
                    }
                } else {
                    // If not found, try basal body temperature
                    if let basalType = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) {
                        let basalQuery = HKSampleQuery(sampleType: basalType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, basalSamples, _ in
                            if let basalSample = basalSamples?.first as? HKQuantitySample {
                                let celsius = basalSample.quantity.doubleValue(for: HKUnit.degreeCelsius())
                                let fahrenheit = (celsius * 9.0 / 5.0) + 32.0
                                let date = basalSample.endDate
                                print("Fetched basal body temperature: \(celsius)°C, \(fahrenheit)°F at \(date)")
                                DispatchQueue.main.async {
                                    self.temperature = (fahrenheit, date)
                                }
                            } else {
                                print("No temperature data found in HealthKit.")
                                DispatchQueue.main.async {
                                    self.temperature = (nil, nil)
                                }
                            }
                        }
                        healthStore.execute(basalQuery)
                    } else {
                        print("No temperature data found in HealthKit.")
                        DispatchQueue.main.async {
                            self.temperature = (nil, nil)
                        }
                    }
                }
            }
            healthStore.execute(query)
        }
    }
    
    // Add function to fetch trend data
    private func fetchTrendData() {
        isLoadingTrends = true
        
        // Clear existing data
        trendData[selectedMetric] = []
        trendAnalysis[selectedMetric] = nil
        
        // Special handling for Body Temperature
        if selectedMetric == "Body Temperature" {
            fetchTemperatureTrendData()
            return
        }
        
        // Determine the quantity type and unit based on selected metric
        let (quantityType, unit): (HKQuantityType?, HKUnit) = {
            switch selectedMetric {
            case "Heart Rate":
                return (HKQuantityType.quantityType(forIdentifier: .heartRate),
                       HKUnit.count().unitDivided(by: .minute()))
            case "Heart Rate Variability":
                return (HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
                       HKUnit.secondUnit(with: .milli))
            case "Oxygen Saturation":
                return (HKQuantityType.quantityType(forIdentifier: .oxygenSaturation),
                       HKUnit.percent())
            case "Respiratory Rate":
                return (HKQuantityType.quantityType(forIdentifier: .respiratoryRate),
                       HKUnit.count().unitDivided(by: .minute()))
            default:
                return (nil, HKUnit.count())
            }
        }()
        
        guard let type = quantityType else {
            isLoadingTrends = false
            return
        }
        
        // Fetch last 7 days of data
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
            if let error = error {
                print("Error fetching trend data: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoadingTrends = false
                }
                return
            }
            
            let readings = samples?.compactMap { sample -> (date: Date, value: Double)? in
                guard let quantitySample = sample as? HKQuantitySample else { return nil }
                let value = quantitySample.quantity.doubleValue(for: unit)
                return (date: quantitySample.endDate, value: value)
            } ?? []
            
            DispatchQueue.main.async {
                self.trendData[selectedMetric] = readings
                
                // Analyze the trend
                if !readings.isEmpty {
                    self.trendAnalysis[selectedMetric] = self.analyzeTrend(for: readings, metric: selectedMetric)
                }
                
                self.isLoadingTrends = false
            }
        }
        
        healthStore.execute(query)
    }
    
    // Special function to fetch temperature trend data
    private func fetchTemperatureTrendData() {
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: Date(), options: .strictEndDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Try body temperature first
        if let temperatureType = HKQuantityType.quantityType(forIdentifier: .bodyTemperature) {
            let query = HKSampleQuery(sampleType: temperatureType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("Error fetching body temperature trend data: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.isLoadingTrends = false
                    }
                    return
                }
                
                let readings = samples?.compactMap { sample -> (date: Date, value: Double)? in
                    guard let quantitySample = sample as? HKQuantitySample else { return nil }
                    let celsius = quantitySample.quantity.doubleValue(for: HKUnit.degreeCelsius())
                    let fahrenheit = (celsius * 9.0 / 5.0) + 32.0
                    return (date: quantitySample.endDate, value: fahrenheit)
                } ?? []
                
                if !readings.isEmpty {
                    DispatchQueue.main.async {
                        self.trendData[selectedMetric] = readings
                        self.trendAnalysis[selectedMetric] = self.analyzeTrend(for: readings, metric: selectedMetric)
                        self.isLoadingTrends = false
                    }
                } else {
                    // If no body temperature data, try basal body temperature
                    self.fetchBasalTemperatureTrendData(predicate: predicate, sortDescriptor: sortDescriptor)
                }
            }
            healthStore.execute(query)
        } else {
            self.fetchBasalTemperatureTrendData(predicate: predicate, sortDescriptor: sortDescriptor)
        }
    }
    
    private func fetchBasalTemperatureTrendData(predicate: NSPredicate, sortDescriptor: NSSortDescriptor) {
        if let basalType = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) {
            let query = HKSampleQuery(sampleType: basalType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    print("Error fetching basal temperature trend data: \(error.localizedDescription)")
                    // Check if it's an authorization error
                    if let hkError = error as? HKError {
                        switch hkError.code {
                        case .errorAuthorizationDenied:
                            print("Basal temperature access denied. User needs to authorize in Health app.")
                        case .errorAuthorizationNotDetermined:
                            print("Basal temperature authorization not determined. Requesting authorization...")
                            DispatchQueue.main.async {
                                self.requestHealthKitAuthorization()
                            }
                        default:
                            print("HealthKit error: \(hkError.localizedDescription)")
                        }
                    }
                    DispatchQueue.main.async {
                        self.isLoadingTrends = false
                    }
                    return
                }
                
                let readings = samples?.compactMap { sample -> (date: Date, value: Double)? in
                    guard let quantitySample = sample as? HKQuantitySample else { return nil }
                    let celsius = quantitySample.quantity.doubleValue(for: HKUnit.degreeCelsius())
                    let fahrenheit = (celsius * 9.0 / 5.0) + 32.0
                    return (date: quantitySample.endDate, value: fahrenheit)
                } ?? []
                
                DispatchQueue.main.async {
                    self.trendData[selectedMetric] = readings
                    if !readings.isEmpty {
                        self.trendAnalysis[selectedMetric] = self.analyzeTrend(for: readings, metric: selectedMetric)
                    }
                    self.isLoadingTrends = false
                }
            }
            healthStore.execute(query)
        } else {
            DispatchQueue.main.async {
                self.isLoadingTrends = false
            }
        }
    }
    
    // Add function to analyze trends
    private func analyzeTrend(for data: [(date: Date, value: Double)], metric: String) -> TrendAnalysis {
        guard data.count >= 3 else {
            return TrendAnalysis(
                direction: .stable,
                rateOfChange: 0.0,
                healthStatus: .good,
                recommendation: "Insufficient data for trend analysis. Continue monitoring for more accurate insights.",
                confidence: 0.0
            )
        }
        
        let sortedData = data.sorted { $0.date < $1.date }
        let values = sortedData.map { $0.value }
        
        // Calculate rate of change
        let firstValue = values.first!
        let lastValue = values.last!
        let rateOfChange = (lastValue - firstValue) / firstValue
        
        // Calculate trend direction
        let direction: TrendDirection
        let confidence: Double
        
        if abs(rateOfChange) < 0.05 { // Less than 5% change
            direction = .stable
            confidence = 0.8
        } else if rateOfChange > 0.1 { // More than 10% increase
            direction = .improving
            confidence = 0.9
        } else if rateOfChange < -0.1 { // More than 10% decrease
            direction = .declining
            confidence = 0.9
        } else {
            direction = .fluctuating
            confidence = 0.7
        }
        
        // Determine health status based on metric and values
        let healthStatus = determineHealthStatus(for: metric, values: values)
        
        // Generate recommendation
        let recommendation = generateRecommendation(for: metric, direction: direction, healthStatus: healthStatus, rateOfChange: rateOfChange)
        
        return TrendAnalysis(
            direction: direction,
            rateOfChange: rateOfChange,
            healthStatus: healthStatus,
            recommendation: recommendation,
            confidence: confidence
        )
    }
    
    private func determineHealthStatus(for metric: String, values: [Double]) -> HealthStatus {
        let average = values.reduce(0, +) / Double(values.count)
        
        switch metric {
        case "Heart Rate":
            if average < 60 { return .excellent }
            else if average < 80 { return .good }
            else if average < 100 { return .fair }
            else if average < 120 { return .poor }
            else { return .critical }
            
        case "Heart Rate Variability":
            if average > 50 { return .excellent }
            else if average > 30 { return .good }
            else if average > 20 { return .fair }
            else if average > 10 { return .poor }
            else { return .critical }
            
        case "Oxygen Saturation":
            if average > 98 { return .excellent }
            else if average > 95 { return .good }
            else if average > 92 { return .fair }
            else if average > 90 { return .poor }
            else { return .critical }
            
        case "Respiratory Rate":
            if average >= 12 && average <= 16 { return .excellent }
            else if average >= 10 && average <= 18 { return .good }
            else if average >= 8 && average <= 20 { return .fair }
            else if average >= 6 && average <= 24 { return .poor }
            else { return .critical }
            
        case "Body Temperature":
            if average >= 97.8 && average <= 99.0 { return .excellent }
            else if average >= 97.0 && average <= 99.5 { return .good }
            else if average >= 96.0 && average <= 100.4 { return .fair }
            else if average >= 95.0 && average <= 101.0 { return .poor }
            else { return .critical }
            
        default:
            return .good
        }
    }
    
    private func generateRecommendation(for metric: String, direction: TrendDirection, healthStatus: HealthStatus, rateOfChange: Double) -> String {
        switch metric {
        case "Heart Rate":
            switch direction {
            case .improving:
                return "Your heart rate is trending downward, which is generally positive. This may indicate improved cardiovascular fitness or reduced stress levels. Continue with your current healthy lifestyle habits."
            case .declining:
                return "Your heart rate is trending upward. Consider factors like stress, caffeine, or physical activity. If this trend continues, consult with a healthcare provider."
            case .stable:
                return "Your heart rate is stable, which is good. Maintain your current healthy habits including regular exercise and stress management."
            case .fluctuating:
                return "Your heart rate shows variability. This is normal and may indicate good cardiovascular health. Monitor for any concerning patterns."
            }
            
        case "Heart Rate Variability":
            switch direction {
            case .improving:
                return "Your HRV is improving, indicating better cardiovascular health and stress resilience. Continue with stress management techniques and regular exercise."
            case .declining:
                return "Your HRV is decreasing, which may indicate increased stress or fatigue. Focus on stress reduction, adequate sleep, and relaxation techniques."
            case .stable:
                return "Your HRV is stable. Consider incorporating stress management techniques and regular exercise to potentially improve it further."
            case .fluctuating:
                return "Your HRV shows natural variability. This is normal and indicates your body is responding appropriately to different situations."
            }
            
        case "Oxygen Saturation":
            switch direction {
            case .improving:
                return "Your oxygen saturation is improving. This is excellent for overall health and indicates good respiratory function."
            case .declining:
                return "Your oxygen saturation is decreasing. This may indicate respiratory issues. Consider consulting a healthcare provider if this trend continues."
            case .stable:
                return "Your oxygen saturation is stable and within normal range. Continue maintaining good respiratory health through regular exercise."
            case .fluctuating:
                return "Your oxygen saturation shows some variability. Monitor for any concerning symptoms and maintain good respiratory health."
            }
            
        case "Respiratory Rate":
            switch direction {
            case .improving:
                return "Your respiratory rate is normalizing, indicating improved respiratory health and reduced stress levels."
            case .declining:
                return "Your respiratory rate is increasing. This may indicate stress, anxiety, or respiratory issues. Practice deep breathing exercises."
            case .stable:
                return "Your respiratory rate is stable and within normal range. Continue with regular breathing exercises and stress management."
            case .fluctuating:
                return "Your respiratory rate shows natural variability. This is normal and indicates your body is responding appropriately."
            }
            
        case "Body Temperature":
            switch direction {
            case .improving:
                return "Your body temperature is normalizing, indicating good health and proper thermoregulation."
            case .declining:
                return "Your body temperature is increasing. Monitor for signs of fever or infection. Rest and stay hydrated."
            case .stable:
                return "Your body temperature is stable and within normal range. Continue maintaining good health practices."
            case .fluctuating:
                return "Your body temperature shows normal daily variations. This is typical and indicates good thermoregulation."
            }
            
        default:
            return "Continue monitoring this metric and consult with a healthcare provider if you notice concerning trends."
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    let date: Date? // Add optional date parameter
    @State private var showingExplanation = false
    @State private var animate = false
    
    // Initialize without date for backward compatibility
    init(title: String, value: String, unit: String, icon: String, color: Color) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.color = color
        self.date = nil
    }
    
    // Initialize with date
    init(title: String, value: String, unit: String, icon: String, color: Color, date: Date?) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.color = color
        self.date = date
    }
    
    // Format the reading label based on title and date
    private var readingLabel: String {
        if date != nil {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return "Last reading as of \(formatter.string(from: date!))"
        }
        return "Current Reading"
    }
    
    var explanation: String {
        switch title {
        case "Heart Rate":
            return "Heart rate measures how many times your heart beats per minute (BPM). A normal resting heart rate for adults ranges from 60 to 100 BPM. Factors like age, fitness level, and activity can affect your heart rate."
        case "Blood Pressure":
            return "Blood pressure measures the force of blood against artery walls. It's shown as two numbers: systolic (top) and diastolic (bottom). Normal blood pressure is typically below 120/80 mmHg. High blood pressure can indicate cardiovascular issues."
        case "Oxygen":
            return "Oxygen saturation (SpO2) measures how much oxygen your blood is carrying. Normal levels are between 95-100%. Levels below 90% may indicate a need for medical attention. This is especially important for monitoring respiratory health."
        case "Temperature":
            return "Body temperature indicates your body's ability to regulate heat. Normal body temperature is around 98.6°F (37°C). A temperature above 100.4°F (38°C) may indicate a fever, while below 95°F (35°C) may indicate hypothermia."
        case "Respiratory Rate":
            return "Respiratory rate measures how many breaths you take per minute. Normal adult respiratory rate is 12-20 breaths per minute. Changes in respiratory rate can indicate respiratory problems, anxiety, or other health conditions."
        case "Heart Rate Variability":
            return "Heart Rate Variability (HRV) measures the variation in time between each heartbeat, in milliseconds. Higher HRV is generally associated with better cardiovascular fitness and resilience to stress. Low HRV can indicate stress, fatigue, or underlying health issues."
        case "Latest ECG":
            return "An Electrocardiogram (ECG) records the electrical activity of your heart over a period of time. It helps detect heart rhythm problems and other cardiac conditions. The value shown is the latest measured voltage (in mV) from your ECG data."
        default:
            return ""
        }
    }
    
    var body: some View {
        Button(action: { showingExplanation = true }) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 30))
                    .foregroundColor(color)
                    .scaleEffect(iconScale)
                    .rotationEffect(iconRotation)
                    .offset(y: iconOffset)
                    .animation(iconAnimation, value: animate)
                    .onAppear { animate = true }
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(16)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showingExplanation) {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        HStack {
                            Image(systemName: icon)
                                .font(.system(size: 40))
                                .foregroundColor(color)
                            Text(title)
                                .font(.title)
                                .fontWeight(.bold)
                        }
                        .padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(readingLabel)
                                .font(.headline)
                            Text("\(value) \(unit)")
                                .font(.title2)
                                .foregroundColor(color)
                        }
                        .padding(.bottom, 8)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About \(title)")
                                .font(.headline)
                            Text(explanation)
                                .font(.body)
                                .foregroundColor(.secondary)
                                .lineSpacing(4)
                        }
                    }
                    .padding(20)
                }
                .toolbar {
                    ToolbarItem(placement: .automatic) {
                        Button("Done") {
                            showingExplanation = false
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Icon Animation Properties
    private var iconScale: CGFloat {
        switch title {
        case "Heart Rate":
            return animate ? 1.2 : 1.0
        case "Oxygen":
            return animate ? 1.12 : 1.0
        case "Blood Pressure":
            return animate ? 1.0 : 1.0 // bounce uses offset
        case "Respiratory Rate":
            return animate ? 1.0 : 1.0 // bounce uses offset
        case "Heart Rate Variability":
            return 1.0
        case "Temperature":
            return 1.0
        case "Latest ECG":
            return animate ? 1.15 : 1.0
        default:
            return 1.0
        }
    }
    private var iconRotation: Angle {
        switch title {
        case "Temperature":
            return animate ? .degrees(15) : .degrees(-15)
        case "Heart Rate Variability":
            return animate ? .degrees(-10) : .degrees(10)
        default:
            return .zero
        }
    }
    private var iconOffset: CGFloat {
        switch title {
        case "Blood Pressure":
            return animate ? -8 : 8
        case "Respiratory Rate":
            return animate ? 8 : -8
        default:
            return 0
        }
    }
    private var iconAnimation: Animation {
        switch title {
        case "Heart Rate":
            return .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        case "Oxygen":
            return .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
        case "Blood Pressure":
            return .interpolatingSpring(stiffness: 120, damping: 5).repeatForever(autoreverses: true)
        case "Respiratory Rate":
            return .interpolatingSpring(stiffness: 80, damping: 7).repeatForever(autoreverses: true)
        case "Heart Rate Variability":
            return .easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        case "Temperature":
            return .easeInOut(duration: 1.4).repeatForever(autoreverses: true)
        case "Latest ECG":
            return .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
        default:
            return .default
        }
    }
}

// Helper Views for each test type
struct TestTypeButton: View {
    let title: String
    let description: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(.red)
                    Text(title)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding()
            .background(Color(UIColor.systemBackground))
            .cornerRadius(10)
        }
    }
}

struct TestField: View {
    let title: String
    let description: String
    let unit: String
    let referenceRange: String
    @Binding var value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
            HStack {
                TextField("Enter value", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(UIKeyboardType.numbersAndPunctuation)
                Text(unit)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            Text("Reference Range: \(referenceRange)")
                .font(.caption)
                .foregroundColor(.blue)
        }
        .padding(.vertical, 8)
    }
}

struct CBCForm: View {
    // WBC and Differential
    @Binding var wbc: String
    @Binding var neutrophilsPercent: String
    @Binding var neutrophilsAbsolute: String
    @Binding var lymphocytesPercent: String
    @Binding var lymphocytesAbsolute: String
    @Binding var monocytesPercent: String
    @Binding var monocytesAbsolute: String
    @Binding var eosinophilsPercent: String
    @Binding var eosinophilsAbsolute: String
    @Binding var basophilsPercent: String
    @Binding var basophilsAbsolute: String
    
    // RBC Parameters
    @Binding var rbc: String
    @Binding var hgb: String
    @Binding var hct: String
    @Binding var mcv: String
    @Binding var mch: String
    @Binding var mchc: String
    @Binding var rdw: String
    
    // Platelet Parameters
    @Binding var plt: String
    @Binding var mpv: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Complete Blood Count (CBC) Results")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("Enter your CBC test results below. These values help assess your overall blood health.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            
            // WBC Section
            Group {
                Text("White Blood Cells (WBC)")
                    .font(.headline)
                    .padding(.top, 8)
                
                TestField(
                    title: "WBC",
                    description: "Measures immune cells. High levels may indicate infection or inflammation; low levels may suggest immune suppression.",
                    unit: "K/µL",
                    referenceRange: "4.5-11.0 K/µL",
                    value: $wbc
                )
                
                // WBC Differential
                Group {
                    TestField(
                        title: "Neutrophils %",
                        description: "A type of WBC that fights bacteria. Elevated in bacterial infections. Low levels (neutropenia) may indicate bone marrow problems or severe infection. High levels (neutrophilia) often indicate bacterial infection, inflammation, or stress.",
                        unit: "%",
                        referenceRange: "40-60%",
                        value: $neutrophilsPercent
                    )
                    TestField(
                        title: "Neutrophils #",
                        description: "Absolute neutrophil count (ANC). Critical for immune function. ANC < 500/µL indicates severe neutropenia with high infection risk. ANC > 7,700/µL suggests neutrophilia, often due to infection or inflammation.",
                        unit: "K/µL",
                        referenceRange: "1.8-7.7 K/µL",
                        value: $neutrophilsAbsolute
                    )
                    
                    TestField(
                        title: "Lymphocytes %",
                        description: "Lymphocytes fight viral infections. High in viral infections; low in immune suppression.",
                        unit: "%",
                        referenceRange: "20-40%",
                        value: $lymphocytesPercent
                    )
                    TestField(
                        title: "Lymphocytes #",
                        description: "Absolute lymphocyte count",
                        unit: "K/µL",
                        referenceRange: "1.0-4.8 K/µL",
                        value: $lymphocytesAbsolute
                    )
                    
                    TestField(
                        title: "Monocytes %",
                        description: "Monocytes help remove dead cells. Elevated in chronic infections or inflammation.",
                        unit: "%",
                        referenceRange: "2-8%",
                        value: $monocytesPercent
                    )
                    TestField(
                        title: "Monocytes #",
                        description: "Absolute monocyte count",
                        unit: "K/µL",
                        referenceRange: "0.2-0.8 K/µL",
                        value: $monocytesAbsolute
                    )
                    
                    TestField(
                        title: "Eosinophils %",
                        description: "Eosinophils increase in allergies or parasitic infections.",
                        unit: "%",
                        referenceRange: "1-4%",
                        value: $eosinophilsPercent
                    )
                    TestField(
                        title: "Eosinophils #",
                        description: "Absolute eosinophil count",
                        unit: "K/µL",
                        referenceRange: "0.1-0.5 K/µL",
                        value: $eosinophilsAbsolute
                    )
                    
                    TestField(
                        title: "Basophils %",
                        description: "Basophils are involved in allergic responses. Usually a small percentage.",
                        unit: "%",
                        referenceRange: "0.5-1%",
                        value: $basophilsPercent
                    )
                    TestField(
                        title: "Basophils #",
                        description: "Absolute basophil count",
                        unit: "K/µL",
                        referenceRange: "0.01-0.1 K/µL",
                        value: $basophilsAbsolute
                    )
                }
            }
            
            // RBC Section
            Group {
                Text("Red Blood Cell Parameters")
                    .font(.headline)
                    .padding(.top, 8)
                
                TestField(
                    title: "RBC",
                    description: "Carries oxygen. Low levels = anemia; high levels = dehydration or other conditions.",
                    unit: "M/µL",
                    referenceRange: "4.5-5.5 M/µL",
                    value: $rbc
                )
                
                TestField(
                    title: "Hemoglobin (HGB)",
                    description: "Protein in RBCs that carries oxygen. Low = anemia.",
                    unit: "g/dL",
                    referenceRange: "13.5-17.5 g/dL",
                    value: $hgb
                )
                
                TestField(
                    title: "Hematocrit (HCT)",
                    description: "% of blood volume made of RBCs. Reflects hydration and oxygen-carrying capacity.",
                    unit: "%",
                    referenceRange: "41-50%",
                    value: $hct
                )
                
                TestField(
                    title: "MCV",
                    description: "Average size of RBCs. High = B12/folate deficiency; low = iron deficiency.",
                    unit: "fL",
                    referenceRange: "80-100 fL",
                    value: $mcv
                )
                
                TestField(
                    title: "MCH",
                    description: "Average amount of hemoglobin per RBC.",
                    unit: "pg",
                    referenceRange: "27-33 pg",
                    value: $mch
                )
                
                TestField(
                    title: "MCHC",
                    description: "Concentration of hemoglobin in RBCs.",
                    unit: "g/dL",
                    referenceRange: "32-36 g/dL",
                    value: $mchc
                )
                
                TestField(
                    title: "RDW",
                    description: "Measures variation in RBC size. Helps diagnose anemia types.",
                    unit: "%",
                    referenceRange: "11.5-14.5%",
                    value: $rdw
                )
            }
            
            // Platelet Section
            Group {
                Text("Platelet Parameters")
                    .font(.headline)
                    .padding(.top, 8)
                
                TestField(
                    title: "Platelet Count",
                    description: "Platelets help with clotting. Low = bleeding risk; high = clotting risk.",
                    unit: "K/µL",
                    referenceRange: "150-450 K/µL",
                    value: $plt
                )
                
                TestField(
                    title: "MPV",
                    description: "Size of platelets. Can help assess platelet function.",
                    unit: "fL",
                    referenceRange: "7.5-11.5 fL",
                    value: $mpv
                )
            }
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .cornerRadius(12)
    }
}

struct CMPForm: View {
    @Binding var glucose: String
    @Binding var calcium: String
    @Binding var sodium: String
    @Binding var potassium: String
    @Binding var chloride: String
    @Binding var bicarbonate: String
    @Binding var bun: String
    @Binding var creatinine: String
    @Binding var alt: String
    @Binding var ast: String
    @Binding var alp: String
    @Binding var bilirubin: String
    @Binding var albumin: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TestField(title: "Glucose", description: "Measures blood sugar levels", unit: "mg/dL", referenceRange: "70-100 mg/dL", value: $glucose)
            TestField(title: "Calcium", description: "Essential for bone health and muscle function", unit: "mg/dL", referenceRange: "8.5-10.5 mg/dL", value: $calcium)
            TestField(title: "Sodium", description: "Helps maintain fluid balance", unit: "mmol/L", referenceRange: "135-145 mmol/L", value: $sodium)
            TestField(title: "Potassium", description: "Important for nerve and muscle function", unit: "mmol/L", referenceRange: "3.5-5.5 mmol/L", value: $potassium)
            TestField(title: "Chloride", description: "Helps maintain fluid balance", unit: "mmol/L", referenceRange: "96-106 mmol/L", value: $chloride)
            TestField(title: "Bicarbonate", description: "Helps maintain acid-base balance", unit: "mmol/L", referenceRange: "22-28 mmol/L", value: $bicarbonate)
            TestField(title: "BUN", description: "Measures kidney function", unit: "mg/dL", referenceRange: "10-20 mg/dL", value: $bun)
            TestField(title: "Creatinine", description: "Indicates kidney function", unit: "mg/dL", referenceRange: "0.6-1.2 mg/dL", value: $creatinine)
            TestField(title: "ALT", description: "Liver enzyme", unit: "U/L", referenceRange: "0-40 U/L", value: $alt)
            TestField(title: "AST", description: "Liver enzyme", unit: "U/L", referenceRange: "0-37 U/L", value: $ast)
            TestField(title: "ALP", description: "Liver and bone enzyme", unit: "U/L", referenceRange: "30-120 U/L", value: $alp)
            TestField(title: "Bilirubin", description: "Measures liver function", unit: "mg/dL", referenceRange: "0-0.3 mg/dL", value: $bilirubin)
            TestField(title: "Albumin", description: "Protein made by the liver", unit: "g/dL", referenceRange: "3.5-5.5 g/dL", value: $albumin)
        }
    }
}

struct LipidForm: View {
    @Binding var totalCholesterol: String
    @Binding var hdl: String
    @Binding var ldl: String
    @Binding var triglycerides: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TestField(
                title: "Total Cholesterol",
                description: "Total amount of cholesterol in blood. Includes HDL, LDL, and other lipid components.",
                unit: "mg/dL",
                referenceRange: "120-240 mg/dL",
                value: $totalCholesterol
            )
            TestField(
                title: "HDL",
                description: "High-Density Lipoprotein, often called 'good' cholesterol. Higher levels are better as it helps remove LDL from arteries.",
                unit: "mg/dL",
                referenceRange: "40-60 mg/dL",
                value: $hdl
            )
            TestField(
                title: "LDL",
                description: "Low-Density Lipoprotein, often called 'bad' cholesterol. Ideal range is < 100 mg/dL. Elevated levels increase risk for heart disease and may require lifestyle changes or medication.",
                unit: "mg/dL",
                referenceRange: "0-130 mg/dL",
                value: $ldl
            )
            TestField(
                title: "Triglycerides",
                description: "Type of fat in blood. High levels may increase risk of heart disease and are often associated with metabolic syndrome.",
                unit: "mg/dL",
                referenceRange: "0-150 mg/dL",
                value: $triglycerides
            )
        }
    }
}

struct A1cForm: View {
    @Binding var hba1c: String
    
    var body: some View {
        TestField(title: "Hemoglobin A1c", description: "Average blood sugar over 2-3 months", unit: "%", referenceRange: "4-6%", value: $hba1c)
    }
}

struct ThyroidForm: View {
    @Binding var tsh: String
    @Binding var t3: String
    @Binding var t4: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Thyroid Function Tests")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("These tests help evaluate thyroid gland function and hormone levels.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            
            TestField(
                title: "TSH",
                description: "Thyroid Stimulating Hormone. Primary test for thyroid function. High levels suggest hypothyroidism, low levels suggest hyperthyroidism.",
                unit: "mcIU/mL",
                referenceRange: "0.27-4.2 mcIU/mL",
                value: $tsh
            )
            
            TestField(
                title: "T3",
                description: "Triiodothyronine. Active thyroid hormone. Helps regulate metabolism and energy levels.",
                unit: "ng/dL",
                referenceRange: "1.2-3.0 ng/dL",
                value: $t3
            )
            
            TestField(
                title: "T4",
                description: "Thyroxine. Main thyroid hormone. Helps control metabolism and growth.",
                unit: "µg/dL",
                referenceRange: "0.8-1.8 µg/dL",
                value: $t4
            )
        }
    }
}

struct VitaminDForm: View {
    @Binding var vitaminD: String
    
    var body: some View {
        TestField(title: "Vitamin D (25-OH)", description: "Measures vitamin D levels", unit: "ng/mL", referenceRange: "20-100 ng/mL", value: $vitaminD)
    }
}

struct CRPForm: View {
    @Binding var crp: String
    @Binding var hsCrp: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TestField(title: "CRP", description: "Measures inflammation", unit: "mg/L", referenceRange: "0-5 mg/L", value: $crp)
            TestField(title: "High-Sensitivity CRP", description: "More sensitive measure of inflammation", unit: "mg/L", referenceRange: "<1 mg/L", value: $hsCrp)
        }
    }
}

struct LiverForm: View {
    @Binding var alt: String
    @Binding var ast: String
    @Binding var alp: String
    @Binding var bilirubin: String
    @Binding var albumin: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TestField(
                title: "ALT",
                description: "A liver enzyme that indicates liver cell damage. Slightly elevated levels can suggest liver irritation or damage. Normal levels indicate healthy liver function.",
                unit: "U/L",
                referenceRange: "0-40 U/L",
                value: $alt
            )
            TestField(
                title: "AST",
                description: "Liver enzyme that can indicate liver damage. Often measured alongside ALT to assess liver health.",
                unit: "U/L",
                referenceRange: "0-37 U/L",
                value: $ast
            )
            TestField(
                title: "ALP",
                description: "An enzyme related to bile ducts and bone. Elevated levels may indicate bile duct obstruction or bone disease.",
                unit: "U/L",
                referenceRange: "30-120 U/L",
                value: $alp
            )
            TestField(
                title: "Total Bilirubin",
                description: "Waste product from the breakdown of RBCs. Normal levels indicate good liver function. Elevated levels may suggest liver disease or bile duct problems.",
                unit: "mg/dL",
                referenceRange: "0-0.3 mg/dL",
                value: $bilirubin
            )
            TestField(
                title: "Albumin",
                description: "Protein made by the liver. Low levels may indicate liver disease or malnutrition.",
                unit: "g/dL",
                referenceRange: "3.5-5.5 g/dL",
                value: $albumin
            )
        }
    }
}

struct IronForm: View {
    @Binding var iron: String
    @Binding var ferritin: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TestField(title: "Iron", description: "Measures iron levels in blood", unit: "µg/dL", referenceRange: "50-150 µg/dL", value: $iron)
            TestField(title: "Ferritin", description: "Measures iron storage", unit: "ng/mL", referenceRange: "10-300 ng/mL", value: $ferritin)
        }
    }
}

struct PSAForm: View {
    @Binding var psa: String
    
    var body: some View {
        TestField(title: "PSA", description: "Prostate-specific antigen", unit: "ng/mL", referenceRange: "0-4 ng/mL", value: $psa)
    }
}

struct KidneyFunctionForm: View {
    @Binding var totalProtein: String
    @Binding var bun: String
    @Binding var creatinine: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Kidney Function Tests")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("These tests help evaluate kidney function and protein levels.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            
            TestField(
                title: "Total Protein",
                description: "Measures total protein in blood. Reflects nutrition and liver function.",
                unit: "g/dL",
                referenceRange: "6.4-8.3 g/dL",
                value: $totalProtein
            )
            
            TestField(
                title: "BUN",
                description: "Blood Urea Nitrogen. Measures kidney function. High levels may indicate kidney problems.",
                unit: "mg/dL",
                referenceRange: "6-23 mg/dL",
                value: $bun
            )
            
            TestField(
                title: "Creatinine",
                description: "Waste product from muscle metabolism. Important indicator of kidney function.",
                unit: "mg/dL",
                referenceRange: "0.6-1.2 mg/dL",
                value: $creatinine
            )
        }
    }
}

struct UrinalysisForm: View {
    @Binding var urineColor: String
    @Binding var urineClarity: String
    @Binding var urineGlucose: String
    @Binding var urineKetones: String
    @Binding var urineBlood: String
    @Binding var urineBilirubin: String
    @Binding var urineBacteria: String
    @Binding var squamousCells: String
    @Binding var specificGravity: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Urinalysis Results")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 8)
            
            Text("These tests help assess kidney health, hydration, and signs of infection or diabetes.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom, 16)
            
            TestField(
                title: "Urine Color",
                description: "Indicates hydration status. Yellow is normal, dark yellow may indicate dehydration.",
                unit: "",
                referenceRange: "Yellow",
                value: $urineColor
            )
            
            TestField(
                title: "Urine Clarity",
                description: "Clear urine is normal. Cloudy urine may indicate infection or excess substances.",
                unit: "",
                referenceRange: "Clear",
                value: $urineClarity
            )
            
            TestField(
                title: "Urine Glucose",
                description: "Presence of sugar in urine. Negative is normal. Positive may indicate diabetes.",
                unit: "",
                referenceRange: "Negative",
                value: $urineGlucose
            )
            
            TestField(
                title: "Urine Ketones",
                description: "Presence of ketones. Trace amounts may be from fasting, exercise, or low-carb diet.",
                unit: "",
                referenceRange: "Negative",
                value: $urineKetones
            )
            
            TestField(
                title: "Urine Blood",
                description: "Presence of blood in urine. Negative is normal. Positive may indicate infection or kidney problems.",
                unit: "",
                referenceRange: "Negative",
                value: $urineBlood
            )
            
            TestField(
                title: "Urine Bilirubin",
                description: "Presence of bilirubin. Negative is normal. Positive may indicate liver or bile issues.",
                unit: "",
                referenceRange: "Negative",
                value: $urineBilirubin
            )
            
            TestField(
                title: "Urine Bacteria",
                description: "Presence of bacteria. Rare is acceptable. High levels may indicate UTI.",
                unit: "",
                referenceRange: "Rare",
                value: $urineBacteria
            )
            
            TestField(
                title: "Squamous Epithelial Cells",
                description: "Cells that line the urinary tract. Rare presence is normal.",
                unit: "",
                referenceRange: "Rare",
                value: $squamousCells
            )
            
            TestField(
                title: "Specific Gravity",
                description: "Measures urine concentration and hydration level.",
                unit: "",
                referenceRange: "1.005-1.030",
                value: $specificGravity
            )
        }
    }
}

// Helper view for displaying test results
struct ResultRow: View {
    let title: String
    let value: String
    let unit: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text("\(value) \(unit)")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
}

