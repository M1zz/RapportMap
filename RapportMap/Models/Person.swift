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
    
    // 상호작용 노트
    var mentoringNotes: String?  // 멘토링 관련 메모
    var mealNotes: String?      // 식사 관련 메모
    var contactNotes: String?   // 연락 관련 메모
    
    // 대화 컨텍스트
    var recentConcerns: String?     // 최근의 고민
    var receivedQuestions: String?  // 받았던 질문
    var unresolvedPromises: String? // 미해결된 약속
    
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
        background: String = "",
        mentoringNotes: String? = nil,
        mealNotes: String? = nil,
        contactNotes: String? = nil,
        recentConcerns: String? = nil,
        receivedQuestions: String? = nil,
        unresolvedPromises: String? = nil
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
        self.mentoringNotes = mentoringNotes
        self.mealNotes = mealNotes
        self.contactNotes = contactNotes
        self.recentConcerns = recentConcerns
        self.receivedQuestions = receivedQuestions
        self.unresolvedPromises = unresolvedPromises
    }
}

enum RelationshipState: String, Codable, CaseIterable {
    case distant = "distant"
    case warming = "warming"
    case close = "close"
    
    var emoji: String {
        switch self {
        case .distant: return "😐"
        case .warming: return "🙂"
        case .close: return "😊"
        }
    }
    
    var localizedName: String {
        switch self {
        case .distant: return "멀어짐"
        case .warming: return "따뜻해지는 중"
        case .close: return "끈끈함"
        }
    }
    
    var description: String {
        switch self {
        case .distant:
            return "관계가 소홀해진 상태예요. 연락을 늘려보세요"
        case .warming:
            return "관계가 발전하고 있어요. 꾸준히 관리해보세요"
        case .close:
            return "좋은 관계를 유지하고 있어요!"
        }
    }
    
    var color: String {
        switch self {
        case .distant: return "#FF6B6B"
        case .warming: return "#FFD93D"
        case .close: return "#6BCF7F"
        }
    }
}

// MARK: - 관계 상태 자동 계산
extension Person {
    
    /// 현재 관계 상태를 자동으로 계산하여 반환
    func calculateRelationshipState() -> RelationshipState {
        let score = calculateRelationshipScore()
        
        // 점수 기반으로 관계 상태 결정
        switch score {
        case 70...: 
            return .close
        case 40..<70: 
            return .warming
        default: 
            return .distant
        }
    }
    
    /// 관계 점수 계산 (0-100)
    func calculateRelationshipScore() -> Double {
        var totalScore: Double = 30 // 기본 점수
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 시간 경과에 따른 감점 (가장 중요한 요소)
        let timeDecayScore = calculateTimeDecayScore()
        totalScore += timeDecayScore
        
        // 2. 액션 완료도 점수 (0-25점)
        let actionScore = calculateActionCompletionScore()
        totalScore += actionScore
        
        // 3. 상호작용 빈도 점수 (0-20점)
        let interactionScore = calculateInteractionFrequencyScore()
        totalScore += interactionScore
        
        // 4. 미해결 대화 감점 (최대 -15점)
        let unsolvedPenalty = min(Double(unansweredCount) * 3, 15)
        totalScore -= unsolvedPenalty
        
        // 5. 소홀함 플래그 감점 (-10점)
        if isNeglected {
            totalScore -= 10
        }
        
        // 6. 관계 지속 기간 보너스 (0-10점)
        let relationshipDuration = calendar.dateComponents([.day], from: relationshipStartDate, to: now).day ?? 0
        let durationBonus = min(Double(relationshipDuration) / 30.0 * 10, 10) // 30일당 최대 10점
        totalScore += durationBonus
        
        return max(0, min(100, totalScore))
    }
    
    /// 시간 경과에 따른 점수 계산 (-30 ~ +15점)
    private func calculateTimeDecayScore() -> Double {
        let now = Date()
        let calendar = Calendar.current
        
        // 가장 최근 상호작용 날짜 찾기
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        // 시간 경과에 따른 점수 (exponential decay)
        switch daysSinceLastInteraction {
        case 0...1:
            return 15 // 최근 1일 이내: 보너스
        case 2...3:
            return 10 // 2-3일: 좋음
        case 4...7:
            return 5  // 4-7일: 보통
        case 8...14:
            return 0  // 1-2주: 중립
        case 15...30:
            return -10 // 2-4주: 감점 시작
        case 31...60:
            return -20 // 1-2달: 큰 감점
        default:
            return -30 // 2달 이상: 최대 감점
        }
    }
    
