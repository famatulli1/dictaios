import SwiftUI

struct MoveRecordingView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.folderViewModel.folders) { folder in
                    Button(action: {
                        guard let recording = viewModel.recordingToMove else { return }
                        
                        Task {
                            await viewModel.moveRecording(to: folder.id)
                            dismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: isDefaultFolder(folder) ? "folder.fill" : "folder")
                                .foregroundColor(isDefaultFolder(folder) ? .blue : .primary)
                            
                            Text(folder.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Déplacer vers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        viewModel.cancelMoveRecording()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func isDefaultFolder(_ folder: Folder) -> Bool {
        DefaultFolderType.allCases.map { $0.name }.contains(folder.name)
    }
}
