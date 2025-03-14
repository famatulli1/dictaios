import SwiftUI
import OSLog

struct TranscriptionRow: View {
    let recording: AudioRecording
    let onEdit: () -> Void
    @State private var showFullText = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text")
                    .foregroundColor(.blue)
                Text(recording.fileName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(recording.formattedDate)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.body)
                    .foregroundColor(.primary)
                    .lineLimit(showFullText ? nil : 3)
                    .onTapGesture {
                        withAnimation {
                            showFullText.toggle()
                        }
                    }
            }
            
            if showFullText {
                Button("Voir moins") {
                    withAnimation {
                        showFullText = false
                    }
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .contentShape(Rectangle())
        .cornerRadius(10)
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
    private let logger = Logger(subsystem: "com.dictaios", category: "TranscriptionsView")
    @ObservedObject var viewModel: RecorderViewModel
    @State private var editingTranscription: AudioRecording?
    @State private var editedText: String = ""
    @State private var isLoading = false
    
    private var transcribedRecordings: [AudioRecording] {
        // Filter by selected folder if one is selected
        let recordings = viewModel.folderViewModel.selectedFolderId != nil ? 
            viewModel.filteredRecordings : viewModel.recordings
        
        return recordings.filter { $0.transcription != nil }
            .sorted { $0.createdAt > $1.createdAt }
    }
    
    var body: some View {
        NavigationView {
            // Sidebar with folders
            FolderSidebarView(folderViewModel: viewModel.folderViewModel, recorderViewModel: viewModel)
                .environmentObject(viewModel)
            
            // Main content
            Group {
                if isLoading {
                    ProgressView("Chargement des transcriptions...")
                } else if transcribedRecordings.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 70))
                            .foregroundColor(.secondary)
                        Text("Aucune transcription")
                            .font(.title2)
                            .fontWeight(.medium)
                        Text("Transcrivez vos enregistrements en cliquant sur l'icône de transcription (bulle de texte) dans la liste des enregistrements")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(transcribedRecordings) { recording in
                                TranscriptionRow(recording: recording) {
                                    editingTranscription = recording
                                    editedText = recording.transcription ?? ""
                                }
                                .contextMenu {
                                    Button {
                                        viewModel.startRenamingRecording(recording)
                                    } label: {
                                        Label("Renommer", systemImage: "pencil")
                                    }
                                    
                                    Button {
                                        viewModel.showMoveRecordingOptions(recording)
                                    } label: {
                                        Label("Déplacer vers...", systemImage: "folder")
                                    }
                                    
                                    Button(role: .destructive) {
                                        Task {
                                            await viewModel.deleteRecording(recording)
                                            await refreshTranscriptions()
                                        }
                                    } label: {
                                        Label("Supprimer", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(viewModel.folderViewModel.selectedFolderId != nil ? 
                            "Transcriptions - \(viewModel.folderViewModel.folders.first(where: { $0.id == viewModel.folderViewModel.selectedFolderId })?.name ?? "Dossier") (\(transcribedRecordings.count))" : 
                            "Transcriptions (\(transcribedRecordings.count))")
            .sheet(item: $editingTranscription) { recording in
                TranscriptionEditor(text: $editedText) {
                    Task {
                        do {
                            try await TranscriptionManager.shared.setTranscription(editedText, for: recording.recordingID)
                            await MainActor.run {
                                viewModel.messageType = .success
                                viewModel.message = "Transcription modifiée"
                                Task {
                                    await refreshTranscriptions()
                                }
                            }
                        } catch {
                            logger.error("Failed to save transcription: \(error.localizedDescription)")
                            await MainActor.run {
                                viewModel.messageType = .error
                                viewModel.message = "Erreur lors de la sauvegarde: \(error.localizedDescription)"
                            }
                        }
                    }
                }
            }
            .toolbar {
                Button(action: {
                    Task {
                        await refreshTranscriptions()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
            .sheet(isPresented: $viewModel.isRenamingRecording) {
                RenameRecordingView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showMoveRecordingSheet) {
                MoveRecordingView(viewModel: viewModel)
            }
            .onAppear {
                Task {
                    await refreshTranscriptions()
                }
            }
            .onChange(of: viewModel.folderViewModel.selectedFolderId) { _ in
                Task {
                    await viewModel.updateFilteredRecordings()
                }
            }
        }
    
    private func refreshTranscriptions() async {
        isLoading = true
        defer { isLoading = false }
        
        await viewModel.loadRecordings()
        let count = await TranscriptionManager.shared.getTranscriptionCount()
        let storedTranscriptions = transcribedRecordings
        logger.notice("Found \(count) transcriptions in storage")
        logger.notice("Found \(storedTranscriptions.count) transcribed recordings")
        logger.notice("Total recordings: \(viewModel.recordings.count)")
        
        for recording in storedTranscriptions {
            logger.notice("Recording: \(recording.recordingID) - Has transcription: \(recording.transcription != nil)")
        }
    }
}

#Preview {
    TranscriptionsView(viewModel: RecorderViewModel())
}
