import SwiftUI

extension View {
    func confirmsRemoval(
        _ title: String, message: String, action: String, isPresented: Binding<Bool>, perform: @escaping () -> Void
    ) -> some View {
        confirmationDialog(title, isPresented: isPresented) {
            Button(action, role: .destructive, action: perform)
            Button(L.cancel, role: .cancel) {}
        } message: {
            Text(message)
        }
    }
}
