//
//  MentoringSessionSheet.swift
//  RapportMap
//
//  멘토링 세션 — 음성·전사·Numbers 로우데이터 + 요약 작성 + 전사 리더 뷰
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import AVFoundation

// MARK: - 멘토링 세션 행 (기록 탭 목록)

struct MentoringSessionRow: View {
    let session: MentoringSession
    let sessionNumber: Int
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var showingDetail = false

    var body: some View {
        Button { showingDetail = true } label: {
            HStack(spacing: 12) {
                // 왼쪽 보라 세로선
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.purple.opacity(0.6))
                    .frame(width: 4)

                VStack(alignment: .leading, spacing: 6) {
                    // 세션 번호 + 제목 + 날짜
                    HStack(spacing: 8) {
                        Text("\(sessionNumber)차")
                            .font(.body).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.purple).cornerRadius(6)

                        Text(session.title.isEmpty ? "멘토링 세션" : session.title)
                            .font(.body).fontWeight(.semibold)
                            .lineLimit(1)

                        Spacer()

                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.body).foregroundStyle(.secondary)
                    }

                    // 상태 아이콘 배지 (아이콘만, 컴팩트)
                    HStack(spacing: 6) {
                        compactBadge("waveform", active: !session.audioFileName.isEmpty, color: .purple)
                        compactBadge("text.quote", active: !session.transcript.isEmpty, color: .blue)
                        compactBadge("tablecells", active: session.numbersURL != nil, color: .green)
                        compactBadge("text.badge.checkmark", active: !session.summary.isEmpty, color: .orange)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color.purple.opacity(0.04))
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.purple.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button { onEdit() } label: { Label("수정", systemImage: "pencil") }
            Button(role: .destructive) { onDelete() } label: { Label("삭제", systemImage: "trash") }
        }
        .sheet(isPresented: $showingDetail) {
            MentoringSessionDetailSheet(session: session)
        }
    }

    private func compactBadge(_ icon: String, active: Bool, color: Color) -> some View {
        Image(systemName: icon)
            .font(.body)
            .foregroundStyle(active ? color : Color.secondary.opacity(0.3))
    }

    @ViewBuilder
    private func summaryPreview(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.isEmpty {
                    Spacer().frame(height: 6)
                } else if let attr = try? AttributedString(markdown: line) {
                    Text(attr).font(.body)
                } else {
                    Text(line).font(.body)
                }
            }
        }
    }

    private func rawBadge(_ icon: String, _ label: String, active: Bool, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.body)
            Text(label).font(.body).lineLimit(1)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(active ? color.opacity(0.12) : Color.secondary.opacity(0.08))
        .foregroundStyle(active ? color : Color.secondary)
        .cornerRadius(8)
    }
}

// MARK: - 멘토링 세션 추가 시트

