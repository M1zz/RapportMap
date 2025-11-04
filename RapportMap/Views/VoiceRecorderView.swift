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
                    }
                }
                .padding(.horizontal)
                
                // 녹음 버튼
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
            .alert("녹음 저장", isPresented: $showingSaveConfirm) {
                Button("저장") {
                    saveMeeting()
                }
                Button("다시 녹음", role: .cancel) {
                    recorder.reset()
                }
                Button("공유 후 저장") {
                    showingShareSheet = true
                }
            } message: {
                Text("녹음을 저장하시겠어요?")
            }
            .sheet(isPresented: $showingShareSheet) {
                if let audioURL = recorder.audioFileURL {
                    ShareSheet(items: [audioURL])
                }
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func saveMeeting() {
        // 텍스트 변환 (비동기)
        if let audioURL = recorder.audioFileURL {
            recorder.transcribeAudio { transcribedText in
                let meeting = MeetingRecord(
                    date: Date(),
                    meetingType: selectedMeetingType,
                    audioFileURL: audioURL.path,
                    transcribedText: transcribedText,
                    duration: recorder.recordingDuration
                )
                meeting.person = person
                
                context.insert(meeting)
                try? context.save()
                
                dismiss()
            }
        } else {
            dismiss()
        }
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
    
    private var audioRecorder: AVAudioRecorder?
    private var timer: Timer?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ko-KR"))
    
    func startRecording() {
        // 권한 요청
        AVAudioSession.sharedInstance().requestRecordPermission { allowed in
            if allowed {
                DispatchQueue.main.async {
                    self.setupRecorder()
                    self.audioRecorder?.record()
                    self.isRecording = true
                    self.startTimer()
                }
            }
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        timer?.invalidate()
        timer = nil
    }
    
    func reset() {
        recordingDuration = 0
        audioFileURL = nil
    }
    
    private func setupRecorder() {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .default)
        try? audioSession.setActive(true)
        
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioFilename = documentsPath.appendingPathComponent("meeting_\(Date().timeIntervalSince1970).m4a")
        
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
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
    
    func transcribeAudio(completion: @escaping (String) -> Void) {
        guard let audioURL = audioFileURL else {
            completion("")
            return
        }
        
        // Speech Recognition 권한 요청
        SFSpeechRecognizer.requestAuthorization { authStatus in
            if authStatus == .authorized {
                let recognitionRequest = SFSpeechURLRecognitionRequest(url: audioURL)
                
                self.speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
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
            } else {
                completion("음성 인식 권한 없음")
            }
        }
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

