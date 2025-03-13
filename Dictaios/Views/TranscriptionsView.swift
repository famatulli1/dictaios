import SwiftUI

struct TranscriptionRow: View {
    let recording: AudioRecording
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text(recording.fileName)
                    .font(.headline)
            }
            
            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(3)
            }
            
            Text(recording.formattedDate)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }
}

struct TranscriptionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSave: () -> Void
    
    var body: some View {
        NavigationView {
            TextEditor(text: $text)
                .padding()
                .navigationTitle("Modifier la transcription")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Enregistrer") {
                            onSave()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

struct TranscriptionsView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @State private var editingTranscription: AudioRecording?
    @State private var editedText: String = ""
    @State private var refreshTimer: Timer? = nil
    
    private var transcribedRecordings: [AudioRecording] {
        viewModel.recordings.filter { $0.transcription != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if transcribedRecordings.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 70))
                            .foregroundColor(.secondary)
                        Text("Aucune transcription")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Les transcriptions de vos enregistrements apparaîtront ici")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    List {
                        ForEach(transcribedRecordings) { recording in
                            TranscriptionRow(recording: recording) {
                                editingTranscription = recording
                                editedText = recording.transcription ?? ""
                            }
                        }
                    }
                }
            }
            .navigationTitle("Transcriptions")
            .sheet(item: $editingTranscription) { recording in
                TranscriptionEditor(text: $editedText) {
                    Task {
                        do {
                            try await TranscriptionManager.shared.setTranscription(editedText, for: recording.recordingID)
                            await MainActor.run {
                                viewModel.loadRecordings()
                            }
                        } catch {
                            print("Failed to save transcription: \(error)")
                            await MainActor.run {
                                viewModel.errorMessage = "Failed to save transcription: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
            .toolbar {
                Button(action: {
                    viewModel.loadRecordings()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .onAppear {
            // Initial load
            viewModel.loadRecordings()
            
            // Start periodic refresh
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
                viewModel.loadRecordings()
            }
        }
        .onDisappear {
            // Clean up timer
            refreshTimer?.invalidate()
            refreshTimer = nil
        }
    }
}

#Preview {
    TranscriptionsView(viewModel: RecorderViewModel())
}
