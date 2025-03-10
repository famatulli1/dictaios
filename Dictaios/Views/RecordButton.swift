import SwiftUI

struct RecordButton: View {
    enum ButtonState {
        case idle
        case recording
        case playing
    }
    
    var state: ButtonState
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 70, height: 70)
                    .shadow(radius: 4)
                
                if state == .recording {
                    // Square for stop recording
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                } else if state == .playing {
                    // Pause icon
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 6, height: 24)
                        
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white)
                            .frame(width: 6, height: 24)
                    }
                } else {
                    // Circle for record
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        switch state {
        case .idle:
            return Color.red
        case .recording:
            return Color.red.opacity(0.8)
        case .playing:
            return Color.blue
        }
    }
}

struct RecordButtonPulseAnimation: View {
    @State private var isAnimating = false
    let state: RecordButton.ButtonState
    
    var body: some View {
        ZStack {
            if state == .recording {
                // Pulsing animation for recording state
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(isAnimating ? 2 + CGFloat(i) * 0.3 : 1)
                        .opacity(isAnimating ? 0 : 1)
                }
                .animation(
                    Animation.easeInOut(duration: 1.5)
                        .repeatForever(autoreverses: false)
                        .delay(0.2),
                    value: isAnimating
                )
                .onAppear {
                    isAnimating = true
                }
            }
        }
    }
}

struct RecordButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            RecordButton(state: .idle, action: {})
            RecordButton(state: .recording, action: {})
            RecordButton(state: .playing, action: {})
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
