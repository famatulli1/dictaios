import SwiftUI

struct FolderSidebarView: View {
    @ObservedObject var folderViewModel: FolderViewModel
    @ObservedObject var recorderViewModel: RecorderViewModel
    
    @State private var draggedRecording: AudioRecording?
    @State private var isHoveringFolder: UUID?
    
    var body: some View {
        VStack(spacing: 0) {
            // Folders list
            List {
                ForEach(folderViewModel.folders) { folder in
                    FolderRow(
                        folder: folder,
                        isSelected: folderViewModel.selectedFolderId == folder.id,
                        onSelect: {
                            folderViewModel.selectedFolderId = folder.id
                        },
                        onRename: {
                            folderViewModel.startRenamingFolder(folder)
                        },
                        onDelete: {
                            folderViewModel.confirmDeleteFolder(folder)
                        },
                        isHovering: isHoveringFolder == folder.id
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        folderViewModel.selectedFolderId = folder.id
                    }
                    .onDrop(of: ["public.item"], isTargeted: Binding<Bool>(
                        get: { isHoveringFolder == folder.id },
                        set: { isHoveringFolder = $0 ? folder.id : nil }
                    )) { providers, _ in
                        guard let recording = draggedRecording else { return false }
                        
                        Task {
                            await folderViewModel.moveRecording(recording, to: folder.id)
                            await recorderViewModel.loadRecordings()
                        }
                        
                        return true
                    }
                }
            }
            .listStyle(SidebarListStyle())
            
            Divider()
            
            // Add folder button
            Button(action: {
                folderViewModel.isCreatingNewFolder = true
            }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("Nouveau dossier")
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .frame(width: 220)
        .sheet(isPresented: $folderViewModel.isCreatingNewFolder) {
            NewFolderView(folderViewModel: folderViewModel)
        }
        .sheet(isPresented: $folderViewModel.isRenamingFolder) {
            RenameFolderView(folderViewModel: folderViewModel)
        }
        .alert("Supprimer le dossier ?", isPresented: $folderViewModel.showDeleteFolderAlert) {
            Button("Annuler", role: .cancel) {
                folderViewModel.cancelFolderOperation()
            }
            Button("Supprimer", role: .destructive) {
                Task {
                    await folderViewModel.deleteFolder()
                }
            }
        } message: {
            if let folder = folderViewModel.folderToDelete {
                Text("Le contenu du dossier \"\(folder.name)\" sera déplacé vers le dossier Brouillons.")
            }
        }
    }
    
    // Method to set the dragged recording
    func setDraggedRecording(_ recording: AudioRecording) {
        self.draggedRecording = recording
    }
}

struct FolderRow: View {
    let folder: Folder
    let isSelected: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void
    let isHovering: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isDefaultFolder ? "folder.fill" : "folder")
                .foregroundColor(isDefaultFolder ? .blue : .primary)
            
            Text(folder.name)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(backgroundColor)
        )
        .contextMenu {
            if !isDefaultFolder {
                Button(action: onRename) {
                    Label("Renommer", systemImage: "pencil")
                }
                
                Button(role: .destructive, action: onDelete) {
                    Label("Supprimer", systemImage: "trash")
                }
            }
        }
    }
    
    private var isDefaultFolder: Bool {
        DefaultFolderType.allCases.map { $0.name }.contains(folder.name)
    }
    
    private var backgroundColor: Color {
        if isHovering {
            return Color.blue.opacity(0.2)
        } else if isSelected {
            return Color.blue.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

struct NewFolderView: View {
    @ObservedObject var folderViewModel: FolderViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Nom du dossier", text: $folderViewModel.newFolderName)
                        .focused($isFocused)
                }
            }
            .navigationTitle("Nouveau dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        folderViewModel.cancelFolderOperation()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        Task {
                            await folderViewModel.createFolder()
                            dismiss()
                        }
                    }
                    .disabled(folderViewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}

struct RenameFolderView: View {
    @ObservedObject var folderViewModel: FolderViewModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("Nom du dossier", text: $folderViewModel.renameFolderName)
                        .focused($isFocused)
                }
            }
            .navigationTitle("Renommer le dossier")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        folderViewModel.cancelFolderOperation()
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Renommer") {
                        Task {
                            await folderViewModel.renameFolder()
                            dismiss()
                        }
                    }
                    .disabled(folderViewModel.renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                isFocused = true
            }
        }
    }
}