struct MentoringSessionAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let person: Person

    @State private var title = ""
    @State private var date = Date()
    @State private var transcript = ""
    @State private var audioFileName = ""
    @State private var numbersURL = ""
    @State private var summary = ""
    @State private var showingAudioPicker = false
    @State private var showingTranscriptPicker = false

    var body: some View {
        NavigationStack {
            MentoringSessionFormContent(
                title: $title, date: $date,
                transcript: $transcript, audioFileName: $audioFileName,
                numbersURL: $numbersURL, summary: $summary,
                showingAudioPicker: $showingAudioPicker,
                showingTranscriptPicker: $showingTranscriptPicker
            )
            .navigationTitle("멘토링 세션 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.isEmpty && transcript.isEmpty && audioFileName.isEmpty && numbersURL.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 520, height: 680)
        #endif
    }

    private func save() {
        let trimmedURL = numbersURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let session = MentoringSession(
            title: title.isEmpty ? "\(date.formatted(date: .abbreviated, time: .omitted)) 멘토링" : title,
            date: date, transcript: transcript,
            audioFileName: audioFileName,
            numbersURL: trimmedURL.isEmpty ? nil : trimmedURL
        )
        session.summary = summary
        session.person = person
        person.mentoringSessions = (person.mentoringSessions ?? []) + [session]
        try? context.save()
        dismiss()
    }
}

// MARK: - 멘토링 세션 수정 시트

struct MentoringSessionEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var session: MentoringSession

    @State private var title = ""
    @State private var date = Date()
    @State private var transcript = ""
    @State private var audioFileName = ""
    @State private var numbersURL = ""
    @State private var summary = ""
    @State private var isLoaded = false
    @State private var showingAudioPicker = false
    @State private var showingTranscriptPicker = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoaded {
                    MentoringSessionFormContent(
                        title: $title, date: $date,
                        transcript: $transcript, audioFileName: $audioFileName,
                        numbersURL: $numbersURL, summary: $summary,
                        showingAudioPicker: $showingAudioPicker,
                        showingTranscriptPicker: $showingTranscriptPicker
                    )
                } else {
                    ProgressView("불러오는 중…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("세션 수정")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("취소") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isLoaded)
                }
            }
        }
        #if os(macOS)
        .frame(width: 520, height: 680)
        #endif
        .task { await populateFields() }
    }

    @MainActor
    private func populateFields() async {
        await Task.yield()
        title         = session.title
        date          = session.date
        audioFileName = session.audioFileName
        numbersURL    = session.numbersURL ?? ""
        summary       = session.summary
        transcript    = session.transcript
        isLoaded      = true
    }

    private func save() {
        let trimmedURL = numbersURL.trimmingCharacters(in: .whitespacesAndNewlines)
        session.title         = title.isEmpty ? "\(date.formatted(date: .abbreviated, time: .omitted)) 멘토링" : title
        session.date          = date
        session.transcript    = transcript
        session.audioFileName = audioFileName
        session.numbersURL    = trimmedURL.isEmpty ? nil : trimmedURL
        session.summary       = summary
        try? context.save()
        dismiss()
    }
}

// MARK: - 공통 폼 컨텐츠

private struct MentoringSessionFormContent: View {
    @Binding var title: String
    @Binding var date: Date
    @Binding var transcript: String
    @Binding var audioFileName: String
    @Binding var numbersURL: String
    @Binding var summary: String
    @Binding var showingAudioPicker: Bool
    @Binding var showingTranscriptPicker: Bool

    @State private var isLoadingTranscript = false
    @State private var transcriptLoadError = false

