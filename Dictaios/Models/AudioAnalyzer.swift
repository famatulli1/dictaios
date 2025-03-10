import Foundation
import AVFoundation

class AudioAnalyzer {
    // Singleton instance
    static let shared = AudioAnalyzer()
    
    // Cache for storing samples
    private var samplesCache: [URL: [Float]] = [:]
    
    private init() {}
    
    // Extract audio samples from a file
    func extractSamples(from url: URL, samplesCount: Int = 100) async throws -> [Float] {
        // Check if samples are already cached
        if let cachedSamples = getCachedSamples(for: url) {
            return cachedSamples
        }
        
        // Create asset from URL
        let asset = AVAsset(url: url)
        
        // Get the first audio track
        guard let audioTrack = try? await asset.loadTracks(withMediaType: .audio).first else {
            throw NSError(domain: "AudioAnalyzer", code: 1, userInfo: [NSLocalizedDescriptionKey: "No audio track found"])
        }
        
        // Create asset reader
        guard let assetReader = try? AVAssetReader(asset: asset) else {
            throw NSError(domain: "AudioAnalyzer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create asset reader"])
        }
        
        // Configure the output settings
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        
        // Create a track output
        let trackOutput = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: outputSettings)
        assetReader.add(trackOutput)
        
        // Start reading
        assetReader.startReading()
        
        // Read all samples
        var sampleBuffer = [Float]()
        
        // Read all samples from the track
        while let sampleData = trackOutput.copyNextSampleBuffer(),
              let blockBuffer = CMSampleBufferGetDataBuffer(sampleData) {
            
            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            
            // Get a pointer to the data
            CMBlockBufferGetDataPointer(blockBuffer, atOffset: 0, lengthAtOffsetOut: &length, totalLengthOut: nil, dataPointerOut: &dataPointer)
            
            // Make sure dataPointer is not nil
            guard let unwrappedDataPointer = dataPointer else {
                continue // Skip this buffer if dataPointer is nil
            }
            
            // Convert to 16-bit samples
            let samples = UnsafeMutablePointer<Int16>(OpaquePointer(unwrappedDataPointer))
            let sampleCount = length / 2
            
            // Process samples (take absolute values for waveform)
            for i in 0..<sampleCount {
                let sample = Float(abs(Int(samples[i]))) / Float(Int16.max)
                sampleBuffer.append(sample)
            }
            
            // Release the sample buffer
            CMSampleBufferInvalidate(sampleData)
        }
        
        // Check if reading completed successfully
        if assetReader.status != .completed {
            throw NSError(domain: "AudioAnalyzer", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to read audio samples"])
        }
        
        // Downsample to the requested number of samples
        let downsampled = downsamplePeaks(from: sampleBuffer, to: samplesCount)
        
        // Normalize the samples
        let normalized = normalizeSamples(downsampled)
        
        // Cache the results
        cacheSamples(normalized, for: url)
        
        return normalized
    }
    
    // Downsample by taking the maximum value in each segment
    private func downsamplePeaks(from samples: [Float], to targetCount: Int) -> [Float] {
        guard samples.count > 0 else { return [] }
        
        if samples.count <= targetCount {
            return samples
        }
        
        var result = [Float]()
        let samplesPerSegment = samples.count / targetCount
        
        for i in 0..<targetCount {
            let startIndex = i * samplesPerSegment
            let endIndex = min(startIndex + samplesPerSegment, samples.count)
            
            if startIndex < endIndex {
                let segmentMax = samples[startIndex..<endIndex].max() ?? 0
                result.append(segmentMax)
            } else {
                result.append(0)
            }
        }
        
        return result
    }
    
    // Normalize samples to have values between 0 and 1
    private func normalizeSamples(_ samples: [Float]) -> [Float] {
        guard let max = samples.max(), max > 0 else {
            return samples
        }
        
        return samples.map { $0 / max }
    }
    
    // Cache samples for a URL
    func cacheSamples(_ samples: [Float], for url: URL) {
        samplesCache[url] = samples
    }
    
    // Get cached samples for a URL
    func getCachedSamples(for url: URL) -> [Float]? {
        return samplesCache[url]
    }
    
    // Clear cache for a specific URL
    func clearCache(for url: URL) {
        samplesCache.removeValue(forKey: url)
    }
    
    // Clear all cache
    func clearAllCache() {
        samplesCache.removeAll()
    }
}
