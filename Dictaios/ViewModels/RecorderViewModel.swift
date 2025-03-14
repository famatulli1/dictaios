import Foundation
import AVFoundation
import SwiftUI
import Combine
import OSLog

enum RecordingState {
    case idle
    case recording
    case playing
}

@MainActor
class RecorderViewModel: NSObject, ObservableObject {
    private let logger = Logger(subsystem: "com.dictaios", category: "RecorderViewModel")
    
    enum MessageType {
        case success
        case error
    }
    
    // Published properties
    @Published var recordings: [AudioRecording] = []
    @Published private(set) var isTranscribing = false
    @Published var recordingState: RecordingState = .idle
    @Published var currentRecordingTime: TimeInterval = 0
    @Published var selectedRecording: AudioRecording?
    @Published var playbackProgress: Double = 0
    @Published var messageType: MessageType = .error
    @Published var message: String? {
        didSet {
            if message != nil && messageType == .success {
                // Clear success messages after 3 seconds
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    if self.messageType == .success {
                        self.message = nil
                    }
                }
            }
        }
    }
    @Published var audioSamples: [URL: [Float]] = [:]
    @Published var isLoadingWaveform: Bool = false
    @Published private var transcribingRecordings: Set<UUID> = []
    
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
        setupAudioSession()
        
        // Initial loading of recordings and waveforms
        Task {
            await self.loadRecordings()
            await self.preloadAllWaveforms()
        }
    }
    
    // MARK: - Setup
    
    private func setupAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        } catch {
            self.messageType = .error
            self.message = "Failed to set up audio session: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Recording Functions
    
    func startRecording() {
        // Request microphone permission if needed
        AVAudioSession.sharedInstance().requestRecordPermission { [weak self] allowed in
            Task { @MainActor in
                guard let self = self else { return }
                if allowed {
                    self.initiateRecording()
                } else {
                    self.messageType = .error
                    self.message = "Microphone access is required to record audio."
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
            self.messageType = .error
            self.message = "Failed to start recording: \(error.localizedDescription)"
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
        
        // Load recordings to show the new recording
        Task {
            await self.loadRecordings()
        }
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
            self.updatePlayingStatus(for: recording.id, isPlaying: true)
            
            // Start timer to update playback progress
            startPlaybackTimer()
        } catch {
            self.messageType = .error
            self.message = "Failed to play recording: \(error.localizedDescription)"
        }
    }
    
    private func updatePlayingStatus(for id: UUID, isPlaying: Bool) {
        if let index = self.recordings.firstIndex(where: { $0.id == id }) {
            self.recordings[index].isPlaying = isPlaying
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
            self.updatePlayingStatus(for: recording.id, isPlaying: false)
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
    
    // MARK: - Recording Management
    
    func loadRecordings() async {
        self.recordings = fileManager.getAllRecordings()
        logger.debug("Loading \(self.recordings.count) recordings")
        
        // Load transcriptions for recordings
        for i in 0..<self.recordings.count {
            let recordingID = self.recordings[i].recordingID
            if let transcription = await TranscriptionManager.shared.getTranscription(for: recordingID) {
                if i < self.recordings.count { // Safety check
                    self.recordings[i].transcription = transcription
                }
            }
        }
        
        let count = await TranscriptionManager.shared.getTranscriptionCount()
        logger.debug("Loaded \(count) transcriptions")
        
        // Preload waveforms for newly loaded recordings
        await self.preloadAllWaveforms()
    }
    
    // MARK: - Waveform Functions
    
    func loadWaveformData(for recording: AudioRecording) async {
        // Skip if already loaded
        if self.audioSamples[recording.fileURL] != nil {
            return
        }
        
        self.isLoadingWaveform = true
        
        do {
            let samples = try await AudioAnalyzer.shared.extractSamples(from: recording.fileURL, samplesCount: 100)
            self.audioSamples[recording.fileURL] = samples
            self.isLoadingWaveform = false
        } catch {
            logger.error("Error loading waveform: \(error.localizedDescription)")
            self.isLoadingWaveform = false
        }
    }
    
    func preloadAllWaveforms() async {
        for recording in self.recordings {
            await self.loadWaveformData(for: recording)
        }
    }
    
    func deleteRecording(_ recording: AudioRecording) async {
        // Stop playback if this recording is playing
        if selectedRecording?.id == recording.id {
            stopPlayback()
        }
        
        // Delete the file and transcription
        if fileManager.deleteRecording(at: recording.fileURL) {
            do {
                try await TranscriptionManager.shared.deleteTranscription(for: recording.recordingID)
                if let index = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                    self.recordings.remove(at: index)
                }
            } catch {
                logger.error("Failed to delete transcription: \(error.localizedDescription)")
                self.messageType = .error
                self.message = "Failed to delete transcription: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Transcription
    
    func transcribeRecording(at url: URL) {
        guard let recording = self.recordings.first(where: { $0.fileURL == url }) else { return }
        
        // Vérifier d'abord si la clé API est valide
        guard AppSettings.shared.isAPIKeyValid else {
            self.messageType = .error
            self.message = "Veuillez configurer une clé API OpenAI valide dans les paramètres"
            return
        }
        
        self.transcribingRecordings.insert(recording.id)
        
        Task {
            do {
                let transcription = try await VoiceRecognitionService.shared.transcribeAudio(url: url)
                try await TranscriptionManager.shared.setTranscription(transcription, for: recording.recordingID)
                
                if let index = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                    self.recordings[index].transcription = transcription
                }
                self.transcribingRecordings.remove(recording.id)
                self.messageType = .success
                self.message = "Transcription terminée"
                await self.loadRecordings()
            } catch let error as VoiceRecognitionError {
                self.transcribingRecordings.remove(recording.id)
                self.messageType = .error
                self.message = error.localizedDescription
            } catch {
                self.transcribingRecordings.remove(recording.id)
                self.messageType = .error
                self.message = "Erreur inattendue: \(error.localizedDescription)"
            }
        }
    }
    
    func isTranscribing(_ recording: AudioRecording) -> Bool {
        self.transcribingRecordings.contains(recording.id)
    }
}

// MARK: - AVAudioRecorderDelegate

extension RecorderViewModel: AVAudioRecorderDelegate {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                self.messageType = .error
                self.message = "Recording failed to complete successfully."
            }
            
            // Update state
            self.recordingState = .idle
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension RecorderViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            // Update state
            self.recordingState = .idle
            self.playbackProgress = 0
            
            // Update the isPlaying flag for the selected recording
            if let recording = self.selectedRecording {
                self.updatePlayingStatus(for: recording.id, isPlaying: false)
            }
            
            self.selectedRecording = nil
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}
