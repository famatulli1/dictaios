import Foundation
import AVFoundation
import OSLog
import CryptoKit

// String extension to handle subscripting
extension String {
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
    
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
}

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
    
    private let logger = Logger(subsystem: "com.dictaios", category: "AudioFileManager")
    
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
                
                // Generate a consistent UUID based on the file name
                let fileName = url.lastPathComponent
                let uuidString = fileName.replacingOccurrences(of: "recording_", with: "")
                    .replacingOccurrences(of: ".m4a", with: "")
                let id = UUID(uuidString: generateConsistentUUID(from: fileName)) ?? UUID()
                
                let recording = AudioRecording(
                    id: id,
                    fileURL: url,
                    createdAt: creationDate,
                    duration: duration
                )
                
                logger.debug("Created recording: \(recording.recordingID) for file: \(fileName)")
                return recording
            }
            .sorted(by: { $0.createdAt > $1.createdAt }) // Sort by date, newest first
            
        } catch {
            logger.error("Error getting recordings: \(error.localizedDescription)")
            return []
        }
    }
    
    // Generate a consistent UUID based on file name
    private func generateConsistentUUID(from fileName: String) -> String {
        // Create a deterministic UUID based on the file name using SHA256
        let hash = SHA256.hash(data: fileName.data(using: .utf8)!)
        let hashString = hash.compactMap { String(format: "%02x", $0) }.joined()
        
        // Convert the first 32 characters of the hash into a UUID format
        let uuid = String(format: "%@-%@-%@-%@-%@",
            hashString[0..<8],
            hashString[8..<12],
            hashString[12..<16],
            hashString[16..<20],
            hashString[20..<32]
        )
        
        logger.debug("Generated UUID \(uuid) for file: \(fileName)")
        return uuid
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
