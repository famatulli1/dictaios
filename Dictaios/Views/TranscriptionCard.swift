import SwiftUI

struct TranscriptionCard: View {
    let recording: AudioRecording
    let onEdit: () -> Void
    let onShare: () -> Void
    @State private var showFullText = false
    @State private var offset = CGSize.zero
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(recording.fileName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(recording.formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Modifier", systemImage: "pencil")
                    }
                    
                    Button(action: onShare) {
                        Label("Partager", systemImage: "square.and.arrow.up")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Content
            if let transcription = recording.transcription {
                Text(transcription)
                    .font(.body)
                    .lineLimit(showFullText ? nil : 3)
                    .animation(.easeOut(duration: 0.2), value: showFullText)
            }
            
            // Footer
            HStack {
                Button(action: { withAnimation { showFullText.toggle() }}) {
                    Text(showFullText ? "Voir moins" : "Voir plus")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                    
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.body)
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        )
        .offset(x: offset.width, y: 0)
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    offset.width = gesture.translation.width
                }
                .onEnded { gesture in
                    withAnimation(.spring()) {
                        offset = .zero
                    }
                }
        )
        .animation(.spring(), value: offset)
    }
}

struct TranscriptionDateHeader: View {
    let date: Date
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    
    var body: some View {
        Text(formattedDate)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
    }
}
