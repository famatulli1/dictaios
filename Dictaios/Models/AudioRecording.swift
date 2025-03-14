import Foundation

struct AudioRecording: Identifiable, Equatable, Codable {
    let id: UUID
    let fileURL: URL
    let createdAt: Date
    var duration: TimeInterval
    var isPlaying: Bool = false
    var transcription: String?
    
    init(id: UUID = UUID(), fileURL: URL, createdAt: Date = Date(), duration: TimeInterval = 0.0, isPlaying: Bool = false, transcription: String? = nil) {
        self.id = id
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.duration = duration
        self.isPlaying = isPlaying
        self.transcription = transcription
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        fileURL = try container.decode(URL.self, forKey: .fileURL)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        isPlaying = try container.decode(Bool.self, forKey: .isPlaying)
        transcription = try container.decodeIfPresent(String.self, forKey: .transcription)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case fileURL
        case createdAt
        case duration
        case isPlaying
        case transcription
    }
    
    var recordingID: String {
        id.uuidString
    }
    
    var fileName: String {
        fileURL.lastPathComponent
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    var formattedDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: duration) ?? "00:00"
    }
    
    static func == (lhs: AudioRecording, rhs: AudioRecording) -> Bool {
        lhs.id == rhs.id
    }
}
