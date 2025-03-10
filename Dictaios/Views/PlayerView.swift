import SwiftUI

struct PlayerView: View {
    let recording: AudioRecording
    let onPlay: (AudioRecording) -> Void
    let onStop: () -> Void
    
    @ObservedObject var viewModel: RecorderViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            // Playback progress bar
            if recording.isPlaying {
                VStack(spacing: 4) {
                    ProgressView(value: viewModel.playbackProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .tint(Color.blue)
                    
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
            }
            
            // Recording info and controls
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.fileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
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
