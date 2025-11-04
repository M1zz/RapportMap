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
    @State private var selectedMeetingType: MeetingType = .general
    @State private var showingSaveConfirm = false
    @State private var showingShareSheet = false
    @State private var showingTranscriptView = false
    @State private var currentTranscript = ""
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // 녹음 상태 표시
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(recorder.isRecording ? Color.red.gradient : Color.gray.gradient)
                            .frame(width: 120, height: 120)
                            .scaleEffect(recorder.isRecording ? 1.1 : 1.0)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.isRecording)
                        
                        Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.white)
                    }
                    
                    Text(recorder.isRecording ? "녹음 중..." : "준비됨")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if recorder.isRecording {
                        Text(formatDuration(recorder.recordingDuration))
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.secondary)
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
                HStack(spacing: 40) {
                    if recorder.isRecording {
                        // 중지 버튼
                        Button {
                            recorder.stopRecording()
                            showingSaveConfirm = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "stop.circle.fill")
                                    .font(.system(size: 60))
                                Text("중지")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.red)
                    } else {
                        // 녹음 시작 버튼
                        Button {
                            recorder.startRecording()
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "record.circle")
                                    .font(.system(size: 60))
                                Text("녹음 시작")
                                    .font(.caption)
                            }
                        }
                        .foregroundStyle(.red)
                        
                        // 녹음 완료 후 전사 버튼
                        if recorder.audioFileURL != nil {
                            Button {
                                showingTranscriptView = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 50))
                                    Text("전사 보기")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.blue)
                        }
                        
                        // 공유 버튼
                        if recorder.audioFileURL != nil {
                            Button {
                                showingShareSheet = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 50))
                                    Text("공유")
                                        .font(.caption)
                                }
                            }
                            .foregroundStyle(.green)
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
                
                if recorder.audioFileURL != nil && !recorder.isRecording {
                    ToolbarItem(placement: .primaryAction) {
                        Button("저장") {
                            saveMeeting()
                        }
                        .disabled(recorder.isTranscribing)
                    }
                }
            }
            .confirmationDialog("녹음 완료", isPresented: $showingSaveConfirm) {
                Button("저장하기") {
                    saveMeeting()
                }
                Button("다시 녹음") {
                    recorder.reset()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("녹음된 내용을 저장하시겠습니까?")
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
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func saveMeeting() {
        guard let audioURL = recorder.audioFileURL else { return }
        
        // 최종 전사가 있으면 사용, 없으면 비동기로 처리
        if !recorder.finalTranscription.isEmpty {
            createMeetingRecord(with: recorder.finalTranscription, audioURL: audioURL)
        } else {
            // 비동기 전사 실행 - 필요한 값들을 직접 캡처
            let context = self.context
            let person = self.person
            let meetingType = self.selectedMeetingType
            let duration = recorder.recordingDuration
            let dismiss = self.dismiss
            
            recorder.transcribeAudio { transcribedText in
                DispatchQueue.main.async {
                    let meeting = MeetingRecord(
                        date: Date(),
                        meetingType: meetingType,
                        audioFileURL: audioURL.path,
                        transcribedText: transcribedText,
                        duration: duration
                    )
                    meeting.person = person
                    
                    context.insert(meeting)
                    try? context.save()
                    
                    dismiss()
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
        try? context.save()
        
        dismiss()
    }
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
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
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
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
        
        // 최종 전사 실행
        performFinalTranscription()
    }
    
    func reset() {
        recordingDuration = 0
        audioFileURL = nil
        finalTranscription = ""
        isTranscribing = false
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
    
    private func performFinalTranscription() {
        guard let audioURL = audioFileURL else { return }
        
        isTranscribing = true
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        
        speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isTranscribing = false
                if let result = result, result.isFinal {
                    self?.finalTranscription = result.bestTranscription.formattedString
                } else if let error = error {
                    print("전사 오류: \(error)")
                    self?.finalTranscription = ""
                }
            }
        }
    }
    
    func transcribeAudio(completion: @escaping (String) -> Void) {
        if !finalTranscription.isEmpty {
            completion(finalTranscription)
            return
        }
        
        guard let audioURL = audioFileURL else {
            completion("")
            return
        }
        
        let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
        
        speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                let transcription = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    completion(transcription)
                }
            } else {
                DispatchQueue.main.async {
                    completion("변환 실패")
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

