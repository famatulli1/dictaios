import Foundation

struct AudioRecording: Identifiable, Equatable {
    let id: UUID
    let fileURL: URL
    let createdAt: Date
    var duration: TimeInterval
    var isPlaying: Bool = false
    
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
