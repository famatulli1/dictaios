import Foundation
import SwiftUI
import Combine
import OSLog

@MainActor
class FolderViewModel: ObservableObject {
    private let logger = Logger(subsystem: "com.dictaios", category: "FolderViewModel")
    
    // Published properties
    @Published var folders: [Folder] = []
    @Published var selectedFolderId: UUID?
    @Published var isCreatingNewFolder = false
    @Published var newFolderName = ""
    @Published var isRenamingFolder = false
    @Published var folderToRename: Folder?
    @Published var renameFolderName = ""
    @Published var showDeleteFolderAlert = false
    @Published var folderToDelete: Folder?
    @Published var messageType: RecorderViewModel.MessageType = .error
    @Published var message: String?
    
    // References
    private let folderManager = FolderManager.shared
    
    init() {
        Task {
            await loadFolders()
            
            // Select the default folder (Drafts) if no folder is selected
            if selectedFolderId == nil, let defaultFolder = await folderManager.getDefaultFolder() {
                selectedFolderId = defaultFolder.id
            }
        }
    }
    
    // MARK: - Folder Management
    
    func loadFolders() async {
        self.folders = await folderManager.getAllFolders().sorted { $0.name < $1.name }
        
        // Move default folders to the top
        let defaultFolderNames = DefaultFolderType.allCases.map { $0.name }
        let defaultFolders = self.folders.filter { defaultFolderNames.contains($0.name) }
            .sorted { defaultFolderNames.firstIndex(of: $0.name)! < defaultFolderNames.firstIndex(of: $1.name)! }
        
        let otherFolders = self.folders.filter { !defaultFolderNames.contains($0.name) }
            .sorted { $0.name < $1.name }
        
        self.folders = defaultFolders + otherFolders
        
        logger.notice("Loaded \(self.folders.count) folders")
    }
    
    func createFolder() async {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            messageType = .error
            message = "Le nom du dossier ne peut pas être vide"
            return
        }
        
        do {
            let folder = try await folderManager.createFolder(name: newFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
            await loadFolders()
            selectedFolderId = folder.id
            isCreatingNewFolder = false
            newFolderName = ""
            messageType = .success
            message = "Dossier créé"
        } catch {
            logger.error("Failed to create folder: \(error.localizedDescription)")
            messageType = .error
            message = "Erreur lors de la création du dossier: \(error.localizedDescription)"
        }
    }
    
    func renameFolder() async {
        guard let folder = folderToRename else { return }
        guard !renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            messageType = .error
            message = "Le nom du dossier ne peut pas être vide"
            return
        }
        
