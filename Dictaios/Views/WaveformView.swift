import SwiftUI

struct WaveformView: View {
    let samples: [Float]
    let progress: Double
    let playingColor: Color
    let notPlayingColor: Color
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                // Calculate the width of each bar and spacing
                let barCount = samples.count
                let barWidth = max(1, size.width / CGFloat(barCount) * 0.8)
                let spacing = max(0, (size.width - (CGFloat(barCount) * barWidth)) / CGFloat(barCount))
                
                // Calculate the progress position
                let progressPosition = size.width * CGFloat(progress)
                
                // Draw each sample as a vertical bar
                for (index, sample) in samples.enumerated() {
                    let barHeight = CGFloat(sample) * size.height
                    let xPosition = CGFloat(index) * (barWidth + spacing)
                    
                    // Create a rectangle for the bar
                    let barRect = CGRect(
                        x: xPosition,
                        y: (size.height - barHeight) / 2,
                        width: barWidth,
                        height: max(1, barHeight)
                    )
                    
                    // Determine the color based on progress
                    let color = xPosition <= progressPosition ? playingColor : notPlayingColor
                    
                    // Create a path for the bar
                    let barPath = Path(roundedRect: barRect, cornerRadius: barWidth / 2)
                    
                    // Fill the path with the appropriate color
                    context.fill(barPath, with: .color(color))
                }
            }
        }
    }
}

struct WaveformLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 4) {
                ForEach(0..<10, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 3, height: 20 + CGFloat.random(in: 0...10))
                        .scaleEffect(y: isAnimating ? 0.4 + CGFloat.random(in: 0...0.6) : 0.4, anchor: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1).repeatForever()) {
                    isAnimating = true
                }
            }
        }
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Example with random samples
            WaveformView(
                samples: (0..<50).map { _ in Float.random(in: 0.1...1.0) },
                progress: 0.3,
                playingColor: .blue,
                notPlayingColor: Color.gray.opacity(0.5)
            )
            .frame(height: 40)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            
            // Example with loading state
            WaveformLoadingView()
                .frame(height: 40)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
