import Foundation
import AVFoundation

class AudioFileManager {
    
    static let shared = AudioFileManager()
    
    private init() {}
    
    // Get the document directory URL
    func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Generate a unique file URL for a new recording
    func generateRecordingURL() -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "recording_\(dateFormatter.string(from: Date())).m4a"
        return getDocumentsDirectory().appendingPathComponent(fileName)
    }
    
    // Get all saved recordings
    func getAllRecordings() -> [AudioRecording] {
        do {
            let directoryContents = try FileManager.default.contentsOfDirectory(
                at: getDocumentsDirectory(),
                includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey],
                options: .skipsHiddenFiles
            )
            
            // Filter for .m4a files
            let audioFiles = directoryContents.filter { $0.pathExtension == "m4a" }
            
            // Create AudioRecording objects
            return try audioFiles.map { url in
                let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
                let creationDate = attributes[.creationDate] as? Date ?? Date()
                
                // Get audio duration
                let audioAsset = AVURLAsset(url: url)
                let duration = TimeInterval(CMTimeGetSeconds(audioAsset.duration))
                
                return AudioRecording(
                    id: UUID(),
                    fileURL: url,
                    createdAt: creationDate,
                    duration: duration
                )
            }
            .sorted(by: { $0.createdAt > $1.createdAt }) // Sort by date, newest first
            
        } catch {
            print("Error getting recordings: \(error.localizedDescription)")
            return []
        }
    }
    
    // Delete a recording
    func deleteRecording(at url: URL) -> Bool {
        do {
            try FileManager.default.removeItem(at: url)
            return true
        } catch {
            print("Error deleting recording: \(error.localizedDescription)")
            return false
        }
    }
}