    var body: some View {
        Form {
            // 세션 정보
            Section("세션 정보") {
                TextField("제목 (예: 1차 멘토링)", text: $title)
                DatePicker("날짜", selection: $date, displayedComponents: .date)
            }

            // 음성 파일
            Section {
                if audioFileName.isEmpty {
                    filePickerRow(icon: "waveform.badge.plus", color: .purple, label: "음성 파일 연결") {
                        #if os(macOS)
                        pickAudioMac()
                        #else
                        showingAudioPicker = true
                        #endif
                    }
                } else {
                    attachedRow(icon: "waveform", color: .purple, name: audioFileName) { audioFileName = "" }
                }
            } header: { Text("음성 파일") }

            // 전사 텍스트
            Section {
                if isLoadingTranscript {
                    HStack(spacing: 10) {
                        ProgressView().scaleEffect(0.85).frame(width: 22)
                        Text("파일 읽는 중…").foregroundStyle(.secondary)
                    }
                } else {
                    filePickerRow(
                        icon: "doc.text.below.ecg",
                        color: transcriptLoadError ? .red : .blue,
                        label: transcriptLoadError ? "파일을 읽지 못했어요 (재시도)"
                            : transcript.isEmpty ? "전사 파일 가져오기 (.txt)" : "파일로 교체"
                    ) {
                        transcriptLoadError = false
                        #if os(macOS)
                        pickTranscriptMac()
                        #else
                        showingTranscriptPicker = true
                        #endif
                    }
                }

                ZStack(alignment: .topLeading) {
                    if transcript.isEmpty && !isLoadingTranscript {
                        Text("또는 여기에 직접 붙여넣기")
                            .font(.body).foregroundStyle(.secondary.opacity(0.6))
                            .padding(.top, 8).padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $transcript)
                        .font(.body)
                        .frame(minHeight: 140, maxHeight: 320)
                        .disabled(isLoadingTranscript)
                        .scrollContentBackground(.hidden)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: {
                HStack {
                    Text("전사 텍스트")
                    Spacer()
                    if isLoadingTranscript {
                        Text("로딩 중").font(.body).foregroundStyle(.secondary)
                    } else if !transcript.isEmpty {
                        Text("\(transcript.count)자").font(.body).foregroundStyle(.secondary)
                    }
                }
            }

            // 요약
            Section {
                ZStack(alignment: .topLeading) {
                    if summary.isEmpty {
                        Text("세션의 핵심 내용을 정리해보세요")
                            .font(.body).foregroundStyle(.secondary.opacity(0.6))
                            .padding(.top, 8).padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                    TextEditor(text: $summary)
                        .font(.body)
                        .frame(minHeight: 100, maxHeight: 200)
                        .scrollContentBackground(.hidden)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            } header: {
                HStack {
                    Text("요약")
                    Spacer()
                    if !summary.isEmpty {
                        Text("\(summary.count)자").font(.body).foregroundStyle(.secondary)
                    }
                }
            }

            // Numbers 링크
            Section {
                if numbersURL.isEmpty {
                    filePickerRow(icon: "link.badge.plus", color: .green, label: "클립보드에서 링크 붙여넣기") { pasteURL() }
                    TextField("또는 직접 입력", text: $numbersURL, axis: .vertical)
                        .lineLimit(1...3)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                        .font(.body)
                } else {
                    attachedRow(icon: "tablecells.fill", color: .green, name: numbersURL, truncate: true) { numbersURL = "" }
                }
            } header: { Text("Numbers 링크") }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        #if os(iOS)
        .fileImporter(isPresented: $showingAudioPicker, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
            if case .success(let urls) = result, let url = urls.first {
                audioFileName = copyAudioToDocuments(from: url) ?? url.lastPathComponent
            }
        }
        .fileImporter(isPresented: $showingTranscriptPicker, allowedContentTypes: [.plainText, .text], allowsMultipleSelection: false) { result in
            guard case .success(let urls) = result, let url = urls.first else { return }
            Task { await loadTranscript(from: url) }
        }
        #endif
    }

    // MARK: - 비동기 파일 로딩

    @MainActor
    private func loadTranscript(from url: URL) async {
        isLoadingTranscript = true
        transcriptLoadError = false
        let accessed = url.startAccessingSecurityScopedResource()
        let result = await Task.detached(priority: .userInitiated) { () -> String? in
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            if let t = try? String(contentsOf: url, encoding: .utf8),  !t.isEmpty { return t }
            if let t = try? String(contentsOf: url, encoding: .utf16), !t.isEmpty { return t }
            return nil
        }.value
        if let text = result { transcript = text } else { transcriptLoadError = true }
        isLoadingTranscript = false
    }

    // MARK: - 재사용 행

    private func filePickerRow(icon: String, color: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(color).frame(width: 22)
                Text(label).foregroundStyle(color)
                Spacer()
                Image(systemName: "chevron.right").font(.body).foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func attachedRow(icon: String, color: Color, name: String, truncate: Bool = false, onRemove: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 22)
            Text(name).font(.body).lineLimit(truncate ? 2 : 1).truncationMode(.middle)
            Spacer()
            Button(action: onRemove) { Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary) }
                .buttonStyle(.plain)
        }
    }

    // MARK: - 헬퍼

    private func pasteURL() {
        #if os(macOS)
        if let s = NSPasteboard.general.string(forType: .string) { numbersURL = s }
        #else
        if let s = UIPasteboard.general.string { numbersURL = s }
        #endif
    }

    #if os(macOS)
    private func pickAudioMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.message = "멘토링 음성 파일을 선택하세요"
        if panel.runModal() == .OK, let url = panel.url {
            audioFileName = copyAudioToDocuments(from: url) ?? url.lastPathComponent
        }
    }

    private func pickTranscriptMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.message = "전사 텍스트 파일을 선택하세요"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        Task { await loadTranscript(from: url) }
    }
    #endif
}

// MARK: - 오디오 파일 헬퍼

private func copyAudioToDocuments(from url: URL) -> String? {
    let accessed = url.startAccessingSecurityScopedResource()
    defer { if accessed { url.stopAccessingSecurityScopedResource() } }
    let fm = FileManager.default
    guard let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let audioDir = docsURL.appendingPathComponent("MentoringAudio")
    try? fm.createDirectory(at: audioDir, withIntermediateDirectories: true)
    let dest = audioDir.appendingPathComponent(url.lastPathComponent)
    if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
    try? fm.copyItem(at: url, to: dest)
    return fm.fileExists(atPath: dest.path) ? url.lastPathComponent : nil
}

private func audioFileURL(for filename: String) -> URL? {
    guard !filename.isEmpty,
          let docsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
    let url = docsURL.appendingPathComponent("MentoringAudio").appendingPathComponent(filename)
    return FileManager.default.fileExists(atPath: url.path) ? url : nil
}

// MARK: - 오디오 플레이어 뷰모델

@Observable
final class AudioPlayerViewModel: NSObject, AVAudioPlayerDelegate {
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 1
    private(set) var isAvailable = false

