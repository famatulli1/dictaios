
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
        stopPlayback()
        
        recordingURL = fileManager.generateRecordingURL()
        guard let url = recordingURL else { return }
        
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
            
            recordingState = .recording
            recordingStartTime = Date()
            startRecordingTimer()
        } catch {
            self.messageType = .error
            self.message = "Failed to start recording: \(error.localizedDescription)"
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
    
    func stopRecording() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        
        recorder.stop()
        audioRecorder = nil
        progressTimer?.invalidate()
        progressTimer = nil
        recordingState = .idle
        
        Task {
            await self.loadRecordings()
        }
    }
    
    // MARK: - Playback Functions
    
    func playRecording(_ recording: AudioRecording) {
        stopRecording()
        stopPlayback()
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: recording.fileURL)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            
            recordingState = .playing
            selectedRecording = recording
            self.updatePlayingStatus(for: recording.id, isPlaying: true)
            startPlaybackTimer()
        } catch {
            self.messageType = .error
            self.message = "Failed to play recording: \(error.localizedDescription)"
        }
    }
    
    func stopPlayback() {
        guard let player = audioPlayer, player.isPlaying else { return }
        
        player.stop()
        audioPlayer = nil
        progressTimer?.invalidate()
        progressTimer = nil
        recordingState = .idle
        playbackProgress = 0
        
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
    
    private func updatePlayingStatus(for id: UUID, isPlaying: Bool) {
        if let index = self.recordings.firstIndex(where: { $0.id == id }) {
            var updatedRecording = self.recordings[index]
            updatedRecording.isPlaying = isPlaying
            self.recordings[index] = updatedRecording
        }
    }
    
    // MARK: - Recording Management
    
    func loadRecordings() async {
        logger.notice("Loading recordings...")
        
        // First get all recordings from the file system
        let allRecordings = fileManager.getAllRecordings()
        logger.notice("Found \(allRecordings.count) recording files")
        
        // Then load their transcriptions
        var recordingsWithTranscriptions: [AudioRecording] = []
        for recording in allRecordings {
            let recordingID = recording.recordingID
            if let transcription = await TranscriptionManager.shared.getTranscription(for: recordingID) {
                var updatedRecording = recording
                updatedRecording.transcription = transcription
                recordingsWithTranscriptions.append(updatedRecording)
                logger.notice("Found transcription for recording \(recordingID)")
            } else {
                recordingsWithTranscriptions.append(recording)
                logger.notice("No transcription found for recording \(recordingID)")
            }
        }
        
        // Update the recordings array
        self.recordings = recordingsWithTranscriptions
        
        // Log transcription status
        let transcribedCount = recordingsWithTranscriptions.filter { $0.transcription != nil }.count
        logger.notice("Loaded \(transcribedCount) transcriptions out of \(recordingsWithTranscriptions.count) recordings")
        
        // Log all recordings and their transcription status
        for recording in recordingsWithTranscriptions {
            logger.debug("""
                Recording ID: \(recording.recordingID)
                File: \(recording.fileName)
                Has transcription: \(recording.transcription != nil)
                Transcription: \(recording.transcription ?? "none")
                """)
        }
    }
    
    // MARK: - Waveform Functions
    
    func loadWaveformData(for recording: AudioRecording) async {
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
        if selectedRecording?.id == recording.id {
            stopPlayback()
        }
        
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
        guard let recording = self.recordings.first(where: { $0.fileURL == url }) else {
            logger.error("No recording found for URL: \(url)")
            return
        }
        
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
                
                // Log the transcription result
                logger.notice("Successfully transcribed recording: \(recording.recordingID)")
                logger.debug("Transcription content: \(transcription)")
                
                // Update the recording with its transcription
                if let index = self.recordings.firstIndex(where: { $0.id == recording.id }) {
                    var updatedRecording = self.recordings[index]
                    updatedRecording.transcription = transcription
                    self.recordings[index] = updatedRecording
                    logger.notice("Updated recording with transcription")
                }
                
                self.transcribingRecordings.remove(recording.id)
                self.messageType = .success
                self.message = "Transcription terminée"
                
                // Reload all recordings to ensure everything is in sync
                await self.loadRecordings()
                
                // Log final state
                let transcribedCount = self.recordings.filter { $0.transcription != nil }.count
                logger.notice("Current state: \(transcribedCount) transcribed recordings out of \(self.recordings.count)")
                
            } catch let error as VoiceRecognitionError {
                logger.error("Transcription failed: \(error.localizedDescription)")
                self.transcribingRecordings.remove(recording.id)
                self.messageType = .error
                self.message = error.localizedDescription
            } catch {
                logger.error("Unexpected error during transcription: \(error.localizedDescription)")
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
            
            self.recordingState = .idle
            self.progressTimer?.invalidate()
            self.progressTimer = nil
            
            await self.loadRecordings()
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension RecorderViewModel: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.recordingState = .idle
            self.playbackProgress = 0
            
            if let recording = self.selectedRecording {
                self.updatePlayingStatus(for: recording.id, isPlaying: false)
            }
            
            self.selectedRecording = nil
            self.progressTimer?.invalidate()
            self.progressTimer = nil
        }
    }
}
