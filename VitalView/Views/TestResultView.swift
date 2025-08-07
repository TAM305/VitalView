import SwiftUI
import Charts

struct TestResultView: View {
    let test: BloodTest
    @State private var selectedResult: TestResult?
    @State private var isEditing = false
    @State private var showingDeleteAlert = false
    @State private var showingTestInfo = false
    @ObservedObject var viewModel: BloodTestViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        List {
            Section {
                Button(action: { showingTestInfo = true }) {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("View Test Information")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Section {
                ForEach(test.results) { result in
                    ResultRowView(result: result, viewModel: viewModel)
                        .onTapGesture {
                            selectedResult = result
                        }
                }
            } header: {
                Text("Results")
            }
            
            if let selectedResult = selectedResult {
                Section {
                    ExplanationView(result: selectedResult)
                } header: {
                    Text("Explanation")
                }
            }
            
            Section {
                Chart(test.results) { result in
                    if !result.value.isNaN && !result.value.isInfinite {
                        BarMark(
                            x: .value("Value", result.value),
                            y: .value("Test", result.name)
                        )
                        .foregroundStyle(viewModel.getResultColor(result))
                    }
                }
                .frame(height: 200)
            } header: {
                Text("Visualization")
            }
        }
        .navigationTitle(test.testType)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { isEditing = true }) {
                        Label("Edit Test", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete Test", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            NavigationView {
                EditTestView(test: test, viewModel: viewModel)
            }
        }
        .sheet(isPresented: $showingTestInfo) {
            NavigationView {
                TestInfoView(testType: test.testType)
            }
        }
        .alert("Delete Test", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteTest(test)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this test? This action cannot be undone.")
        }
    }
}

struct EditTestView: View {
    let test: BloodTest
    @ObservedObject var viewModel: BloodTestViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editedResults: [TestResult]
    @State private var testDate: Date
    
    init(test: BloodTest, viewModel: BloodTestViewModel) {
        self.test = test
        self.viewModel = viewModel
        _editedResults = State(initialValue: test.results)
        _testDate = State(initialValue: test.date)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Test Information")) {
                DatePicker("Test Date", selection: $testDate, displayedComponents: .date)
            }
            
            Section(header: Text("Results")) {
                ForEach($editedResults) { $result in
                    HStack {
                        Text(result.name)
                        Spacer()
                        TextField("Value", value: $result.value, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text(result.unit)
                    }
                }
            }
        }
        .navigationTitle("Edit Test")
        .navigationBarItems(
            leading: Button("Cancel") {
                dismiss()
            },
            trailing: Button("Save") {
                let updatedTest = BloodTest(
                    id: test.id,
                    date: testDate,
                    testType: test.testType,
                    results: editedResults
                )
                viewModel.updateTest(updatedTest)
                dismiss()
            }
        )
    }
}

struct ResultRowView: View {
    let result: TestResult
    @ObservedObject var viewModel: BloodTestViewModel
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(result.name)
                    .font(.headline)
                Text("\(result.value, specifier: "%.1f") \(result.unit)")
                    .font(.subheadline)
            }
            
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(result.referenceRange)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(result.status.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(viewModel.getResultColor(result))
            }
        }
        .padding(.vertical, 4)
    }
} 
