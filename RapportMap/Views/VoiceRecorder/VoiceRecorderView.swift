//
//  VoiceRecorderView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import SwiftUI
import AVFoundation
import Speech
import Combine
import SwiftData

struct VoiceRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let person: Person
    
    @StateObject private var recorder = VoiceRecorder()
    @State private var selectedInteractionType: InteractionType = .mentoring
    @State private var isSaved = false
    @State private var showingShareSheet = false
    @State private var showingTranscriptView = false
    @State private var currentTranscript = ""
    @State private var remainingTime: Double = 0.0
    @State private var dismissTimer: Timer?
    
    // 음성 녹음에 적합한 상호작용 유형만 필터링
    private let voiceRecordingInteractionTypes: [InteractionType] = [.mentoring, .meal, .contact]
    
    // 저장 상태 텍스트를 계산하는 computed property
    private var saveStatusText: String {
        if isSaved {
            return "저장 완료"
        } else if recorder.isTranscribing {
            return "저장 중..."
        } else {
            return "저장하기"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // 녹음 상태 표시
                VStack(spacing: 16) {
                    if recorder.isRecording {
                        // 녹음 중일 때는 음파만 표시
                        WaveformView(
                            audioLevels: recorder.audioLevels,
                            currentLevel: recorder.currentAudioLevel,
                            isRecording: recorder.isRecording
                        )
                        .padding(.horizontal)
                        
                        Text("녹음 중...")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(formatDuration(recorder.recordingDuration))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.secondary)
                    } else if recorder.audioFileURL != nil {
                        if isSaved {
                            // 저장 완료 상태
                            ZStack {
                                // 배경 원
                                Circle()
                                    .fill(Color.green.gradient)
                                    .frame(width: 120, height: 120)
                                
                                // 카운트다운 진행 바 (3초 동안)
                                if remainingTime > 0 {
                                    Circle()
                                        .trim(from: 0, to: CGFloat(3.0 - remainingTime) / 3.0)
                                        .stroke(Color.white, lineWidth: 4)
                                        .frame(width: 110, height: 110)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.linear(duration: 0.1), value: remainingTime)
                                }
                                
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white)
                            }
                            
                            Text("녹음 완료됨")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            // 저장 완료 후 자동 닫힘 카운트다운 표시
                            if remainingTime > 0 {
                                VStack(spacing: 8) {
                                    Text("저장이 완료되었습니다")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                    
                                    Text("\(Int(remainingTime))초 후 자동으로 닫힙니다")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        } else {
                            // 저장하기 버튼 (큰 사이즈)
                            Button {
                                saveMeeting()
                            } label: {
                                VStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.gradient)
                                            .frame(width: 120, height: 120)
                                        
                                        if recorder.isTranscribing {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(1.5)
                                        } else {
                                            Image(systemName: "square.and.arrow.down.fill")
                                                .font(.system(size: 50))
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    
                                    Text(saveStatusText)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                }
                            }
                            .disabled(recorder.isTranscribing)
                        }
                    } else {
                        // 녹음 준비 상태
                        ZStack {
                            Circle()
                                .fill(Color.gray.gradient)
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "mic.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.white)
                        }
                        
                        Text("준비됨")
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.top, 50)
                
                
                Spacer()
                
                // 상호작용 유형 선택
                VStack(alignment: .leading, spacing: 12) {
                    Text("상호작용 유형")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(voiceRecordingInteractionTypes, id: \.self) { type in
                                InteractionTypeButton(
                                    type: type,
                                    isSelected: selectedInteractionType == type
                                ) {
                                    // 녹음 완료 후에는 상호작용 유형 변경 불가
                                    if recorder.audioFileURL == nil {
                                        selectedInteractionType = type
                                    }
                                }
                                .disabled(recorder.audioFileURL != nil) // 녹음 완료 후 비활성화
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                // 컨트롤 버튼들
                VStack(spacing: 20) {
                    if recorder.isRecording {
                        // 녹음 중 - 녹음 완료 버튼
                        Button {
                            recorder.stopRecording()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 24))
                                Text("녹음 완료")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    } else if recorder.audioFileURL != nil && isSaved {
                        // 저장 완료 후 액션 버튼들
                        VStack(spacing: 16) {
                            // 주요 액션 버튼들
                            HStack(spacing: 16) {
                                // 전사 보기 버튼
                                Button {
                                    showingTranscriptView = true
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "doc.text.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.blue)
                                        Text("전사 보기")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                
                                // 공유 버튼
                                Button {
                                    showingShareSheet = true
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "square.and.arrow.up.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.orange)
                                        Text("공유")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            
                            // 새로운 녹음 시작 버튼
                            Button {
                                // 타이머 정리
                                dismissTimer?.invalidate()
                                dismissTimer = nil
                                remainingTime = 0
                                
                                // 상태 초기화
                                isSaved = false
                                recorder.reset()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 20))
                                    Text("새로운 녹음 시작")
                                        .font(.headline)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.blue.opacity(0.1))
                                .foregroundStyle(.blue)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue, lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // 초기 상태 - 녹음 시작 버튼
                        Button {
                            recorder.startRecording()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "mic.circle.fill")
                                    .font(.system(size: 24))
                                Text("녹음 시작")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom, 50)
        }
        .navigationTitle("상호작용 기록하기")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("취소") {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    }
                    dismiss()
                }
            }
        }

        .sheet(isPresented: $showingShareSheet) {
            if let audioURL = recorder.audioFileURL {
                ShareSheet(items: [audioURL])
            }
        }
        .sheet(isPresented: $showingTranscriptView) {
            TranscriptView(
                recorder: recorder,
                audioURL: recorder.audioFileURL,
                transcript: $currentTranscript
            )
        }
        .onAppear {
            print("VoiceRecorderView appeared")
        }
        .onDisappear {
            // 화면이 사라질 때 타이머 정리
            dismissTimer?.invalidate()
            dismissTimer = nil
        }
    }
    
    private func saveMeeting() {
        print("saveMeeting() called")
        
        guard let audioURL = recorder.audioFileURL else {
            print("Audio URL is nil")
            return
        }
        
        print("Audio URL exists: \(audioURL.path)")
        
        // 이미 저장 중이라면 중복 실행 방지
        if recorder.isTranscribing {
            print("Already processing transcription")
            return
        }
        
        // 이미 저장되었다면 중복 실행 방지
        if isSaved {
            print("Already saved")
            return
        }
        
        print("Starting save process...")
        
        // 최종 전사가 있으면 사용, 없으면 비동기로 처리
        if !recorder.finalTranscription.isEmpty {
            print("Using existing transcription: \(recorder.finalTranscription.prefix(50))...")
            createBothRecords(with: recorder.finalTranscription, audioURL: audioURL)
        } else {
            print("Starting transcription process...")
            // 비동기 전사 실행 - 중복 방지를 위해 상태 변경
            recorder.isTranscribing = true
            
            // 필요한 값들을 직접 캡처
            let context = self.context
            let person = self.person
            let interactionType = self.selectedInteractionType
            let duration = recorder.recordingDuration
            let dismiss = self.dismiss
            
            recorder.transcribeAudio { [weak recorder] (transcribedText: String) in
                DispatchQueue.main.async {
                    print("Transcription completed: \(transcribedText.prefix(50))...")
                    
                    // 중복 실행 방지 체크
                    guard recorder?.isTranscribing == true else {
                        print("Transcription already completed or cancelled")
                        return
                    }
                    
                    // 상태 리셋
                    recorder?.isTranscribing = false
                    
                    // InteractionRecord 생성 (새로운 방식)
                    let interaction = InteractionRecord(
                        date: Date(),
                        type: interactionType,
                        notes: transcribedText.isEmpty ? nil : transcribedText,
                        duration: duration
                    )
                    interaction.person = person
                    
                    // MeetingRecord도 생성 (기존 히스토리 유지를 위해)
                    let meetingType: MeetingType = {
                        switch interactionType {
                        case .mentoring: return .mentoring
                        case .meal: return .meal
                        case .contact: return .general
                        default: return .general
                        }
                    }()
                    
                    let meeting = MeetingRecord(
                        date: Date(),
                        meetingType: meetingType,
                        audioFileURL: audioURL.path,
                        transcribedText: transcribedText,
                        duration: duration
                    )
                    meeting.person = person
                    
                    context.insert(interaction)
                    context.insert(meeting)
                    
                    do {
                        try context.save()
                        print("Successfully saved both interaction and meeting records")
                        self.isSaved = true
                        
                        // 카운트다운 시작
                        self.startDismissCountdown()
                    } catch {
                        print("Error saving records: \(error)")
                    }
                }
            }
        }
    }
    
    private func createBothRecords(with transcription: String, audioURL: URL) {
        // InteractionRecord 생성 (새로운 상호작용 시스템)
        let interaction = InteractionRecord(
            date: Date(),
            type: selectedInteractionType,
            notes: transcription.isEmpty ? nil : transcription,
            duration: recorder.recordingDuration
        )
        interaction.person = person
        
        // MeetingRecord도 생성 (기존 시스템과 호환성 유지)
        let meetingType: MeetingType = {
            switch selectedInteractionType {
            case .mentoring: return .mentoring
            case .meal: return .meal
            case .contact: return .general
            default: return .general
            }
        }()
        
        let meeting = MeetingRecord(
            date: Date(),
            meetingType: meetingType,
            audioFileURL: audioURL.path,
            transcribedText: transcription,
            duration: recorder.recordingDuration
        )
        meeting.person = person
        
        context.insert(interaction)
        context.insert(meeting)
        
        do {
            try context.save()
            print("Successfully saved both records with transcription")
            isSaved = true
            
            // 카운트다운 시작
            startDismissCountdown()
        } catch {
            print("Error saving both records with transcription: \(error)")
        }
    }
    
    // 자동 닫힘 카운트다운 함수
    private func startDismissCountdown() {
        remainingTime = 3.0 // 3초 카운트다운 (실수형)
        
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            DispatchQueue.main.async {
                self.remainingTime -= 0.1
                
                if self.remainingTime <= 0 {
                    timer.invalidate()
                    self.dismissTimer = nil
                    self.dismiss()
                }
            }
        }
    }
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}


