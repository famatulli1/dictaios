import Foundation

actor TranscriptionManager {
    static let shared = TranscriptionManager()
    
    private let transcriptionsURL: URL
    private var transcriptions: [String: String] = [:] // [recordingID: transcription]
    
    private init() {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        transcriptionsURL = documentsDirectory.appendingPathComponent("transcriptions.json")
        loadTranscriptions()
    }
    
    private func loadTranscriptions() {
        do {
            let data = try Data(contentsOf: transcriptionsURL)
            transcriptions = try JSONDecoder().decode([String: String].self, from: data)
        } catch {
            print("Failed to load transcriptions: \(error)")
            transcriptions = [:]
        }
    }
    
    private func saveTranscriptions() {
        do {
            let data = try JSONEncoder().encode(transcriptions)
            try data.write(to: transcriptionsURL)
        } catch {
            print("Failed to save transcriptions: \(error)")
        }
    }
    
    func getTranscription(for recordingID: String) -> String? {
        transcriptions[recordingID]
    }
    
    func setTranscription(_ transcription: String, for recordingID: String) async throws {
        transcriptions[recordingID] = transcription
        // Save the transcription
        let data = try JSONEncoder().encode(transcriptions)
        try await Task {
            try data.write(to: transcriptionsURL)
        }.value
    }
    
    func deleteTranscription(for recordingID: String) async {
        transcriptions.removeValue(forKey: recordingID)
        // Save the transcription
        do {
            let data = try JSONEncoder().encode(transcriptions)
            try await Task {
                try data.write(to: transcriptionsURL)
            }.value
        } catch {
            print("Failed to delete transcription: \(error)")
        }
    }
}
