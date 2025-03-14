import SwiftUI
import OSLog

struct TranscriptionsView: View {
    private let logger = Logger(subsystem: "com.dictaios", category: "TranscriptionsView")
    @ObservedObject var viewModel: RecorderViewModel
    @State private var editingTranscription: AudioRecording?
    @State private var editedText: String = ""
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showSearch = false
    @State private var selectedFolder: Folder?
    @State private var showFolderPicker = false
    
    private var transcribedRecordings: [AudioRecording] {
        let recordings = viewModel.folderViewModel.selectedFolderId != nil ? 
            viewModel.filteredRecordings : viewModel.recordings
        
        let filtered = recordings.filter { $0.transcription != nil }
            .filter {
                if searchText.isEmpty { return true }
                return $0.transcription?.localizedCaseInsensitiveContains(searchText) ?? false ||
                       $0.fileName.localizedCaseInsensitiveContains(searchText)
            }
            .sorted { $0.createdAt > $1.createdAt }
        
        return filtered
    }
    
    private var groupedRecordings: [(Date, [AudioRecording])] {
        let grouped = Dictionary(grouping: transcribedRecordings) { recording in
            Calendar.current.startOfDay(for: recording.createdAt)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    ProgressView("Chargement des transcriptions...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if transcribedRecordings.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 24) {
                            ForEach(groupedRecordings, id: \.0) { date, recordings in
                                Section {
                                    VStack(spacing: 16) {
                                        ForEach(recordings) { recording in
                                            TranscriptionCard(
                                                recording: recording,
                                                onEdit: {
                                                    editingTranscription = recording
                                                    editedText = recording.transcription ?? ""
                                                },
                                                onShare: {
                                                    if let transcription = recording.transcription {
                                                        let activityVC = UIActivityViewController(
                                                            activityItems: [transcription],
                                                            applicationActivities: nil
                                                        )
                                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                                           let window = windowScene.windows.first,
                                                           let rootVC = window.rootViewController {
                                                            activityVC.popoverPresentationController?.sourceView = rootVC.view
                                                            rootVC.present(activityVC, animated: true)
                                                        }
                                                    }
                                                }
                                            )
                                            .transition(.scale.combined(with: .opacity))
                                        }
                                    }
                                } header: {
                                    TranscriptionDateHeader(date: date)
                                }
                            }
                        }
                        .padding()
                        .animation(.spring(), value: transcribedRecordings)
                    }
                    .refreshable {
                        await refreshTranscriptions()
                    }
                }
            }
            .navigationTitle("Transcriptions (\(transcribedRecordings.count))")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: { showSearch.toggle() }) {
                        Image(systemName: "magnifyingglass")
                    }
                    
                    Button(action: { showFolderPicker = true }) {
                        Image(systemName: "folder")
                    }
                    
                    Button(action: {
                        Task {
                            await refreshTranscriptions()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer,
                prompt: "Rechercher dans les transcriptions"
            )
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
            .sheet(isPresented: $showFolderPicker) {
                FoldersSheet(viewModel: viewModel)
            }
            .onChange(of: viewModel.folderViewModel.selectedFolderId) { _ in
                Task {
                    await viewModel.updateFilteredRecordings()
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.fill")
                .font(.system(size: 70))
                .foregroundColor(.blue.opacity(0.8))
                .padding()
                .background(
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 120, height: 120)
                )
            
            Text("Aucune transcription")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Transcrivez vos enregistrements en cliquant sur l'icône de transcription dans la liste des enregistrements")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .fixedSize(horizontal: false, vertical: true)
            
            Button(action: {
                viewModel.folderViewModel.selectedFolderId = nil
            }) {
                Label("Voir tous les enregistrements", systemImage: "arrow.right")
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .padding(.top)
        }
        .padding()
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
