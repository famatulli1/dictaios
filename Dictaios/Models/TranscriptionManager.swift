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
        
        if !FileManager.default.fileExists(atPath: self.transcriptionsURL.path) {
            logger.notice("Transcriptions file not found, creating empty transcriptions")
            self.transcriptions = [:]
            try self.saveTranscriptions()
            return
        }
        
        do {
            let data = try Data(contentsOf: self.transcriptionsURL)
            self.transcriptions = try JSONDecoder().decode([String: String].self, from: data)
            logger.info("Successfully loaded \(self.transcriptions.count) transcriptions")
        } catch {
            logger.error("Failed to load transcriptions: \(error)")
            throw TranscriptionError.loadError(error)
        }
    }
    
    private func saveTranscriptions() throws {
        logger.debug("Saving transcriptions to: \(self.transcriptionsURL)")
        do {
            let data = try JSONEncoder().encode(self.transcriptions)
            try data.write(to: self.transcriptionsURL)
            logger.info("Successfully saved \(self.transcriptions.count) transcriptions")
        } catch {
            logger.error("Failed to save transcriptions: \(error)")
            throw TranscriptionError.saveError(error)
        }
    }
    
    func getTranscription(for recordingID: String) -> String? {
        logger.debug("Getting transcription for recordingID: \(recordingID)")
        return self.transcriptions[recordingID]
    }
    
    func setTranscription(_ transcription: String, for recordingID: String) async throws {
        logger.debug("Setting transcription for recordingID: \(recordingID)")
        self.transcriptions[recordingID] = transcription
        try await Task {
            try self.saveTranscriptions()
        }.value
        logger.info("Successfully set transcription for recordingID: \(recordingID)")
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