    private var player: AVAudioPlayer?
    private var timer: Timer?

    func load(url: URL) {
        stop()
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            duration = max(player?.duration ?? 1, 1)
            isAvailable = true
        } catch {
            isAvailable = false
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            stopTimer()
            isPlaying = false
        } else {
            #if os(iOS)
            try? AVAudioSession.sharedInstance().setCategory(.playback)
            try? AVAudioSession.sharedInstance().setActive(true)
            #endif
            player.play()
            isPlaying = true
            startTimer()
        }
    }

    func seek(to time: TimeInterval) {
        player?.currentTime = time
        currentTime = time
    }

    func stop() {
        player?.stop()
        player = nil
        stopTimer()
        isPlaying = false
        currentTime = 0
        duration = 1
        isAvailable = false
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            guard let self, let p = self.player else { return }
            self.currentTime = p.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully _: Bool) {
        isPlaying = false
        stopTimer()
        player.currentTime = 0
        currentTime = 0
    }
}

// MARK: - 오디오 플레이어 뷰

struct AudioPlayerView: View {
    @Binding var filename: String
    @State private var vm = AudioPlayerViewModel()
    @State private var showingFilePicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 파일명
            HStack(spacing: 8) {
                Image(systemName: "waveform").foregroundStyle(.purple)
                Text(filename)
                    .font(.body).lineLimit(1).truncationMode(.middle)
                    .foregroundStyle(.secondary)
            }

