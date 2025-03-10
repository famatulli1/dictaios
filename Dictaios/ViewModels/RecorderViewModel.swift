import Foundation
import AVFoundation
import SwiftUI
import Combine

enum RecordingState {
    case idle
    case recording
    case playing
}

class RecorderViewModel: NSObject, ObservableObject {
    
    // Published properties
    @Published var recordings: [AudioRecording] = []
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecordingTime: TimeInterval = 0
    @Published var selectedRecording: AudioRecording?
    @Published var playbackProgress: Double = 0
    @Published var errorMessage: String?
    
    // Audio components
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var recordingStartTime: Date?
    private var progressTimer: Timer?
    
    // File manager
    private let fileManager = AudioFileManager.shared
    
    override init() {
        super.init()
        loadRecordings()
        setupAudioSession()
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            errorMessage = "Failed to set up audio session: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Recording Functions
    
    func startRecording() {
        // Request microphone permission if needed
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            DispatchQueue.main.async {
                if allowed {
                    self?.initiateRecording()
                } else {
                    self?.errorMessage = "Microphone access is required to record audio."
                }
            }
        }
    }
    
    private func initiateRecording() {
        // Stop any ongoing playback
        stopPlayback()
        
        // Generate a new recording URL
        recordingURL = fileManager.generateRecordingURL()
        guard let url = recordingURL else { return }
        
        // Set up the audio recorder
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 2,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            
            // Update state
            recordingState = .recording
            recordingStartTime = Date()
            
            // Start timer to update recording time
            startRecordingTimer()
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        // Stop recording
        recorder.stop()
        audioRecorder = nil
        
        // Stop timer
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Update state
        recordingState = .idle
        
        // Add the new recording to the list
        loadRecordings()
    }
    
    private func startRecordingTimer() {
        progressTimer?.invalidate()
        currentRecordingTime = 0
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let startTime = self.recordingStartTime else { return }
            self.currentRecordingTime = Date().timeIntervalSince(startTime)
        }
    }
    
    // MARK: - Playback Functions
    
    func playRecording(_ recording: AudioRecording) {
        // Stop any ongoing recording or playback
        stopRecording()
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            // Update state
            recordingState = .playing
            selectedRecording = recording
            
            // Update the isPlaying flag for the selected recording
            updatePlayingStatus(for: recording.id, isPlaying: true)
            
            // Start timer to update playback progress
            startPlaybackTimer()
        } catch {
            errorMessage = "Failed to play recording: \(error.localizedDescription)"
        }
    }
    
    func stopPlayback() {
        guard let player = audioPlayer, player.isPlaying else { return }
        
        // Stop playback
        player.stop()
        audioPlayer = nil
        
        // Stop timer
        progressTimer?.invalidate()
        progressTimer = nil
        
        // Update state
        recordingState = .idle
        playbackProgress = 0
        
        // Update the isPlaying flag for the selected recording
        if let recording = selectedRecording {
            updatePlayingStatus(for: recording.id, isPlaying: false)
        }
        
        selectedRecording = nil
    }
    
    private func startPlaybackTimer() {
        progressTimer?.invalidate()
        playbackProgress = 0
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer, player.duration > 0 else { return }
            self.playbackProgress = player.currentTime / player.duration
        }
    }
    
    private func updatePlayingStatus(for id: UUID, isPlaying: Bool) {
        if let index = recordings.firstIndex(where: { $0.id == id }) {
            recordings[index].isPlaying = isPlaying
        }
    }
    
    // MARK: - Recording Management
    
    func loadRecordings() {
        recordings = fileManager.getAllRecordings()
    }
    
    func deleteRecording(_ recording: AudioRecording) {
        // Stop playback if this recording is playing
        if selectedRecording?.id == recording.id {
            stopPlayback()
        }
        
        // Delete the file
        if fileManager.deleteRecording(at: recording.fileURL) {
            // Remove from the list
            if let index = recordings.firstIndex(where: { $0.id == recording.id }) {
                recordings.remove(at: index)
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecorderViewModel: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            errorMessage = "Recording failed to complete successfully."
        }
        
        // Update state
        recordingState = .idle
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

// MARK: - AVAudioPlayerDelegate

extension RecorderViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // Update state
        recordingState = .idle
        playbackProgress = 0
        
        // Update the isPlaying flag for the selected recording
        if let recording = selectedRecording {
            updatePlayingStatus(for: recording.id, isPlaying: false)
        }
        
        selectedRecording = nil
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
