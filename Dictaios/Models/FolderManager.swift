import Foundation
import OSLog

enum FolderError: Error {
    case loadError(Error)
    case saveError(Error)
    case fileNotFound
    case folderNotFound
    case recordingNotFound
}

actor FolderManager {
    static let shared = FolderManager()
    private let logger = Logger(subsystem: "com.dictaios", category: "FolderManager")
    
    private let foldersURL: URL
    private var folders: [Folder] = []
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        foldersURL = documentsDirectory.appendingPathComponent("folders.json")
        do {
            try loadFolders()
            createDefaultFoldersIfNeeded()
            logger.info("FolderManager initialized successfully")
        } catch {
            logger.error("Failed to initialize FolderManager: \(error)")
        }
    }
    
    private func loadFolders() throws {
        logger.debug("Loading folders from: \(self.foldersURL)")
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if !fileManager.fileExists(atPath: self.foldersURL.path, isDirectory: &isDirectory) {
            logger.notice("Folders file not found, creating empty folders")
            self.folders = []
            try self.saveFolders()
            return
        }
        
        do {
            let data = try Data(contentsOf: self.foldersURL)
            self.folders = try JSONDecoder().decode([Folder].self, from: data)
            logger.notice("Successfully loaded \(self.folders.count) folders")
        } catch {
            logger.error("Failed to load folders: \(error)")
            // Initialize with empty array but don't throw
            self.folders = []
        }
    }
    
    private func saveFolders() throws {
        logger.debug("Saving folders to: \(self.foldersURL)")
        
        // Create intermediate directories if needed
        try FileManager.default.createDirectory(at: self.foldersURL.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self.folders)
            try data.write(to: self.foldersURL, options: .atomic)
            logger.notice("Successfully saved \(self.folders.count) folders")
        } catch {
            logger.error("Failed to save folders: \(error)")
            throw FolderError.saveError(error)
        }
    }
    
    private func createDefaultFoldersIfNeeded() {
        let defaultFolderTypes = DefaultFolderType.allCases
        let existingDefaultFolders = folders.filter { folder in
            defaultFolderTypes.map { $0.name }.contains(folder.name)
        }
        
        // Create missing default folders
        for folderType in defaultFolderTypes {
            if !existingDefaultFolders.contains(where: { $0.name == folderType.name }) {
                let newFolder = Folder(name: folderType.name)
                folders.append(newFolder)
                logger.notice("Created default folder: \(folderType.name)")
            }
        }
        
        // Save the folders if any were created
        if existingDefaultFolders.count != defaultFolderTypes.count {
            do {
                try saveFolders()
            } catch {
                logger.error("Failed to save default folders: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    func getAllFolders() -> [Folder] {
        return folders
    }
    
    func getFolder(with id: UUID) -> Folder? {
        return folders.first { $0.id == id }
    }
    
    func getFolder(named name: String) -> Folder? {
        return folders.first { $0.name == name }
    }
    
    func createFolder(name: String) throws -> Folder {
        // Check if a folder with this name already exists
        if folders.contains(where: { $0.name == name }) {
            let newName = "\(name) (\(Date().timeIntervalSince1970))"
            logger.warning("Folder with name \(name) already exists, creating with name \(newName)")
            return try createFolder(name: newName)
        }
        
        let newFolder = Folder(name: name)
        folders.append(newFolder)
        try saveFolders()
        logger.notice("Created new folder: \(name) with ID: \(newFolder.id)")
        return newFolder
    }
    
    func renameFolder(id: UUID, newName: String) throws {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw FolderError.folderNotFound
        }
        
        // Check if a folder with this name already exists
        if folders.contains(where: { $0.name == newName && $0.id != id }) {
            let uniqueName = "\(newName) (\(Date().timeIntervalSince1970))"
            logger.warning("Folder with name \(newName) already exists, renaming to \(uniqueName)")
            try renameFolder(id: id, newName: uniqueName)
            return
        }
        
        var folder = folders[index]
        folder.name = newName
        folders[index] = folder
        try saveFolders()
        logger.notice("Renamed folder ID: \(id) to: \(newName)")
    }
    
    func deleteFolder(id: UUID) throws {
        guard let index = folders.firstIndex(where: { $0.id == id }) else {
            throw FolderError.folderNotFound
        }
        
        // Don't allow deleting default folders
        let folder = folders[index]
        if DefaultFolderType.allCases.map({ $0.name }).contains(folder.name) {
            logger.error("Cannot delete default folder: \(folder.name)")
            throw FolderError.folderNotFound
        }
        
        folders.remove(at: index)
        try saveFolders()
        logger.notice("Deleted folder ID: \(id)")
    }
    
    func addRecording(_ recordingId: UUID, to folderId: UUID) throws {
        guard let index = folders.firstIndex(where: { $0.id == folderId }) else {
            throw FolderError.folderNotFound
        }
        
        // Remove from any other folders first
        for i in 0..<folders.count {
            if folders[i].contains(recordingId) && folders[i].id != folderId {
                var folder = folders[i]
                folder.removeRecording(recordingId)
                folders[i] = folder
            }
        }
        
        // Add to the target folder
        var folder = folders[index]
        folder.addRecording(recordingId)
        folders[index] = folder
        
        try saveFolders()
        logger.notice("Added recording ID: \(recordingId) to folder ID: \(folderId)")
    }
    
    func removeRecording(_ recordingId: UUID, from folderId: UUID) throws {
        guard let index = folders.firstIndex(where: { $0.id == folderId }) else {
            throw FolderError.folderNotFound
        }
        
        var folder = folders[index]
        folder.removeRecording(recordingId)
        folders[index] = folder
        
        try saveFolders()
        logger.notice("Removed recording ID: \(recordingId) from folder ID: \(folderId)")
    }
    
    func moveRecording(_ recordingId: UUID, from sourceFolderId: UUID, to targetFolderId: UUID) throws {
        // Remove from source folder
        try removeRecording(recordingId, from: sourceFolderId)
        
        // Add to target folder
        try addRecording(recordingId, to: targetFolderId)
        
        logger.notice("Moved recording ID: \(recordingId) from folder ID: \(sourceFolderId) to folder ID: \(targetFolderId)")
    }
    
    func getFolderContaining(_ recordingId: UUID) -> Folder? {
        return folders.first { $0.contains(recordingId) }
    }
    
    // When a recording is deleted, remove it from all folders
    func removeRecordingFromAllFolders(_ recordingId: UUID) throws {
        var foldersChanged = false
        
        for i in 0..<folders.count {
            if folders[i].contains(recordingId) {
                var folder = folders[i]
                folder.removeRecording(recordingId)
                folders[i] = folder
                foldersChanged = true
            }
        }
        
        if foldersChanged {
            try saveFolders()
            logger.notice("Removed recording ID: \(recordingId) from all folders")
        }
    }
    
    // Get all recordings in a folder
    func getRecordingIds(in folderId: UUID) throws -> [UUID] {
        guard let folder = folders.first(where: { $0.id == folderId }) else {
            throw FolderError.folderNotFound
        }
        
        return folder.recordingIds
    }
    
    // Get the default folder for new recordings (Drafts)
    func getDefaultFolder() -> Folder? {
        return folders.first { $0.name == DefaultFolderType.drafts.name }
    }
}
