//
//  MeetingWorkflowGuideView.swift
//  RapportMap
//
//  멘토링 분석 워크플로우 단계별 가이드
//

import SwiftUI
import SwiftData

struct MeetingWorkflowGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var meetingRecord: MeetingRecord
    let person: Person

    @State private var currentInput = ""
    @State private var showingApplyConfirmation = false
    @State private var showingShareSheet = false
    @State private var fileToShare: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 진행 상황 표시
                    progressIndicator

                    // 현재 단계 카드
                    currentStepCard

                    // 입력 영역 (단계에 따라 다름)
                    inputSection

                    // 액션 버튼
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("멘토링 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
            .alert("기록에 적용하시겠습니까?", isPresented: $showingApplyConfirmation) {
                Button("취소", role: .cancel) { }
                Button("적용") {
                    applyToPersonRecords()
                }
            } message: {
                Text("추출된 약속과 액션아이템을 \(person.name)님의 기록에 추가합니다.")
            }
        }
    }

    // MARK: - 진행 상황 표시

    private var progressIndicator: some View {
        VStack(spacing: 16) {
            // 단계 표시
            HStack(spacing: 0) {
                ForEach(1...6, id: \.self) { step in
                    HStack(spacing: 0) {
                        // 단계 원
                        ZStack {
                            Circle()
                                .fill(stepColor(for: step))
                                .frame(width: 40, height: 40)

                            if step <= meetingRecord.workflowStatus.stepNumber {
                                Image(systemName: step < meetingRecord.workflowStatus.stepNumber ? "checkmark" : "\(step).circle.fill")
                                    .foregroundStyle(.white)
                                    .font(.system(size: step < meetingRecord.workflowStatus.stepNumber ? 16 : 20))
                            } else {
                                Text("\(step)")
                                    .foregroundStyle(.white)
                                    .font(.caption)
                                    .fontWeight(.bold)
                            }
                        }

                        // 연결선 (마지막 단계가 아니면)
                        if step < 6 {
                            Rectangle()
                                .fill(step < meetingRecord.workflowStatus.stepNumber ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
            }

            // 현재 단계 텍스트
            Text("\(meetingRecord.workflowStatus.emoji) \(meetingRecord.workflowStatus.displayText)")
                .font(.headline)
                .foregroundStyle(.blue)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func stepColor(for step: Int) -> Color {
        if step < meetingRecord.workflowStatus.stepNumber {
            return .blue
        } else if step == meetingRecord.workflowStatus.stepNumber {
            return .orange
        } else {
            return .gray.opacity(0.3)
        }
    }

    // MARK: - 현재 단계 카드

    private var currentStepCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("다음 할 일")
                    .font(.headline)
            }

            Text(meetingRecord.workflowStatus.instruction)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange, lineWidth: 2)
        )
    }

    // MARK: - 입력 섹션

    @ViewBuilder
    private var inputSection: some View {
        switch meetingRecord.workflowStatus {
        case .recorded:
            audioFileSection
        case .needsTranscription:
            transcriptionInputSection
        case .needsDiarization:
            diarizationInputSection
        case .needsExtraction:
            extractionInputSection
        case .needsReview:
            reviewSection
        case .completed:
            completedSection
        }
    }

    // 1단계: 오디오 파일
    private var audioFileSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("녹음 파일", systemImage: "waveform")
                .font(.headline)

            if let audioURL = meetingRecord.audioFileURL {
                HStack {
                    Image(systemName: "music.note")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading) {
                        Text("녹음 완료")
                            .font(.subheadline)
                        Text("길이: \(meetingRecord.formattedDuration)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button {
                        // 파일 공유
                        if let url = URL(string: audioURL) {
                            fileToShare = url
                            showingShareSheet = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title3)
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }

            Text("💡 이 파일을 네이버 Clova Speech에 업로드하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // 2단계: STT 결과 입력
    private var transcriptionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("STT 결과 붙여넣기", systemImage: "doc.text")
                .font(.headline)

            TextEditor(text: $currentInput)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )

            if !currentInput.isEmpty {
                Text("\(currentInput.count) 자")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // 3단계: 화자 분리 결과 입력
    private var diarizationInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("화자 분리 결과 붙여넣기", systemImage: "person.2")
                .font(.headline)

            // 이전 단계 결과 표시
            if let transcription = meetingRecord.transcriptionText {
                VStack(alignment: .leading, spacing: 8) {
                    Text("이전 단계 (STT 결과)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        copyToClipboard(transcription)
                    } label: {
                        HStack {
                            Text(transcription)
                                .font(.caption)
                                .lineLimit(3)
                            Spacer()
                            Image(systemName: "doc.on.doc")
                                .foregroundStyle(.blue)
                        }
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 8)
            }

            TextEditor(text: $currentInput)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.green, lineWidth: 1)
                )

            Text("예시: [멘토] 안녕하세요\\n[멘티] 안녕하세요")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // 4단계: Claude 추출 결과 입력
    private var extractionInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Claude 추출 결과 붙여넣기", systemImage: "sparkles")
                .font(.headline)

            // 프롬프트 템플릿
            VStack(alignment: .leading, spacing: 8) {
                Text("Claude에게 이렇게 물어보세요:")
                    .font(.caption)
                    .fontWeight(.semibold)

                Button {
                    copyClaudePrompt()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("다음 멘토링 대화에서:")
                                .font(.caption)
                            Text("1. 멘토가 한 약속")
                                .font(.caption)
                            Text("2. 멘티가 한 약속")
                                .font(.caption)
                            Text("3. 액션 아이템")
                                .font(.caption)
                            Text("4. 일정")
                                .font(.caption)
                            Text("을 JSON으로 추출해줘")
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "doc.on.doc")
                            .foregroundStyle(.purple)
                    }
                    .padding(12)
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 8)

            TextEditor(text: $currentInput)
                .frame(minHeight: 200)
                .padding(8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 1)
                )
        }
    }

    // 5단계: 검토
    private var reviewSection: some View {
        VStack(spacing: 16) {
            if !meetingRecord.mentorPromises.isEmpty {
                promisesSection(
                    title: "멘토가 한 약속",
                    promises: meetingRecord.mentorPromises,
                    color: .blue
                )
            }

            if !meetingRecord.menteePromises.isEmpty {
                promisesSection(
                    title: "멘티가 한 약속",
                    promises: meetingRecord.menteePromises,
                    color: .green
                )
            }

            if !meetingRecord.actionItems.isEmpty {
                actionItemsSection
            }

            if !meetingRecord.scheduledEvents.isEmpty {
                scheduledEventsSection
            }
        }
    }

    private func promisesSection(title: String, promises: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: "hand.raised.fill")
                .font(.headline)
                .foregroundStyle(color)

            VStack(spacing: 8) {
                ForEach(Array(promises.enumerated()), id: \.offset) { index, promise in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(color)

                        Text(promise)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var actionItemsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("액션 아이템", systemImage: "checklist")
                .font(.headline)
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                ForEach(Array(meetingRecord.actionItems.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "square")
                            .foregroundStyle(.purple)

                        Text(item)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.purple.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    private var scheduledEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("일정", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(.red)

            VStack(spacing: 8) {
                ForEach(Array(meetingRecord.scheduledEvents.enumerated()), id: \.offset) { index, event in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.red)

                        Text(event)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }

    // 완료
    private var completedSection: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("워크플로우 완료!")
                .font(.title2)
                .fontWeight(.bold)

            if let completedDate = meetingRecord.workflowCompletedDate {
                Text("완료 시간: \(completedDate.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - 액션 버튼

    @ViewBuilder
    private var actionButtons: some View {
        if meetingRecord.workflowStatus != .completed {
            VStack(spacing: 12) {
                // 다음 단계 버튼
                Button {
                    proceedToNextStep()
                } label: {
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                        Text(buttonText)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canProceed ? Color.blue : Color.gray)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
                }
                .disabled(!canProceed)

                // 이전 단계 버튼
                if meetingRecord.workflowStatus.stepNumber > 1 {
                    Button {
                        goBackToPreviousStep()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.left")
                            Text("이전 단계로")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private var buttonText: String {
        switch meetingRecord.workflowStatus {
        case .recorded: return "STT 단계로"
        case .needsTranscription: return "결과 저장하고 다음"
        case .needsDiarization: return "결과 저장하고 다음"
        case .needsExtraction: return "추출 결과 저장"
        case .needsReview: return "기록에 적용"
        case .completed: return "완료"
        }
    }

    private var canProceed: Bool {
        switch meetingRecord.workflowStatus {
        case .recorded: return true
        case .needsTranscription, .needsDiarization, .needsExtraction:
            return !currentInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .needsReview:
            return !meetingRecord.mentorPromises.isEmpty || !meetingRecord.menteePromises.isEmpty
        case .completed: return false
        }
    }

    // MARK: - 헬퍼 메서드

    private func proceedToNextStep() {
        switch meetingRecord.workflowStatus {
        case .recorded:
            meetingRecord.workflowStatus = .needsTranscription
        case .needsTranscription:
            meetingRecord.transcriptionText = currentInput
            currentInput = ""
            meetingRecord.workflowStatus = .needsDiarization
        case .needsDiarization:
            meetingRecord.diarizedText = currentInput
            currentInput = ""
            meetingRecord.workflowStatus = .needsExtraction
        case .needsExtraction:
            parseExtractedData(currentInput)
            currentInput = ""
            meetingRecord.workflowStatus = .needsReview
        case .needsReview:
            showingApplyConfirmation = true
        case .completed:
            break
        }

        try? context.save()
    }

    private func goBackToPreviousStep() {
        switch meetingRecord.workflowStatus {
        case .needsTranscription:
            meetingRecord.workflowStatus = .recorded
        case .needsDiarization:
            meetingRecord.workflowStatus = .needsTranscription
            currentInput = meetingRecord.transcriptionText ?? ""
        case .needsExtraction:
            meetingRecord.workflowStatus = .needsDiarization
            currentInput = meetingRecord.diarizedText ?? ""
        case .needsReview:
            meetingRecord.workflowStatus = .needsExtraction
        default:
            break
        }

        try? context.save()
    }

    private func parseExtractedData(_ jsonString: String) {
        // JSON 파싱 시도
        let cleanedJSON = jsonString
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleanedJSON.data(using: .utf8) else { return }

        do {
            let result = try JSONDecoder().decode(MeetingAnalysisResult.self, from: data)
            meetingRecord.mentorPromises = result.mentorPromises.map { $0.content }
            meetingRecord.menteePromises = result.menteePromises.map { $0.content }
            meetingRecord.actionItems = result.actionItems.map { $0.content }
            meetingRecord.scheduledEvents = result.scheduledEvents.map { "\($0.title) - \($0.date)" }
            meetingRecord.extractedData = cleanedJSON
        } catch {
            print("❌ JSON 파싱 실패: \(error)")
            // 파싱 실패 시 원본 저장
            meetingRecord.extractedData = cleanedJSON
        }
    }

    private func applyToPersonRecords() {
        // ConversationRecord로 저장
        for promise in meetingRecord.mentorPromises {
            let record = person.addConversationRecord(
                type: .promise,
                content: "[멘토] \(promise)",
                priority: .normal,
                isImportant: true,
                date: meetingRecord.date
            )
            context.insert(record)
        }

        for promise in meetingRecord.menteePromises {
            let record = person.addConversationRecord(
                type: .promise,
                content: "[멘티] \(promise)",
                priority: .high,
                isImportant: true,
                date: meetingRecord.date
            )
            context.insert(record)
        }

        meetingRecord.workflowStatus = .completed
        meetingRecord.workflowCompletedDate = Date()

        try? context.save()

        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            dismiss()
        }
    }

    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }

    private func copyClaudePrompt() {
        let prompt = """
        다음 멘토링 대화를 분석해서 JSON으로 추출해줘:

        1. mentorPromises: 멘토가 한 약속들
        2. menteePromises: 멘티가 한 약속들
        3. actionItems: 액션 아이템들
        4. scheduledEvents: 일정들

        대화 내용:
        \(meetingRecord.diarizedText ?? "")
        """

        copyToClipboard(prompt)
    }
}

// MARK: - Analysis Result Types

struct MeetingAnalysisResult: Codable {
    let mentorPromises: [PromiseItem]
    let menteePromises: [PromiseItem]
    let actionItems: [ActionItem]
    let scheduledEvents: [ScheduledEvent]
    let summary: String?
}

struct PromiseItem: Codable {
    let content: String
    let speaker: String
    let priority: String?
}

struct ActionItem: Codable {
    let content: String
    let assignee: String
    let deadline: String?
}

struct ScheduledEvent: Codable {
    let title: String
    let date: String
    let description: String?
}
