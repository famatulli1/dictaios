import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()
    
    @Published var isVoiceRecognitionEnabled: Bool {
        didSet {
            UserDefaults.standard.set(isVoiceRecognitionEnabled, forKey: "isVoiceRecognitionEnabled")
        }
    }
    
    @Published var openAIKey: String {
        didSet {
            UserDefaults.standard.set(openAIKey, forKey: "openAIKey")
            validateAPIKey()
        }
    }
    
    @Published var isAPIKeyValid: Bool = false
    
    private init() {
        self.isVoiceRecognitionEnabled = UserDefaults.standard.bool(forKey: "isVoiceRecognitionEnabled")
        self.openAIKey = UserDefaults.standard.string(forKey: "openAIKey") ?? ""
        validateAPIKey()
    }
    
    private func validateAPIKey() {
        isAPIKeyValid = !openAIKey.isEmpty && openAIKey.hasPrefix("sk-") && openAIKey.count >= 20
    }
}
