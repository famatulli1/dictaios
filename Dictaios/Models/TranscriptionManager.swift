import Foundation
import OSLog

enum TranscriptionError: Error {
    case loadError(Error)
    case saveError(Error)
    case fileNotFound
}

actor TranscriptionManager {
    static let shared = TranscriptionManager()
    private let logger = Logger(subsystem: "com.dictaios", category: "TranscriptionManager")
    
    private let transcriptionsURL: URL
    private var transcriptions: [String: String] = [:] // [recordingID: transcription]
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        transcriptionsURL = documentsDirectory.appendingPathComponent("transcriptions.json")
        do {
            try loadTranscriptions()
            logger.info("TranscriptionManager initialized successfully")
        } catch {
            logger.error("Failed to initialize TranscriptionManager: \(error)")
        }
    }
    
    private func loadTranscriptions() throws {
        logger.debug("Loading transcriptions from: \(self.transcriptionsURL)")
        
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        if !fileManager.fileExists(atPath: self.transcriptionsURL.path, isDirectory: &isDirectory) {
            logger.notice("Transcriptions file not found, creating empty transcriptions")
            self.transcriptions = [:]
            try self.saveTranscriptions()
            return
        }
        
        do {
            let data = try Data(contentsOf: self.transcriptionsURL)
            self.transcriptions = try JSONDecoder().decode([String: String].self, from: data)
            logger.notice("Successfully loaded \(self.transcriptions.count) transcriptions: \(self.transcriptions)")
        } catch {
            logger.error("Failed to load transcriptions: \(error)")
            // Initialize with empty dictionary but don't throw
            self.transcriptions = [:]
        }
    }
    
    private func saveTranscriptions() throws {
        logger.debug("Saving transcriptions to: \(self.transcriptionsURL)")
        
        // Create intermediate directories if needed
        try FileManager.default.createDirectory(at: self.transcriptionsURL.deletingLastPathComponent(),
                                             withIntermediateDirectories: true)
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(self.transcriptions)
            try data.write(to: self.transcriptionsURL, options: .atomic)
            logger.notice("Successfully saved \(self.transcriptions.count) transcriptions: \(self.transcriptions)")
        } catch {
            logger.error("Failed to save transcriptions: \(error)")
            throw TranscriptionError.saveError(error)
        }
    }
    
    func getTranscription(for recordingID: String) -> String? {
        logger.debug("Getting transcription for recordingID: \(recordingID)")
        let transcription = self.transcriptions[recordingID]
        logger.debug("Found transcription: \(String(describing: transcription))")
        return transcription
    }
    
    func setTranscription(_ transcription: String, for recordingID: String) async throws {
        logger.notice("Setting transcription for recordingID: \(recordingID) - \(transcription)")
        self.transcriptions[recordingID] = transcription
        try await Task {
            try self.saveTranscriptions()
        }.value
        logger.notice("Successfully set and saved transcription for recordingID: \(recordingID)")
        logger.notice("Current transcriptions: \(self.transcriptions)")
    }
    
    func deleteTranscription(for recordingID: String) async throws {
        logger.debug("Deleting transcription for recordingID: \(recordingID)")
        self.transcriptions.removeValue(forKey: recordingID)
        try await Task {
            try self.saveTranscriptions()
        }.value
        logger.info("Successfully deleted transcription for recordingID: \(recordingID)")
    }
    
    func getTranscriptionCount() -> Int {
        return self.transcriptions.count
    }
}
