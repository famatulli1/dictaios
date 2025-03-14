import SwiftUI

struct PlayerView: View {
    let recording: AudioRecording
    let onPlay: (AudioRecording) -> Void
    let onStop: () -> Void
    
    @ObservedObject var viewModel: RecorderViewModel
    @State private var showTranscription = false
    
    var body: some View {
        VStack(spacing: 8) {
            // Waveform visualization
            if recording.isPlaying {
                VStack(spacing: 4) {
                    if let samples = viewModel.audioSamples[recording.fileURL] {
                        // Show waveform if samples are available
                        WaveformView(
                            samples: samples,
                            progress: viewModel.playbackProgress,
                            playingColor: .blue,
                            notPlayingColor: Color.gray.opacity(0.5)
                        )
                        .frame(height: 40)
                    } else if viewModel.isLoadingWaveform {
                        // Show loading animation while samples are being loaded
                        WaveformLoadingView()
                            .frame(height: 40)
                    } else {
                        // Fallback to simple progress bar if waveform can't be loaded
                        ProgressView(value: viewModel.playbackProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .tint(Color.blue)
                    }
                    
                    // Time indicators
                    HStack {
                        Text(formatTime(viewModel.playbackProgress * recording.duration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(recording.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
                .onAppear {
                    // Load waveform data when the player appears
                    Task {
                        await viewModel.loadWaveformData(for: recording)
                    }
                }
            }
            
            // Recording info and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble.fill")
                                .foregroundColor(.blue)
                                .opacity(recording.transcription != nil ? 1 : 0)
                            Text(recording.fileName)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)
                        }
                        
                        if let transcription = recording.transcription {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text("Transcription:")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        withAnimation {
                                            showTranscription.toggle()
                                        }
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: showTranscription ? "chevron.up" : "chevron.down")
                                            Text(showTranscription ? "Voir moins" : "Voir plus")
                                        }
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    }
                                }
                                
                                Text(transcription)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .padding(.vertical, 4)
                                    .lineLimit(showTranscription ? nil : 2)
                                    .onTapGesture {
                                        withAnimation {
                                            showTranscription.toggle()
                                        }
                                    }
                            }
                        } else if viewModel.isTranscribing(recording) {
                            HStack(spacing: 4) {
                                Text("Transcription en cours...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                            .padding(.vertical, 2)
                        }
                        
                        Text(recording.formattedDate)
                            .font(.caption)
                            .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Duration
                if !recording.isPlaying {
                    Text(recording.formattedDuration)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.trailing, 8)
                }
                
                HStack(spacing: 8) {
                    // Play/Stop button
                    Button(action: {
                        if recording.isPlaying {
                            onStop()
                        } else {
                            onPlay(recording)
                        }
                    }) {
                        Image(systemName: recording.isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(recording.isPlaying ? Color.red : Color.blue)
                            .clipShape(Circle())
                    }
                    
                    // Transcription button
                    if AppSettings.shared.isVoiceRecognitionEnabled {
                        if !AppSettings.shared.isAPIKeyValid {
                            Button(action: {}) {
                                Image(systemName: "text.bubble")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(Color.orange)
                                    .clipShape(Circle())
                            }
                            .disabled(true)
                            .help("Clé API OpenAI invalide ou manquante dans les paramètres")
                        } else {
                            Button(action: {
                                viewModel.transcribeRecording(at: recording.fileURL)
                            }) {
                                Image(systemName: viewModel.isTranscribing(recording) ? "ellipsis" : "text.bubble")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 30, height: 30)
                                    .background(viewModel.isTranscribing(recording) ? Color.gray : Color.green)
                                    .clipShape(Circle())
                                    .overlay {
                                        if viewModel.isTranscribing(recording) {
                                            ProgressView()
                                                .scaleEffect(0.5)
                                                .tint(.white)
                                        }
                                    }
                            }
                            .disabled(viewModel.isTranscribing(recording) || recording.transcription != nil)
                            .help(recording.transcription != nil ? "Déjà transcrit" : "Transcrire l'enregistrement")
                        }
                    }
                    
                    // Rename button
                    Button(action: {
                        viewModel.startRenamingRecording(recording)
                    }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.orange)
                            .clipShape(Circle())
                    }
                    .help("Renommer l'enregistrement")
                    
                    // Move to folder button
                    Button(action: {
                        viewModel.showMoveRecordingOptions(recording)
                    }) {
                        Image(systemName: "folder")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(Color.purple)
                            .clipShape(Circle())
                    }
                    .help("Déplacer vers un dossier")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: timeInterval) ?? "00:00"
    }
}

struct PlayerView_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = RecorderViewModel()
        let recording = AudioRecording(
            id: UUID(),
            fileURL: URL(string: "file://recording.m4a")!,
            createdAt: Date(),
            duration: 125,
            isPlaying: false
        )
        
        let playingRecording = AudioRecording(
            id: UUID(),
            fileURL: URL(string: "file://recording2.m4a")!,
            createdAt: Date().addingTimeInterval(-3600),
            duration: 65,
            isPlaying: true
        )
        
        VStack(spacing: 20) {
            PlayerView(
                recording: recording,
                onPlay: { _ in },
                onStop: { },
                viewModel: viewModel
            )
            
            PlayerView(
                recording: playingRecording,
                onPlay: { _ in },
                onStop: { },
                viewModel: viewModel
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