// MARK: - InteractionTypeButton
struct InteractionTypeButton: View {
    let type: InteractionType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(type.emoji)
                    .font(.title)
                Text(type.title)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - VoiceRecorder (ViewModel)
class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioFileURL: URL?
    @Published var finalTranscription = ""
    @Published var isTranscribing = false
    @Published var audioLevels: [Float] = Array(repeating: 0.0, count: 50) // 파형을 위한 오디오 레벨 배열
    @Published var currentAudioLevel: Float = 0.0
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private var levelTimer: Timer?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    
    override init() {
        super.init()
        setupPermissions()
        // 앱 시작 시 오래된 파일 정리
        cleanupOldAudioFiles()
    }
    
    private func setupPermissions() {
        // 마이크 권한
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        
        // 음성 인식 권한
        SFSpeechRecognizer.requestAuthorization { _ in }
    }
    
    // 30일 이상된 오디오 파일 자동 정리
    private func cleanupOldAudioFiles() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey], options: [])
            
            for file in files {
                if file.pathExtension == "m4a" && (file.lastPathComponent.hasPrefix("recording_") || file.lastPathComponent.hasPrefix("meeting_")) {
                    let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                    if let creationDate = attributes[.creationDate] as? Date,
                       creationDate < thirtyDaysAgo {
                        try FileManager.default.removeItem(at: file)
                        print("Deleted old audio file: \(file.lastPathComponent)")
                    }
                }
            }
        } catch {
            print("Error cleaning up old files: \(error)")
        }
    }
    
    func startRecording() {
        // 권한 확인
        guard AVAudioSession.sharedInstance().recordPermission == .granted else {
            print("마이크 권한이 필요합니다")
            return
        }
        
        setupRecorder()
        
        audioRecorder?.record()
        isRecording = true
        startTimer()
        startAudioLevelMonitoring()
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        levelTimer?.invalidate()
        levelTimer = nil
        currentAudioLevel = 0.0
        
        print("Recording stopped, audio file URL: \(audioFileURL?.path ?? "nil")")
        
        // 최종 전사 실행
        performFinalTranscription()
    }
    
    func reset() {
        recordingDuration = 0
        audioFileURL = nil
        finalTranscription = ""
        isTranscribing = false
        audioLevels = Array(repeating: 0.0, count: 50)
        currentAudioLevel = 0.0
    }
    
    private func setupRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? audioSession.setActive(true)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // 더 의미있는 파일명 생성
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        
        let audioFilename = documentsPath.appendingPathComponent("recording_\(timestamp).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.isMeteringEnabled = true // 오디오 레벨 측정 활성화
            audioFileURL = audioFilename
        } catch {
            print("Failed to setup recorder: \(error)")
        }
    }
    
    private func startTimer() {
        recordingDuration = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordingDuration += 1
        }
    }
    
    private func startAudioLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self, let recorder = self.audioRecorder else { return }
            
            recorder.updateMeters()
            let averagePower = recorder.averagePower(forChannel: 0)
            let peakPower = recorder.peakPower(forChannel: 0)
            
            // 데시벨을 0-1 범위로 변환 (-60dB ~ 0dB 범위를 사용)
            let normalizedLevel = max(0.0, min(1.0, (averagePower + 60.0) / 60.0))
            let normalizedPeak = max(0.0, min(1.0, (peakPower + 60.0) / 60.0))
            
            DispatchQueue.main.async {
                self.currentAudioLevel = normalizedPeak
                
                // 파형 데이터 업데이트 (배열의 첫 번째 요소 제거, 마지막에 새 값 추가)
                self.audioLevels.removeFirst()
                self.audioLevels.append(normalizedLevel)
            }
        }
    }
    
    private func performFinalTranscription() {
        guard let audioURL = audioFileURL else {
            print("No audio URL for final transcription")
            return
        }
        
        // 이미 전사 중인 경우 중복 실행 방지
        if isTranscribing {
            print("Final transcription already in progress")
            return
        }
        
        isTranscribing = true
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        
        speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                self.isTranscribing = false
                
                if let result = result, result.isFinal {
                    self.finalTranscription = result.bestTranscription.formattedString
                    print("Final transcription completed: \(self.finalTranscription.prefix(50))...")
                } else if let error = error {
                    print("전사 오류: \(error)")
                    self.finalTranscription = ""
                } else {
                    print("No transcription result")
                    self.finalTranscription = ""
                }
            }
        }
    }
    
    func transcribeAudio(completion: @escaping (String) -> Void) {
        // 이미 전사가 완료된 경우
        if !finalTranscription.isEmpty {
            completion(finalTranscription)
            return
        }
        
        // 이미 전사 중인 경우 중복 실행 방지
        if isTranscribing {
            print("Transcription already in progress")
            return
        }
        
        guard let audioURL = audioFileURL else {
            print("Audio URL is nil for transcription")
            completion("")
            return
        }
        
        isTranscribing = true
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        
        speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 이미 처리된 경우 중복 실행 방지
                if !self.isTranscribing {
                    print("Transcription was already completed")
                    return
                }
                
                self.isTranscribing = false
                
                if let result = result {
                    let transcription = result.bestTranscription.formattedString
                    self.finalTranscription = transcription
                    completion(transcription)
                } else if let error = error {
                    print("전사 오류: \(error)")
                    completion("음성 변환에 실패했습니다.")
                } else {
                    completion("")
                }
            }
        }
    }
}

