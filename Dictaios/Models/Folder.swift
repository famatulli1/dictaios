import Foundation

struct Folder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let createdAt: Date
    var recordingIds: [UUID]
    
    init(id: UUID = UUID(), name: String, createdAt: Date = Date(), recordingIds: [UUID] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.recordingIds = recordingIds
    }
    
    // Add a recording to the folder
    mutating func addRecording(_ recordingId: UUID) {
        if !recordingIds.contains(recordingId) {
            recordingIds.append(recordingId)
        }
    }
    
    // Remove a recording from the folder
    mutating func removeRecording(_ recordingId: UUID) {
        recordingIds.removeAll { $0 == recordingId }
    }
    
    // Check if the folder contains a recording
    func contains(_ recordingId: UUID) -> Bool {
        recordingIds.contains(recordingId)
    }
    
    static func == (lhs: Folder, rhs: Folder) -> Bool {
        lhs.id == rhs.id
    }
}

// Default folder types
enum DefaultFolderType: String, CaseIterable {
    case personal = "Personnel"
    case work = "Travail"
    case drafts = "Brouillons"
    
    var name: String {
        self.rawValue
    }
}
