import SwiftUI

struct FoldersSheet: View {
    @ObservedObject var viewModel: RecorderViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(viewModel.folderViewModel.folders) { folder in
                    FolderSheetRow(folder: folder, viewModel: viewModel, dismiss: dismiss)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dossiers")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        viewModel.folderViewModel.isCreatingNewFolder = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $viewModel.folderViewModel.isCreatingNewFolder) {
                NewFolderView(folderViewModel: viewModel.folderViewModel)
            }
            .sheet(isPresented: $viewModel.folderViewModel.isRenamingFolder) {
                RenameFolderView(folderViewModel: viewModel.folderViewModel)
            }
            .alert("Supprimer le dossier ?", isPresented: $viewModel.folderViewModel.showDeleteFolderAlert) {
                Button("Annuler", role: .cancel) {
                    viewModel.folderViewModel.cancelFolderOperation()
                }
                Button("Supprimer", role: .destructive) {
                    Task {
                        await viewModel.folderViewModel.deleteFolder()
                    }
                }
            } message: {
                if let folder = viewModel.folderViewModel.folderToDelete {
                    Text("Le contenu du dossier \"\(folder.name)\" sera déplacé vers le dossier Brouillons.")
                }
            }
        }
    }
}

private struct FolderSheetRow: View {
    let folder: Folder
    @ObservedObject var viewModel: RecorderViewModel
    let dismiss: DismissAction
    
    var body: some View {
        HStack {
            Image(systemName: isDefaultFolder ? "folder.fill" : "folder")
                .foregroundColor(isDefaultFolder ? .blue : .primary)
            
            Text(folder.name)
                .lineLimit(1)
            
            Spacer()
            
            if viewModel.folderViewModel.selectedFolderId == folder.id {
                Image(systemName: "checkmark")
                    .foregroundColor(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            viewModel.folderViewModel.selectedFolderId = folder.id
            Task {
                await viewModel.updateFilteredRecordings()
            }
            dismiss()
        }
        .swipeActions(allowsFullSwipe: false) {
            if !isDefaultFolder {
                Button(role: .destructive) {
                    viewModel.folderViewModel.confirmDeleteFolder(folder)
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
                
                Button {
                    viewModel.folderViewModel.startRenamingFolder(folder)
                } label: {
                    Label("Renommer", systemImage: "pencil")
                }
                .tint(.orange)
            }
        }
    }
    
    private var isDefaultFolder: Bool {
        DefaultFolderType.allCases.map { $0.name }.contains(folder.name)
    }
}