            if vm.isAvailable {
                Slider(
                    value: Binding(get: { vm.currentTime }, set: { vm.seek(to: $0) }),
                    in: 0...vm.duration
                )
                .tint(.purple)

                HStack {
                    Text(timeString(vm.currentTime))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    Spacer()
                    Button { vm.togglePlayPause() } label: {
                        Image(systemName: vm.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.purple)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(timeString(vm.duration))
                        .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else {
                // 파일 없음 — 다시 연결 버튼
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                    Text("파일을 찾을 수 없습니다")
                        .font(.body).foregroundStyle(.secondary)
                    Spacer()
                    Button("다시 연결") {
                        #if os(macOS)
                        relinkMac()
                        #else
                        showingFilePicker = true
                        #endif
                    }
                    .font(.body)
                    .foregroundStyle(.purple)
                    .buttonStyle(.plain)
                }
                #if os(iOS)
                .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.audio], allowsMultipleSelection: false) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        if let newName = copyAudioToDocuments(from: url) {
                            filename = newName
                            if let fileURL = audioFileURL(for: newName) { vm.load(url: fileURL) }
                        }
                    }
                }
                #endif
            }
        }
        .padding(.horizontal).padding(.bottom, 16)
        .onAppear {
            if let url = audioFileURL(for: filename) { vm.load(url: url) }
        }
        .onDisappear { vm.stop() }
    }

    private func timeString(_ t: TimeInterval) -> String {
        let total = Int(max(0, t))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    #if os(macOS)
    private func relinkMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.message = "음성 파일을 다시 선택해주세요"
        if panel.runModal() == .OK, let url = panel.url {
            if let newName = copyAudioToDocuments(from: url) {
                filename = newName
                if let fileURL = audioFileURL(for: newName) { vm.load(url: fileURL) }
            }
        }
    }
    #endif
}

// MARK: - 멘토링 세션 상세 열람 (요약 편집 + 전사 리더)

