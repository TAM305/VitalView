import SwiftUI
import CoreData

struct AddTestSheetView: View {
    @Binding var isPresented: Bool
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: BloodTestViewModel
    
    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
        let context = PersistenceController.shared.container.viewContext
        self._viewModel = StateObject(wrappedValue: BloodTestViewModel(context: context))
    }
    
    var body: some View {
        AddTestView(context: context)
            .onDisappear {
                isPresented = false
            }
    }
}
