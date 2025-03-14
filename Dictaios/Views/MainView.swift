import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = RecorderViewModel()
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
        ZStack {
            TabView {
                RecordingsView(viewModel: viewModel)
                    .tabItem {
                        Label("Enregistrements", systemImage: "mic")
                    }
                
                TranscriptionsView(viewModel: viewModel)
                    .tabItem {
                        Label("Transcriptions", systemImage: "doc.text")
                    }
            }
            
            // Messages overlay
            VStack {
                if let message = viewModel.message {
                    HStack {
                        Image(systemName: viewModel.messageType == .success ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundColor(viewModel.messageType == .success ? .green : .red)
                        Text(message)
                            .foregroundColor(viewModel.messageType == .success ? .green : .red)
                    }
                    .padding()
                    .background(Color(.systemBackground).opacity(0.9))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding(.top, 44)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .animation(.easeInOut, value: viewModel.message != nil)
        }
    }
}

struct RecordingsView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @State private var showingSettings = false
    @State private var showingFolders = false
    @State private var showingErrorAlert = false
    @State private var draggedRecording: AudioRecording?
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Main recording button area
                Spacer()
                
                // Record button area
                VStack(spacing: 16) {
                    if viewModel.recordingState == .recording {
                        Text(formatRecordingTime(viewModel.currentRecordingTime))
                            .font(.system(size: 32, weight: .medium, design: .monospaced))
                            .foregroundColor(.red)
                            .transition(.opacity)
                    } else {
                        Text("Appuyez pour enregistrer")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    ZStack {
                        // Pulse animation
                        if viewModel.recordingState == .recording {
                            RecordButtonPulseAnimation(
                                state: .recording
                            )
                            .frame(width: 160, height: 160)
                        }
                        
                        // Record button
                        RecordButton(
                            state: buttonState,
                            action: {
                                switch viewModel.recordingState {
                                case .idle:
                                    viewModel.startRecording()
                                case .recording:
                                    viewModel.stopRecording()
                                case .playing:
                                    viewModel.stopPlayback()
                                }
                            }
                        )
                    }
                    .frame(height: 160)
                }
                .padding(.vertical, 30)
                .shadow(radius: 3)
                
                Spacer()
                
                // Recordings list
                VStack {
                    HStack {
                        Text(viewModel.folderViewModel.selectedFolderId != nil ? 
                             (viewModel.folderViewModel.folders.first(where: { $0.id == viewModel.folderViewModel.selectedFolderId })?.name ?? "Enregistrements") : 
                             "Enregistrements")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button(action: {
                            showingFolders = true
                        }) {
                            Image(systemName: "folder")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                    
                    if viewModel.filteredRecordings.isEmpty {
                        emptyStateView
                    } else {
                        recordingsList
                    }
                }
                .frame(maxHeight: UIScreen.main.bounds.height * 0.4)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedCorner(radius: 15, corners: [.topLeft, .topRight]))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5)
                        .frame(maxWidth: .infinity),
                    alignment: .top
                )
            }
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(.all, edges: .top)
            .sheet(isPresented: $showingFolders) {
                FoldersSheet(viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 15) {
                        Button(action: {
                            Task {
                                await viewModel.loadRecordings()
                                await viewModel.updateFilteredRecordings()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Button(action: {
                            showingSettings = true
                        }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .alert(isPresented: .constant(false)) {
                Alert(title: Text(""))
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $viewModel.isRenamingRecording) {
                RenameRecordingView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.showMoveRecordingSheet) {
                MoveRecordingView(viewModel: viewModel)
            }
            .task {
                await viewModel.loadRecordings()
                await viewModel.updateFilteredRecordings()
            }
            .onChange(of: viewModel.folderViewModel.selectedFolderId) { _ in
                Task {
                    await viewModel.updateFilteredRecordings()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "mic.slash")
                .font(.system(size: 70))
                .foregroundColor(.secondary)
            
            Text("Aucun enregistrement")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Appuyez sur le bouton d'enregistrement pour commencer.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var recordingsList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.filteredRecordings) { recording in
                    PlayerView(
                        recording: recording,
                        onPlay: { viewModel.playRecording($0) },
                        onStop: { viewModel.stopPlayback() },
                        viewModel: viewModel
                    )
                    .swipeActions {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteRecording(recording)
                            }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                        
                        Button {
                            viewModel.startRenamingRecording(recording)
                        } label: {
                            Label("Renommer", systemImage: "pencil")
                        }
                        .tint(.orange)
                        
                        Button {
                            viewModel.showMoveRecordingOptions(recording)
                        } label: {
                            Label("Déplacer", systemImage: "folder")
                        }
                        .tint(.blue)
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
                            }
                        } label: {
                            Label("Supprimer", systemImage: "trash")
                        }
                    }
                    .onDrag {
                        // Set the dragged recording for folder drop
                        self.draggedRecording = recording
                        if let sidebarView = findFolderSidebarView() {
                            sidebarView.setDraggedRecording(recording)
                        }
                        return NSItemProvider(object: recording.id.uuidString as NSString)
                    }
                }
            }
            .padding(.top)
        }
    }
    
    private func findFolderSidebarView() -> FolderSidebarView? {
        // This is a workaround to find the FolderSidebarView instance
        // In a real app, you might use a different approach like a coordinator pattern
        return nil
    }
    
    private var recordingControls: some View {
        VStack(spacing: 16) {
            // Recording time display
            if viewModel.recordingState == .recording {
                Text(formatRecordingTime(viewModel.currentRecordingTime))
                    .font(.system(size: 24, weight: .medium, design: .monospaced))
                    .foregroundColor(.red)
                    .transition(.opacity)
            }
            
            // Record button with pulse animation
            ZStack {
                // Pulse animation
                if viewModel.recordingState == .recording {
                    RecordButtonPulseAnimation(
                        state: .recording
                    )
                    .frame(width: 120, height: 120)
                }
                
                // Record button
                RecordButton(
                    state: buttonState,
                    action: {
                        switch viewModel.recordingState {
                        case .idle:
                            viewModel.startRecording()
                        case .recording:
                            viewModel.stopRecording()
                        case .playing:
                            viewModel.stopPlayback()
                        }
                    }
                )
            }
            .frame(height: 120)
            .padding(.bottom)
        }
    }
    
    // MARK: - Helper Methods
    
    private var buttonState: RecordButton.ButtonState {
        switch viewModel.recordingState {
        case .idle:
            return .idle
        case .recording:
            return .recording
        case .playing:
            return .playing
        }
    }
    
    private func formatRecordingTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: timeInterval) ?? "00:00"
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
