import SwiftUI

struct TranscriptionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    @FocusState private var isFocused: Bool
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Text editor
                ZStack(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("Tapez votre transcription ici...")
                            .foregroundColor(.gray)
                            .padding(.horizontal)
                            .padding(.top, 10)
                    }
                    
                    TextEditor(text: $text)
                        .focused($isFocused)
                        .background(Color(.systemBackground))
                        .padding(.horizontal)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .background(Color(.systemGroupedBackground))
                
                // Word count
                HStack {
                    Text("\(text.split(separator: " ").count) mots")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(text.count) caractères")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground))
            }
            .navigationTitle("Modifier la transcription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        onSave()
                        dismiss()
                    }
                    .font(.headline)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    
                    Button("Terminé") {
                        isFocused = false
                    }
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

struct TranscriptionEditor_Previews: PreviewProvider {
    static var previews: some View {
        TranscriptionEditor(text: .constant("Example text"), onSave: {})
    }
}
