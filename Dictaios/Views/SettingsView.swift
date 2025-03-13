import SwiftUI

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Voice Recognition")) {
                    Toggle("Enable Voice Recognition", isOn: $settings.isVoiceRecognitionEnabled)
                    
                    if settings.isVoiceRecognitionEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            SecureField("OpenAI API Key", text: $settings.openAIKey)
                                .textContentType(.password)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            HStack {
                                Image(systemName: settings.isAPIKeyValid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                    .foregroundColor(settings.isAPIKeyValid ? .green : .red)
                                Text(settings.isAPIKeyValid ? "Clé API valide" : "Format de clé API invalide")
                                    .font(.caption)
                                    .foregroundColor(settings.isAPIKeyValid ? .green : .red)
                            }
                            
                            if !settings.isAPIKeyValid {
                                Text("La clé API doit commencer par 'sk-' et avoir au moins 20 caractères")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .headerProminence(.increased)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
