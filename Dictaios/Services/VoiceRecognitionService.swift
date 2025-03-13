import Foundation
import SwiftUI

public enum VoiceRecognitionError: Error, LocalizedError {
    case invalidAPIKey
    case invalidAPIKeyFormat
    case networkError(Error)
    case transcriptionFailed(String)
    case fileError(String)
    case serverTimeout
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "Clé API OpenAI manquante dans les paramètres"
        case .invalidAPIKeyFormat:
            return "Format de clé API invalide. La clé doit commencer par 'sk-'"
        case .networkError(let error):
            return "Erreur réseau: \(error.localizedDescription)"
        case .transcriptionFailed(let message):
            return "Échec de la transcription: \(message)"
        case .fileError(let message):
            return "Erreur de fichier: \(message)"
        case .serverTimeout:
            return "Le serveur a mis trop de temps à répondre. Veuillez réessayer."
        case .unknownError:
            return "Une erreur inconnue s'est produite"
        }
    }
}

public actor VoiceRecognitionService {
    public static let shared = VoiceRecognitionService()
    
    public init() {}
    
    private func transcribeAudioOnce(url: URL) async throws -> String {
        guard AppSettings.shared.isAPIKeyValid else {
            throw VoiceRecognitionError.invalidAPIKeyFormat
        }
        
        guard !AppSettings.shared.openAIKey.isEmpty else {
            throw VoiceRecognitionError.invalidAPIKey
        }
        
        let apiKey = AppSettings.shared.openAIKey
        let whisperEndpoint = "https://api.openai.com/v1/audio/transcriptions"
        
        let fileData: Data
        do {
            fileData = try Data(contentsOf: url)
        } catch {
            throw VoiceRecognitionError.fileError("Impossible de lire le fichier audio")
        }
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: URL(string: whisperEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30 // Augmente le timeout à 30 secondes
        
        var body = Data()
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VoiceRecognitionError.transcriptionFailed("Invalid response")
            }
            
            if httpResponse.statusCode == 408 || httpResponse.statusCode == 504 {
                throw VoiceRecognitionError.serverTimeout
            }
            
            guard httpResponse.statusCode == 200 else {
                let decoder = JSONDecoder()
                
                // Try to decode OpenAI error format
                struct OpenAIError: Codable {
                    let error: ErrorDetail
                    
                    struct ErrorDetail: Codable {
                        let message: String
                        let type: String?
                        let code: String?
                    }
                }
                
                if let openAIError = try? decoder.decode(OpenAIError.self, from: data) {
                    throw VoiceRecognitionError.transcriptionFailed("OpenAI: \(openAIError.error.message)")
                }
                
                // Fallback to raw error message
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                throw VoiceRecognitionError.transcriptionFailed("Erreur du serveur (\(httpResponse.statusCode)): \(errorMessage)")
            }
            
            struct WhisperResponse: Codable {
                let text: String
            }
            
            let decoder = JSONDecoder()
            let whisperResponse = try decoder.decode(WhisperResponse.self, from: data)
            
            return whisperResponse.text
        } catch {
            if let error = error as? URLError, error.code == .timedOut {
                throw VoiceRecognitionError.serverTimeout
            } else {
                throw VoiceRecognitionError.networkError(error)
            }
        }
    }

    public func transcribeAudio(url: URL, retryCount: Int = 3) async throws -> String {
        var lastError: Error? = nil
        let retryDelay: UInt64 = 2_000_000_000 // 2 secondes
        
        for attempt in 1...retryCount {
            do {
                return try await transcribeAudioOnce(url: url)
            } catch let error as VoiceRecognitionError {
                switch error {
                case .invalidAPIKey, .invalidAPIKeyFormat, .fileError:
                    throw error // Ne réessaie pas ces erreurs
                case .networkError, .transcriptionFailed, .serverTimeout, .unknownError:
                    lastError = error
                    if attempt < retryCount {
                        try await Task.sleep(nanoseconds: retryDelay)
                        continue
                    }
                }
            } catch {
                lastError = error
            }
        }
        
        if let error = lastError {
            throw error
        } else {
            throw VoiceRecognitionError.transcriptionFailed("Échec après \(retryCount) tentatives")
        }
    }
}