// MARK: - TranscriptView
struct TranscriptView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var recorder: VoiceRecorder
    let audioURL: URL?
    @Binding var transcript: String
    @State private var isEditing = false
    @State private var editableTranscript = ""
    @State private var showingShareSheet = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 헤더 정보
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title)
                            .foregroundStyle(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("음성 전사 결과")
                                .font(.headline)
                            
                            if recorder.recordingDuration > 0 {
                                Text("길이: \(formatDuration(recorder.recordingDuration))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            if recorder.isTranscribing {
                                HStack(spacing: 6) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("전사 중...")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                        
                        // 공유 버튼
                        Button {
                            showingShareSheet = true
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                        }
                        .disabled(currentTranscript.isEmpty)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                Divider()
                
                // 전사 텍스트
                if isEditing {
                    TextEditor(text: $editableTranscript)
                        .font(.body)
                        .padding()
                        .background(Color(.systemBackground))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            if currentTranscript.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                    
                                    Text("전사 결과가 없습니다")
                                        .font(.headline)
                                        .foregroundStyle(.secondary)
                                    
                                    if let audioURL = audioURL {
                                        Button("다시 전사하기") {
                                            recorder.transcribeAudio { newTranscript in
                                                transcript = newTranscript
                                                editableTranscript = newTranscript
                                            }
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .multilineTextAlignment(.center)
                            } else {
                                Text(currentTranscript)
                                    .font(.body)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding()
                    }
                }
                
                Spacer()
            }
            .navigationTitle("전사 결과")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(isEditing ? "완료" : "편집") {
                        if isEditing {
                            // 편집 완료
                            transcript = editableTranscript
                            recorder.finalTranscription = editableTranscript
                        } else {
                            // 편집 시작
                            editableTranscript = currentTranscript
                        }
                        isEditing.toggle()
                    }
                    .disabled(currentTranscript.isEmpty)
                }
            }
            .onAppear {
                editableTranscript = currentTranscript
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(items: [currentTranscript])
            }
        }
    }
    
    private var currentTranscript: String {
        isEditing ? editableTranscript : (!recorder.finalTranscription.isEmpty ? recorder.finalTranscription : transcript)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d분 %d초", minutes, seconds)
    }
}



