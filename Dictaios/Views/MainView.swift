import SwiftUI

struct MainView: View {
    @StateObject private var viewModel = RecorderViewModel()
    @StateObject private var settings = AppSettings.shared
    
    var body: some View {
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
    }
}

struct RecordingsView: View {
    @ObservedObject var viewModel: RecorderViewModel
    @State private var showingSettings = false
    @State private var showingErrorAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                Color(.systemBackground)
                    .edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Recordings list
                    if viewModel.recordings.isEmpty {
                        emptyStateView
                    } else {
                        recordingsList
                    }
                    
                    Spacer()
                    
                    // Recording controls
                    recordingControls
                }
                .padding()
            }
            .navigationTitle("Dictaios")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingSettings = true
                    }) {
                        Image(systemName: "gear")
                    }
                    
                    Button(action: {
                        viewModel.loadRecordings()
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .alert(isPresented: $showingErrorAlert) {
                Alert(
                    title: Text("Error"),
                    message: Text(viewModel.errorMessage ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showingErrorAlert = newValue != nil
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
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
            
            Text("No Recordings Yet")
                .font(.title2)
                .fontWeight(.medium)
            
            Text("Tap the record button below to start recording your first note.")
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
                ForEach(viewModel.recordings) { recording in
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
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            Task {
                                await viewModel.deleteRecording(recording)
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.top)
        }
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
