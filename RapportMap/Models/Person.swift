import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID
    var name: String
    var contact: String
    var state: RelationshipState
    var lastMentoring: Date?
    var lastMeal: Date?
    var lastQuestion: String?
    var unansweredCount: Int
    var lastContact: Date?
    var isNeglected: Bool
    
    // 새로 추가된 필드들
    var currentPhase: ActionPhase  // 현재 관계 단계
    var relationshipStartDate: Date  // 관계 시작일
    
    // 개인 컨텍스트 (외장 두뇌!)
    var preferredName: String  // 선호 호칭 (예: "철수", "김 대리")
    var interests: String  // 관심사 (예: "등산, 게임 개발")
    var preferences: String  // 취향/선호 (예: "커피 안 마심, 매운 거 못 먹음")
    var importantDates: String  // 중요한 날짜들 (예: "생일 5/15, 발표 11/20")
    var workStyle: String  // 업무 스타일 (예: "문서 선호, 대면 미팅 싫어함")
    var background: String  // 배경 정보 (예: "서울 출신, 전 직장 네이버")
    
    // 관계
    @Relationship(deleteRule: .cascade, inverse: \PersonAction.person)
    var actions: [PersonAction] = []
    
    @Relationship(deleteRule: .cascade, inverse: \MeetingRecord.person)
    var meetingRecords: [MeetingRecord] = []

    init(
        id: UUID = UUID(),
        name: String,
        contact: String = "",
        state: RelationshipState = .distant,
        lastMentoring: Date? = nil,
        lastMeal: Date? = nil,
        lastQuestion: String? = nil,
        unansweredCount: Int = 0,
        lastContact: Date? = nil,
        isNeglected: Bool = false,
        currentPhase: ActionPhase = .phase1,
        relationshipStartDate: Date = Date(),
        preferredName: String = "",
        interests: String = "",
        preferences: String = "",
        importantDates: String = "",
        workStyle: String = "",
        background: String = ""
    ) {
        self.id = id
        self.name = name
        self.contact = contact
        self.state = state
        self.lastMentoring = lastMentoring
        self.lastMeal = lastMeal
        self.lastQuestion = lastQuestion
        self.unansweredCount = unansweredCount
        self.lastContact = lastContact
        self.isNeglected = isNeglected
        self.currentPhase = currentPhase
        self.relationshipStartDate = relationshipStartDate
        self.preferredName = preferredName
        self.interests = interests
        self.preferences = preferences
        self.importantDates = importantDates
        self.workStyle = workStyle
        self.background = background
    }
}

enum RelationshipState: String, Codable, CaseIterable {
    case distant
    case warming
    case close
}