struct MentoringSessionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var session: MentoringSession

    @State private var showingTranscriptReader = false
    @State private var transcriptCopied = false
    @State private var isEditingSummary = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // 날짜
                    Text(session.date.formatted(date: .complete, time: .omitted))
                        .font(.body).foregroundStyle(.secondary)
                        .padding(.horizontal).padding(.top, 16).padding(.bottom, 4)

                    // ── 요약 패널 ──
                    detailPanel(
                        icon: "text.badge.checkmark",
                        title: "요약",
                        color: .orange,
                        trailing: {
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingSummary.toggle()
                                    if !isEditingSummary { try? context.save() }
                                }
                            } label: {
                                Text(isEditingSummary ? "완료" : "편집")
                                    .font(.body)
                                    .foregroundStyle(.orange)
                            }
                            .buttonStyle(.plain)
                        }
                    ) {
                        Group {
                            if isEditingSummary {
                                // 편집 모드: 원문 텍스트 에디터
                                ZStack(alignment: .topLeading) {
                                    if session.summary.isEmpty {
                                        Text("이 세션의 핵심 내용을 요약해보세요\n마크다운 사용 가능 (**굵게**, *기울임*, - 목록 등)")
                                            .font(.body).foregroundStyle(.secondary.opacity(0.55))
                                            .padding(.top, 8).padding(.leading, 5)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $session.summary)
                                        .font(.body)
                                        .frame(minHeight: 140, maxHeight: 320)
                                        .scrollContentBackground(.hidden)
                                }
                            } else {
                                // 뷰 모드: 마크다운 렌더링
                                if session.summary.isEmpty {
                                    Button { withAnimation { isEditingSummary = true } } label: {
                                        Label("요약 작성하기", systemImage: "plus")
                                            .font(.body).foregroundStyle(.orange)
                                    }
                                    .buttonStyle(.plain)
                                } else {
                                    renderedSummary(session.summary)
                                        .font(.body).lineSpacing(4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 16)
                    }

                    sectionDivider

                    // ── 음성 파일 패널 ──
                    if !session.audioFileName.isEmpty {
                        detailPanel(icon: "waveform.circle.fill", title: "음성 파일", color: .purple) {
                            AudioPlayerView(filename: $session.audioFileName)
                        }
                        sectionDivider
                    }

                    // ── Numbers 링크 패널 ──
                    if let urlString = session.numbersURL {
                        detailPanel(icon: "tablecells.fill", title: "Numbers", color: .green) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(urlString)
                                    .font(.body).foregroundStyle(.secondary)
                                    .lineLimit(2).truncationMode(.middle)
                                if let url = URL(string: urlString) {
                                    Link(destination: url) {
                                        Label("Numbers에서 열기", systemImage: "arrow.up.right.square")
                                            .font(.body)
                                            .padding(.horizontal, 14).padding(.vertical, 8)
                                            .background(Color.green.opacity(0.12))
                                            .foregroundStyle(.green).cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal).padding(.bottom, 16)
                        }
                        sectionDivider
                    }

                    // ── 전사 텍스트 패널 ──
                    detailPanel(icon: "text.quote", title: "전사 텍스트", color: .blue, trailing: {
                        HStack(spacing: 12) {
                            if !session.transcript.isEmpty {
                                // 리더 모드 열기
                                Button {
                                    showingTranscriptReader = true
                                } label: {
                                    Label("리더 모드", systemImage: "book.pages")
                                        .font(.body).foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)

                                // 전체 복사
                                Button { copyTranscript() } label: {
                                    Label(
                                        transcriptCopied ? "복사됨" : "복사",
                                        systemImage: transcriptCopied ? "checkmark" : "doc.on.doc"
                                    )
                                    .font(.body).foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }) {
                        if session.transcript.isEmpty {
                            Text("전사 텍스트가 없습니다")
                                .font(.body).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 32).padding(.horizontal)
                        } else {
                            // 미리보기 (앞 300자) + 전체 보기 버튼
                            VStack(alignment: .leading, spacing: 10) {
                                Text(session.transcript.prefix(300) + (session.transcript.count > 300 ? "…" : ""))
                                    .font(.body).lineSpacing(5)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if session.transcript.count > 300 {
                                    Button {
                                        showingTranscriptReader = true
                                    } label: {
                                        Text("전체 \(session.transcript.count)자 보기 →")
                                            .font(.body).foregroundStyle(.blue)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal).padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationTitle(session.title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("닫기") { dismiss() }
                }
            }
            .sheet(isPresented: $showingTranscriptReader) {
                TranscriptReaderSheet(transcript: session.transcript, title: session.title)
            }
        }
        #if os(macOS)
        .frame(width: 600, height: 700)
        #endif
    }

    @ViewBuilder
    private func renderedSummary(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                if line.isEmpty {
                    Spacer().frame(height: 6)
                } else if let attr = try? AttributedString(markdown: line) {
                    Text(attr).font(.body)
                } else {
                    Text(line).font(.body)
                }
            }
        }
    }

    private func detailPanel<Content: View, Trailing: View>(
        icon: String, title: String, color: Color,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Text(title).font(.headline)
                Spacer()
                trailing()
            }
            .padding(.horizontal).padding(.top, 16)
            content()
        }
    }

    private var sectionDivider: some View {
        Divider().padding(.horizontal).padding(.vertical, 4)
    }

    private func copyTranscript() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(session.transcript, forType: .string)
        #else
        UIPasteboard.general.string = session.transcript
        #endif
        transcriptCopied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            transcriptCopied = false
        }
    }
}

// MARK: - 전사 텍스트 리더 (몰입형 읽기)

struct TranscriptReaderSheet: View {
    @Environment(\.dismiss) private var dismiss

    let transcript: String
    let title: String

    @State private var fontSize: CGFloat = 16
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(transcript)
                    .font(.system(size: fontSize))
                    .lineSpacing(fontSize * 0.5)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }

                ToolbarItemGroup(placement: .primaryAction) {
                    // 글자 크기 조절
                    Menu {
                        ForEach([13, 15, 16, 18, 20, 22, 24], id: \.self) { size in
                            Button {
                                fontSize = CGFloat(size)
                            } label: {
                                HStack {
                                    Text("\(size)pt")
                                    if fontSize == CGFloat(size) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Label("글자 크기", systemImage: "textformat.size")
                    }

                    // 전체 복사
                    Button { copyAll() } label: {
                        Label(copied ? "복사됨" : "전체 복사",
                              systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 660, height: 740)
        #endif
    }

    private func copyAll() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(transcript, forType: .string)
        #else
        UIPasteboard.general.string = transcript
        #endif
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}