        do {
            try await folderManager.renameFolder(id: folder.id, newName: renameFolderName.trimmingCharacters(in: .whitespacesAndNewlines))
            await loadFolders()
            isRenamingFolder = false
            folderToRename = nil
            renameFolderName = ""
            messageType = .success
            message = "Dossier renommé"
        } catch {
            logger.error("Failed to rename folder: \(error.localizedDescription)")
            messageType = .error
            message = "Erreur lors du renommage du dossier: \(error.localizedDescription)"
        }
    }
    
    func deleteFolder() async {
        guard let folder = folderToDelete else { return }
        
        // Check if it's a default folder
        let defaultFolderNames = DefaultFolderType.allCases.map { $0.name }
        if defaultFolderNames.contains(folder.name) {
            messageType = .error
            message = "Impossible de supprimer un dossier par défaut"
            showDeleteFolderAlert = false
            folderToDelete = nil
            return
        }
        
        do {
            // Get the recordings in this folder
            let recordingIds = try await folderManager.getRecordingIds(in: folder.id)
            
            // If there are recordings, move them to the Drafts folder
            if !recordingIds.isEmpty {
                if let draftsFolder = await folderManager.getFolder(named: DefaultFolderType.drafts.name) {
                    for recordingId in recordingIds {
                        try await folderManager.addRecording(recordingId, to: draftsFolder.id)
                    }
                }
            }
            
            // Delete the folder
            try await folderManager.deleteFolder(id: folder.id)
            
            // If the deleted folder was selected, select the Drafts folder
            if selectedFolderId == folder.id {
                if let draftsFolder = await folderManager.getFolder(named: DefaultFolderType.drafts.name) {
                    selectedFolderId = draftsFolder.id
                }
            }
            
            await loadFolders()
            showDeleteFolderAlert = false
            folderToDelete = nil
            messageType = .success
            message = "Dossier supprimé"
        } catch {
            logger.error("Failed to delete folder: \(error.localizedDescription)")
            messageType = .error
            message = "Erreur lors de la suppression du dossier: \(error.localizedDescription)"
        }
    }
    
    func startRenamingFolder(_ folder: Folder) {
        // Check if it's a default folder
        let defaultFolderNames = DefaultFolderType.allCases.map { $0.name }
        if defaultFolderNames.contains(folder.name) {
            messageType = .error
            message = "Impossible de renommer un dossier par défaut"
            return
        }
        
        folderToRename = folder
        renameFolderName = folder.name
        isRenamingFolder = true
    }
    
    func confirmDeleteFolder(_ folder: Folder) {
        // Check if it's a default folder
        let defaultFolderNames = DefaultFolderType.allCases.map { $0.name }
        if defaultFolderNames.contains(folder.name) {
            messageType = .error
            message = "Impossible de supprimer un dossier par défaut"
            return
        }
        
        folderToDelete = folder
        showDeleteFolderAlert = true
    }
    
    func cancelFolderOperation() {
        isCreatingNewFolder = false
        newFolderName = ""
        isRenamingFolder = false
        folderToRename = nil
        renameFolderName = ""
        showDeleteFolderAlert = false
        folderToDelete = nil
    }
    
    // MARK: - Recording Management
    
    func getRecordingsInSelectedFolder(allRecordings: [AudioRecording]) async -> [AudioRecording] {
        guard let folderId = selectedFolderId else { return [] }
        
        do {
            let recordingIds = try await folderManager.getRecordingIds(in: folderId)
            return allRecordings.filter { recordingIds.contains($0.id) }
                .sorted { $0.createdAt > $1.createdAt } // Sort by date, newest first
        } catch {
            logger.error("Failed to get recordings in folder: \(error.localizedDescription)")
            return []
        }
    }
    
    func moveRecording(_ recording: AudioRecording, to folderId: UUID) async {
        do {
            // Find the current folder containing the recording
            if let currentFolder = await folderManager.getFolderContaining(recording.id) {
                // If it's already in the target folder, do nothing
                if currentFolder.id == folderId {
                    return
                }
                
                // Move the recording
                try await folderManager.moveRecording(recording.id, from: currentFolder.id, to: folderId)
            } else {
                // If it's not in any folder, add it to the target folder
                try await folderManager.addRecording(recording.id, to: folderId)
            }
            
            messageType = .success
            message = "Enregistrement déplacé"
        } catch {
            logger.error("Failed to move recording: \(error.localizedDescription)")
            messageType = .error
            message = "Erreur lors du déplacement de l'enregistrement: \(error.localizedDescription)"
        }
    }
    
    func addNewRecording(_ recording: AudioRecording) async {
        do {
            // Add to the default folder (Drafts) if no folder is selected
            if let draftsFolder = await folderManager.getFolder(named: DefaultFolderType.drafts.name) {
                try await folderManager.addRecording(recording.id, to: draftsFolder.id)
            }
        } catch {
            logger.error("Failed to add new recording to default folder: \(error.localizedDescription)")
        }
    }
    
    func removeRecordingFromAllFolders(_ recording: AudioRecording) async {
        do {
            try await folderManager.removeRecordingFromAllFolders(recording.id)
        } catch {
            logger.error("Failed to remove recording from all folders: \(error.localizedDescription)")
        }
    }
    
    func getFolderForRecording(_ recording: AudioRecording) async -> Folder? {
        return await folderManager.getFolderContaining(recording.id)
    }
}