    /// 액션 완료도 점수 계산 (0-25점)
    private func calculateActionCompletionScore() -> Double {
        let totalActions = actions.count
        guard totalActions > 0 else { return 0 }
        
        let completedActions = actions.filter { $0.isCompleted }.count
        let completionRate = Double(completedActions) / Double(totalActions)
        
        // Critical 액션 완료도는 더 높은 가중치
        let criticalActions = actions.filter { $0.action?.type == .critical }
        let completedCriticalActions = criticalActions.filter { $0.isCompleted }
        
        let criticalBonus = criticalActions.isEmpty ? 0 : 
            Double(completedCriticalActions.count) / Double(criticalActions.count) * 10
        
        return completionRate * 15 + criticalBonus
    }
    
    /// 상호작용 빈도 점수 계산 (0-20점)
    private func calculateInteractionFrequencyScore() -> Double {
        let now = Date()
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        var interactionCount = 0
        
        // 최근 30일 내 상호작용 카운트
        [lastContact, lastMeal, lastMentoring].forEach { date in
            if let date = date, date >= thirtyDaysAgo {
                interactionCount += 1
            }
        }
        
        // 만남 기록도 카운트
        let recentMeetings = meetingRecords.filter { $0.date >= thirtyDaysAgo }.count
        interactionCount += recentMeetings
        
        // 빈도에 따른 점수
        switch interactionCount {
        case 8...: return 20
        case 5...7: return 15
        case 3...4: return 10
        case 1...2: return 5
        default: return 0
        }
    }
    
    /// 관계 상태를 자동으로 업데이트
    func updateRelationshipState() {
        let calculatedState = calculateRelationshipState()
        
        // 상태가 변경된 경우에만 업데이트
        if state != calculatedState {
            let oldState = state
            state = calculatedState
            
            print("🔄 [RelationshipState] \(name)님과의 관계 상태 변경: \(oldState.rawValue) → \(calculatedState.rawValue)")
            
            // 관계가 악화된 경우 소홀함 플래그 설정
            if calculatedState == .distant && oldState != .distant {
                isNeglected = true
                print("⚠️ [RelationshipState] \(name)님과의 관계가 소홀해졌습니다")
            }
            // 관계가 개선된 경우 소홀함 플래그 해제
            else if calculatedState != .distant && isNeglected {
                isNeglected = false
                print("✅ [RelationshipState] \(name)님과의 관계가 개선되었습니다")
            }
        }
    }
    
    /// 관계 상태에 대한 상세 정보 반환
    func getRelationshipAnalysis() -> RelationshipAnalysis {
        let score = calculateRelationshipScore()
        let now = Date()
        let calendar = Calendar.current
        
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        return RelationshipAnalysis(
            currentScore: score,
            currentState: calculateRelationshipState(),
            daysSinceLastInteraction: daysSinceLastInteraction,
            actionCompletionRate: calculateActionCompletionRate(),
            criticalActionCompletionRate: calculateCriticalActionCompletionRate(),
            recommendations: generateRecommendations()
        )
    }
    
    private func calculateActionCompletionRate() -> Double {
        guard !actions.isEmpty else { return 0 }
        let completed = actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(actions.count)
    }
    
    private func calculateCriticalActionCompletionRate() -> Double {
        let criticalActions = actions.filter { $0.action?.type == .critical }
        guard !criticalActions.isEmpty else { return 0 }
        let completed = criticalActions.filter { $0.isCompleted }.count
        return Double(completed) / Double(criticalActions.count)
    }
    
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        let now = Date()
        let calendar = Calendar.current
        
        // 최근 상호작용 확인
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        // 시간 기반 추천
        if daysSinceLastInteraction > 14 {
            recommendations.append("🚨 2주 이상 연락이 없었어요. 안부 인사를 보내보세요")
        } else if daysSinceLastInteraction > 7 {
            recommendations.append("📱 일주일이 지났어요. 가벼운 연락을 해보세요")
        }
        
        // 액션 기반 추천
        let incompleteCritical = actions.filter { $0.action?.type == .critical && !$0.isCompleted }.count
        if incompleteCritical > 0 {
            recommendations.append("⚠️ 중요한 액션 \(incompleteCritical)개가 미완료입니다")
        }
        
        // 미해결 대화 추천
        if unansweredCount > 2 {
            recommendations.append("💬 미해결 대화가 많아요. 답변을 해보세요")
        }
        
        // 식사/만남 추천
        if let lastMeal = lastMeal {
            let daysSinceMeal = calendar.dateComponents([.day], from: lastMeal, to: now).day ?? 0
            if daysSinceMeal > 30 {
                recommendations.append("🍽️ 함께 식사한 지 한 달이 넘었어요")
            }
        } else {
            recommendations.append("🍽️ 아직 함께 식사해본 적이 없어요")
        }
        
        return recommendations
    }
}

struct RelationshipAnalysis {
    let currentScore: Double
    let currentState: RelationshipState
    let daysSinceLastInteraction: Int
    let actionCompletionRate: Double
    let criticalActionCompletionRate: Double
    let recommendations: [String]
}