// MARK: - Waveform View
struct WaveformView: View {
    let audioLevels: [Float]
    let currentLevel: Float
    let isRecording: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // 실시간 파형 표시
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<audioLevels.count, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(waveformGradient(for: index))
                        .frame(width: 3, height: max(2, CGFloat(audioLevels[index]) * 50))
                        .animation(.easeInOut(duration: 0.1), value: audioLevels[index])
                }
            }
            .frame(height: 60)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            
            // 현재 음량 레벨 표시
            if isRecording {
                HStack {
                    Text("음량 레벨:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ProgressView(value: currentLevel, total: 1.0)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 4)
                        .scaleEffect(y: 2)
                    
                    Text("\(Int(currentLevel * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 35, alignment: .trailing)
                }
                .padding(.horizontal)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func waveformGradient(for index: Int) -> LinearGradient {
        let level = audioLevels[index]
        let isRecentIndex = index >= audioLevels.count - 10 // 최근 10개 샘플
        
        // 회색 기준으로 단순화된 색상
        if level > 0.7 {
            // 높은 음량 - 진한 회색
            return LinearGradient(
                colors: isRecentIndex ? [.gray, .black] : [.gray.opacity(0.6), .black.opacity(0.6)],
                startPoint: .bottom,
                endPoint: .top
            )
        } else if level > 0.3 {
            // 중간 음량 - 중간 회색
            return LinearGradient(
                colors: isRecentIndex ? [.gray.opacity(0.7), .gray] : [.gray.opacity(0.4), .gray.opacity(0.4)],
                startPoint: .bottom,
                endPoint: .top
            )
        } else {
            // 낮은 음량 - 연한 회색
            return LinearGradient(
                colors: isRecentIndex ? [.gray.opacity(0.3), .gray.opacity(0.5)] : [.gray.opacity(0.2), .gray.opacity(0.3)],
                startPoint: .bottom,
                endPoint: .top
            )
        }
    }
}

