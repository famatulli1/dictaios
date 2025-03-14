import SwiftUI

struct RenameRecordingView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Nom de l'enregistrement", text: $viewModel.renameRecordingName)
                        .focused($isFocused)
                }
            }
            .navigationTitle("Renommer l'enregistrement")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        viewModel.cancelRenamingRecording()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Renommer") {
                        Task {
                            await viewModel.renameRecording()
                            dismiss()
                        }
                    }
                    .disabled(viewModel.renameRecordingName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
