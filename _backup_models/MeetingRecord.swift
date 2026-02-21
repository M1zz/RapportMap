//
//  MeetingRecord.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation
import SwiftData

// MARK: - ⚠️ DEPRECATED
// 이 모델은 Record.swift의 통합 Record 모델로 대체되었습니다.
// 기존 데이터 호환성을 위해 유지되며, DataSeeder.migrateToUnifiedRecords()를 통해
// 데이터가 Record 모델로 마이그레이션됩니다.
// 향후 버전에서 삭제될 예정입니다.

@Model
final class MeetingRecord {
    var id: UUID
    var date: Date
    var meetingType: MeetingType
    var audioFileURL: String?  // 음성 파일 경로
    var transcribedText: String  // 음성 → 텍스트 변환 결과
    var summary: String  // 요약
    var duration: TimeInterval  // 녹음 길이
    var isImportant: Bool = false // 중요도 표시

    // 수동 분석 워크플로우
    var workflowStatus: WorkflowStatus  // 현재 워크플로우 단계
    var transcriptionText: String?  // STT 결과 텍스트 (복사-붙여넣기)
    var diarizedText: String?  // 화자 분리된 텍스트 (복사-붙여넣기)
    var extractedData: String?  // Claude에서 추출한 결과 (복사-붙여넣기)

    @Attribute
    var mentorPromises: [String] = []  // 멘토가 한 약속들

    @Attribute
    var menteePromises: [String] = []  // 멘티가 한 약속들

    @Attribute
    var actionItems: [String] = []  // 액션 아이템들

    @Attribute
    var scheduledEvents: [String] = []  // 일정들

    var workflowCompletedDate: Date?  // 워크플로우 완료 날짜

    // 관계
    var person: Person?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        meetingType: MeetingType = .mentoring,
        audioFileURL: String? = nil,
        transcribedText: String = "",
        summary: String = "",
        duration: TimeInterval = 0,
        isImportant: Bool = false
    ) {
        self.id = id
        self.date = date
        self.meetingType = meetingType
        self.audioFileURL = audioFileURL
        self.transcribedText = transcribedText
        self.summary = summary
        self.duration = duration
        self.isImportant = isImportant
        self.workflowStatus = .recorded
    }
}

// MARK: - Helpers
extension MeetingRecord {
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var hasAudio: Bool {
        audioFileURL != nil
    }
}

enum MeetingType: String, Codable, CaseIterable {
    case mentoring = "멘토링"
    case meal = "식사"
    case coffee = "커피"
    case general = "일반 대화"
    case presentation = "발표/회의"
    case oneOnOne = "1:1 미팅"

    var emoji: String {
        switch self {
        case .mentoring: return "🧑‍🏫"
        case .meal: return "🍱"
        case .coffee: return "☕️"
        case .general: return "💬"
        case .presentation: return "📊"
        case .oneOnOne: return "👥"
        }
    }
}

enum WorkflowStatus: String, Codable {
    case recorded = "recorded"  // 1단계: 녹음 완료
    case needsTranscription = "needs_transcription"  // 2단계: STT 필요
    case needsDiarization = "needs_diarization"  // 3단계: 화자 분리 필요
    case needsExtraction = "needs_extraction"  // 4단계: 약속/액션 추출 필요
    case needsReview = "needs_review"  // 5단계: 검토 및 적용 필요
    case completed = "completed"  // 완료

    var stepNumber: Int {
        switch self {
        case .recorded: return 1
        case .needsTranscription: return 2
        case .needsDiarization: return 3
        case .needsExtraction: return 4
        case .needsReview: return 5
        case .completed: return 6
        }
    }

    var displayText: String {
        switch self {
        case .recorded: return "녹음 완료"
        case .needsTranscription: return "STT 필요"
        case .needsDiarization: return "화자 분리 필요"
        case .needsExtraction: return "내용 추출 필요"
        case .needsReview: return "검토 필요"
        case .completed: return "완료"
        }
    }

    var emoji: String {
        switch self {
        case .recorded: return "🎙️"
        case .needsTranscription: return "📝"
        case .needsDiarization: return "👥"
        case .needsExtraction: return "🤖"
        case .needsReview: return "✅"
        case .completed: return "🎉"
        }
    }

    var nextStep: WorkflowStatus? {
        switch self {
        case .recorded: return .needsTranscription
        case .needsTranscription: return .needsDiarization
        case .needsDiarization: return .needsExtraction
        case .needsExtraction: return .needsReview
        case .needsReview: return .completed
        case .completed: return nil
        }
    }

    var instruction: String {
        switch self {
        case .recorded:
            return """
            다음 단계: 음성을 텍스트로 변환하세요

            1️⃣ 녹음 파일을 네이버 클라우드 Clova Speech로 업로드
            2️⃣ STT 결과를 복사
            3️⃣ 아래 입력란에 붙여넣기
            """
        case .needsTranscription:
            return """
            다음 단계: 화자를 분리하세요

            1️⃣ STT 텍스트를 네이버 클라우드 화자 분리 API로 전송
            2️⃣ 멘토/멘티로 라벨링된 결과를 복사
            3️⃣ 아래 입력란에 붙여넣기

            예시:
            [멘토] 안녕하세요
            [멘티] 안녕하세요
            """
        case .needsDiarization:
            return """
            다음 단계: Claude로 약속과 액션 아이템을 추출하세요

            1️⃣ 화자 분리된 텍스트를 복사
            2️⃣ Claude.ai에 접속하여 프롬프트 입력:

            "다음 멘토링 대화에서 약속, 액션아이템, 일정을 JSON으로 추출해줘"

            3️⃣ Claude 응답 결과를 복사하여 아래에 붙여넣기
            """
        case .needsExtraction:
            return """
            다음 단계: 추출된 내용을 확인하고 적용하세요

            ✅ 멘토 약속
            ✅ 멘티 약속
            ✅ 액션 아이템
            ✅ 일정

            내용이 정확하면 "기록에 적용" 버튼을 눌러주세요
            """
        case .needsReview:
            return "모든 단계가 완료되었습니다!"
        case .completed:
            return "워크플로우 완료! 🎉"
        }
    }
}
