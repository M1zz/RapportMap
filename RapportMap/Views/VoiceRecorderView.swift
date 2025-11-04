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
    @State private var selectedMeetingType: MeetingType = .mentoring
    @State private var showingSaveConfirm = false
    @State private var showingShareSheet = false
    @State private var showingTranscriptView = false
    @State private var currentTranscript = ""
    
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
                
                // 만남 타입 선택
                VStack(alignment: .leading, spacing: 12) {
                    Text("만남 유형")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(MeetingType.allCases, id: \.self) { type in
                                MeetingTypeButton(
                                    type: type,
                                    isSelected: selectedMeetingType == type
                                ) {
                                    selectedMeetingType = type
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                
                // 컨트롤 버튼들
                VStack(spacing: 20) {
                    if recorder.isRecording {
                        // 녹음 중 - 중지 버튼
                        Button {
                            recorder.stopRecording()
                            showingSaveConfirm = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 24))
                                Text("녹음 중지")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.red)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .padding(.horizontal)
                    } else if recorder.audioFileURL != nil {
                        // 녹음 완료 상태 - 액션 버튼들
                        VStack(spacing: 16) {
                            // 주요 액션 버튼들
                            HStack(spacing: 16) {
                                // 저장 버튼
                                Button {
                                    saveMeeting()
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.green)
                                        Text("저장")
                                            .font(.caption)
                                            .foregroundStyle(.primary)
                                    }
                                }
                                .disabled(recorder.isTranscribing)
                                
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
        .navigationTitle("만남 기록하기")
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
        .confirmationDialog("녹음 완료", isPresented: $showingSaveConfirm) {
            Button("저장하기") {
                if !recorder.isTranscribing {
                    saveMeeting()
                }
            }
            .disabled(recorder.isTranscribing)
            Button("계속 작업") {
                // 아무것도 하지 않음 - 녹음 완료 상태를 유지
            }
            Button("취소", role: .cancel) {
                recorder.reset()
            }
        } message: {
            Text("녹음이 완료되었습니다. 어떻게 하시겠습니까?")
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
    }
    
    private func saveMeeting() {
        guard let audioURL = recorder.audioFileURL else {
            print("Audio URL is nil")
            return
        }
        
        // 이미 저장 중이라면 중복 실행 방지
        if recorder.isTranscribing {
            print("Already processing transcription")
            return
        }
        
        // 최종 전사가 있으면 사용, 없으면 비동기로 처리
        if !recorder.finalTranscription.isEmpty {
            createMeetingRecord(with: recorder.finalTranscription, audioURL: audioURL)
        } else {
            // 비동기 전사 실행 - 중복 방지를 위해 상태 변경
            recorder.isTranscribing = true
            
            // 필요한 값들을 직접 캡처
            let context = self.context
            let person = self.person
            let meetingType = self.selectedMeetingType
            let duration = recorder.recordingDuration
            let dismiss = self.dismiss
            
            recorder.transcribeAudio { [weak recorder] (transcribedText: String) in
                DispatchQueue.main.async {
                    // 중복 실행 방지 체크
                    guard recorder?.isTranscribing == true else {
                        print("Transcription already completed or cancelled")
                        return
                    }
                    
                    // 상태 리셋
                    recorder?.isTranscribing = false
                    
                    let meeting = MeetingRecord(
                        date: Date(),
                        meetingType: meetingType,
                        audioFileURL: audioURL.path,
                        transcribedText: transcribedText,
                        duration: duration
                    )
                    meeting.person = person
                    
                    context.insert(meeting)
                    
                    do {
                        try context.save()
                        print("Successfully saved meeting record")
                        dismiss()
                    } catch {
                        print("Error saving meeting record: \(error)")
                    }
                }
            }
        }
    }
    
    private func createMeetingRecord(with transcription: String, audioURL: URL) {
        let meeting = MeetingRecord(
            date: Date(),
            meetingType: selectedMeetingType,
            audioFileURL: audioURL.path,
            transcribedText: transcription,
            duration: recorder.recordingDuration
        )
        meeting.person = person
        
        context.insert(meeting)
        
        do {
            try context.save()
            print("Successfully saved meeting record with transcription")
            dismiss()
        } catch {
            print("Error saving meeting record with transcription: \(error)")
        }
    }
}

private func formatDuration(_ duration: TimeInterval) -> String {
    let minutes = Int(duration) / 60
    let seconds = Int(duration) % 60
    return String(format: "%02d:%02d", minutes, seconds)
}


// MARK: - MeetingTypeButton
struct MeetingTypeButton: View {
    let type: MeetingType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(type.emoji)
                    .font(.title)
                Text(type.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
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
    }
    
    private func setupPermissions() {
        // 마이크 권한
        AVAudioSession.sharedInstance().requestRecordPermission { _ in }
        
        // 음성 인식 권한
        SFSpeechRecognizer.requestAuthorization { _ in }
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
        let audioFilename = documentsPath.appendingPathComponent("meeting_\(Date().timeIntervalSince1970).m4a")
        
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

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
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

