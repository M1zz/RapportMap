import Foundation
import SwiftData
import SwiftUI

// MARK: - ⚠️ DEPRECATED
// 이 모델은 Record.swift의 통합 Record 모델로 대체되었습니다.
// 기존 데이터 호환성을 위해 유지되며, DataSeeder.migrateToUnifiedRecords()를 통해
// 데이터가 Record 모델로 마이그레이션됩니다.
// 향후 버전에서 삭제될 예정입니다.

/// 대화/상태 기록을 관리하는 모델
/// 질문, 고민, 약속 등의 대화 내용과 상태를 구조화하여 저장
@Model
final class ConversationRecord {
    // MARK: - 기본 정보
    var id: UUID                        // 고유 식별자
    var createdDate: Date               // 대화/상태 기록 생성 날짜
    var date: Date                      // 대화/상태 발생 날짜 (실제 대화 날짜)
    var resolvedDate: Date?             // 해결 날짜 (해결되었을 때의 날짜)
    var type: ConversationType          // 대화 타입 (질문, 고민, 약속 등)
    var content: String                 // 대화 내용 또는 상태 정보
    var notes: String?                  // 추가 메모
    var isResolved: Bool                // 해결 여부 (질문 답변, 약속 이행 등)
    var isImportant: Bool               // 중요한 기록 여부 (놓치면 안되는 것들에 표시)
    var priority: ConversationPriority  // 우선순위

    @Attribute
    var tags: [String] = []             // 태그들 (검색이나 분류용)

    /// 첨부된 이미지 데이터 (여러 장 가능)
    @Attribute(.externalStorage)
    var imageDataArray: [Data]?

    // MARK: - 관계형 데이터
    /// 이 대화가 속한 사람
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    // MARK: - 초기화
    /// ConversationRecord 객체 생성자
    init(
        id: UUID = UUID(),
        createdDate: Date = Date(),
        date: Date = Date(),
        resolvedDate: Date? = nil,
        type: ConversationType,
        content: String,
        notes: String? = nil,
        isResolved: Bool = false,
        isImportant: Bool = false,
        priority: ConversationPriority = .normal,
        tags: [String] = [],
        imageDataArray: [Data]? = nil
    ) {
        self.id = id
        self.createdDate = createdDate
        self.date = date
        self.resolvedDate = resolvedDate
        self.type = type
        self.content = content
        self.notes = notes
        self.isResolved = isResolved
        self.isImportant = isImportant
        self.priority = priority
        self.tags = tags
        self.imageDataArray = imageDataArray
    }
}

/// 대화/상태 타입을 정의하는 열거형
enum ConversationType: String, Codable, CaseIterable, Hashable {
    case question = "question"          // 받은 질문
    case concern = "concern"           // 고민 상담
    case promise = "promise"           // 약속
    case update = "update"             // 근황 업데이트
    case feedback = "feedback"         // 피드백
    case achievement = "achievement"    // 성취나 좋은 소식
    
    /// 타입별 한국어 이름
    var title: String {
        switch self {
        case .question: return "질문"
        case .concern: return "고민"
        case .promise: return "약속"
        case .update: return "근황"
        case .feedback: return "피드백"
        case .achievement: return "성취"
        }
    }
    
    /// 타입별 이모지
    var emoji: String {
        switch self {
        case .question: return "❓"
        case .concern: return "😰"
        case .promise: return "🤝"
        case .update: return "📰"
        case .feedback: return "💭"
        case .achievement: return "🎉"
        }
    }
    
    /// 타입별 SF Symbol
    var systemImage: String {
        switch self {
        case .question: return "questionmark.circle"
        case .concern: return "person.badge.minus"
        case .promise: return "hand.raised"
        case .update: return "newspaper"
        case .feedback: return "bubble.left.and.bubble.right"
        case .achievement: return "star.circle"
        }
    }
    
    /// 타입별 색상
    var color: Color {
        switch self {
        case .question: return .blue
        case .concern: return .orange
        case .promise: return .green
        case .update: return .purple
        case .feedback: return .pink
        case .achievement: return .yellow
        }
    }
}

/// 대화/상태 우선순위
enum ConversationPriority: String, Codable, CaseIterable {
    case low = "low"
    case normal = "normal"
    case high = "high"
    case urgent = "urgent"
    
    var title: String {
        switch self {
        case .low: return "낮음"
        case .normal: return "보통"
        case .high: return "높음"
        case .urgent: return "긴급"
        }
    }
    
    var emoji: String {
        switch self {
        case .low: return "🔵"
        case .normal: return "⚪"
        case .high: return "🟡"
        case .urgent: return "🔴"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .blue
        case .normal: return .gray
        case .high: return .orange
        case .urgent: return .red
        }
    }
    
    /// 정렬용 숫자 값
    var sortOrder: Int {
        switch self {
        case .urgent: return 3
        case .high: return 2
        case .normal: return 1
        case .low: return 0
        }
    }
}

// MARK: - ConversationRecord 확장
extension ConversationRecord {
    /// 상대적 날짜 표시 (예: "3일 전", "방금 전")
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdDate, relativeTo: .now)
    }
    
    /// 최근 기록인지 여부 (7일 이내)
    var isRecent: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
        return daysSince <= 7
    }
    
    /// 오래된 기록인지 여부 (30일 이상)
    var isOld: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: createdDate, to: Date()).day ?? 0
        return daysSince >= 30
    }
    
    /// 표시용 제목 (타입 + 내용 일부)
    var displayTitle: String {
        let prefix = "\(type.emoji) \(type.title)"
        let maxLength = 30
        
        if content.count <= maxLength {
            return "\(prefix): \(content)"
        } else {
            let truncated = String(content.prefix(maxLength))
            return "\(prefix): \(truncated)..."
        }
    }
    
    /// 상태 표시용 라벨
    var statusLabel: String {
        if isResolved {
            return "✅ 해결됨"
        } else {
            switch priority {
            case .urgent:
                return "🔴 긴급"
            case .high:
                return "🟡 높음"
            default:
                return "⏳ 진행중"
            }
        }
    }
    
    /// 내용이 비어있지 않은지 확인
    var hasContent: Bool {
        return !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    /// 태그 문자열 (쉼표로 구분)
    var tagsString: String {
        return tags.joined(separator: ", ")
    }
    
    /// 문자열에서 태그 배열로 변환
    func setTags(from string: String) {
        let tagArray = string
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        self.tags = tagArray
    }
}
