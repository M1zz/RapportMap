import Foundation
import SwiftData
import SwiftUI

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
    
    @Relationship(deleteRule: .cascade, inverse: \InteractionRecord.person)
    var interactionRecords: [InteractionRecord] = []
    
    @Relationship(deleteRule: .cascade, inverse: \PersonContext.person)
    var contexts: [PersonContext] = []

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
        currentPhase: ActionPhase = .surface,  // 기본값을 새로운 enum으로 변경
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
    
    var color: Color {
        switch self {
        case .distant: return .blue
        case .warming: return .orange
        case .close: return .pink
        }
    }
}

// MARK: - 관계 상태 자동 계산
extension Person {
    
    /// 현재 관계 상태를 자동으로 계산하여 반환
    func calculateRelationshipState() -> RelationshipState {
        let score = calculateRelationshipScore()
        
        // 점수 기준을 더 관대하게 조정
        switch score {
        case 65...: 
            return .close
        case 35..<65: 
            return .warming
        default: 
            return .distant
        }
    }
    
    /// 관계 점수 계산 (0-100)
    func calculateRelationshipScore() -> Double {
        var totalScore: Double = 40 // 기본 점수를 40으로 상향 (더 관대하게)
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 시간 경과에 따른 감점/가점 (가장 중요한 요소)
        let timeDecayScore = calculateTimeDecayScore()
        totalScore += timeDecayScore
        
        // 2. 액션 완료도 점수 (0-25점)
        let actionScore = calculateActionCompletionScore()
        totalScore += actionScore
        
        // 3. 상호작용 빈도 점수 (0-20점)
        let interactionScore = calculateInteractionFrequencyScore()
        totalScore += interactionScore
        
        // 4. 미해결 대화 감점 (최대 -12점으로 완화)
        let unsolvedPenalty = min(Double(unansweredCount) * 2.5, 12)
        totalScore -= unsolvedPenalty
        
        // 5. 소홀함 플래그 감점 (-8점으로 완화)
        if isNeglected {
            totalScore -= 8
        }
        
        // 6. 관계 지속 기간 보너스 (0-15점으로 상향)
        let relationshipDuration = calendar.dateComponents([.day], from: relationshipStartDate, to: now).day ?? 0
        let durationBonus = min(Double(relationshipDuration) / 20.0 * 15, 15) // 20일당 최대 15점
        totalScore += durationBonus
        
        // 7. 최근 상호작용 보너스 (새로 추가)
        let recentInteractionBonus = calculateRecentInteractionBonus()
        totalScore += recentInteractionBonus
        
        return max(0, min(100, totalScore))
    }
    
    /// 시간 경과에 따른 점수 계산 (-25 ~ +20점으로 개선)
    private func calculateTimeDecayScore() -> Double {
        let now = Date()
        let calendar = Calendar.current
        
        // 가장 최근 상호작용 날짜 찾기
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        // 시간 경과에 따른 점수 (더 관대하게 조정)
        switch daysSinceLastInteraction {
        case 0...1:
            return 20 // 최근 1일 이내: 큰 보너스
        case 2...3:
            return 15 // 2-3일: 좋은 보너스
        case 4...7:
            return 10  // 4-7일: 보통 보너스
        case 8...14:
            return 5  // 1-2주: 작은 보너스
        case 15...21:
            return 0  // 2-3주: 중립
        case 22...35:
            return -8 // 3-5주: 작은 감점
        case 36...60:
            return -15 // 5주-2달: 중간 감점
        default:
            return -25 // 2달 이상: 최대 감점 (기존 -30에서 완화)
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
    
    /// 최근 상호작용 보너스 계산 (0-10점) - 새로 추가
    private func calculateRecentInteractionBonus() -> Double {
        let now = Date()
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        
        var recentBonus: Double = 0
        
        // 최근 3일 내 각 상호작용마다 보너스
        if let lastContact = lastContact, lastContact >= threeDaysAgo {
            recentBonus += 3
        }
        if let lastMeal = lastMeal, lastMeal >= threeDaysAgo {
            recentBonus += 3  
        }
        if let lastMentoring = lastMentoring, lastMentoring >= threeDaysAgo {
            recentBonus += 4 // 멘토링은 더 큰 보너스
        }
        
        return min(recentBonus, 10) // 최대 10점
    }
    
    /// 관계 상태를 자동으로 업데이트
    func updateRelationshipState() {
        let calculatedState = calculateRelationshipState()
        let currentScore = calculateRelationshipScore()
        
        // 상태가 변경된 경우에만 업데이트
        if state != calculatedState {
            let oldState = state
            state = calculatedState
            
            print("🔄 [RelationshipState] \(name)님과의 관계 상태 변경: \(oldState.rawValue) → \(calculatedState.rawValue) (점수: \(Int(currentScore)))")
            
            // 관계가 개선된 경우 소홀함 플래그 해제
            if calculatedState != .distant && isNeglected {
                isNeglected = false
                print("✅ [RelationshipState] \(name)님과의 관계가 개선되어 소홀함 플래그를 해제했습니다")
            }
            // 관계가 악화된 경우에만 소홀함 플래그 설정 (기존보다 완화)
            else if calculatedState == .distant && oldState == .close && currentScore < 30 {
                isNeglected = true
                print("⚠️ [RelationshipState] \(name)님과의 관계가 많이 소홀해졌습니다")
            }
        } else {
            print("📊 [RelationshipState] \(name)님 관계 점수: \(Int(currentScore)) (\(calculatedState.rawValue))")
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
    
    /// 상호작용 기록 추가
    func addInteractionRecord(type: InteractionType, date: Date = Date(), notes: String? = nil, duration: TimeInterval? = nil, location: String? = nil) {
        let record = InteractionRecord(
            date: date,
            type: type,
            notes: notes,
            duration: duration,
            location: location
        )
        record.person = self
        interactionRecords.append(record)
        
        // 기존 lastXXX 필드도 업데이트 (호환성을 위해)
        switch type {
        case .mentoring:
            lastMentoring = date
            if let notes = notes {
                mentoringNotes = notes
            }
        case .meal:
            lastMeal = date
            if let notes = notes {
                mealNotes = notes
            }
        case .contact, .call, .message:
            lastContact = date
            if let notes = notes {
                contactNotes = notes
            }
        case .meeting:
            // meeting은 별도로 처리
            break
        }
    }
    
    /// 특정 타입의 상호작용 기록들 반환
    func getInteractionRecords(ofType type: InteractionType) -> [InteractionRecord] {
        return interactionRecords
            .filter { $0.type == type }
            .sorted { $0.date > $1.date }
    }
    
    /// 모든 상호작용 기록을 날짜순으로 정렬하여 반환
    func getAllInteractionRecordsSorted() -> [InteractionRecord] {
        return interactionRecords.sorted { $0.date > $1.date }
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

// MARK: - PersonContext Helpers
extension Person {
    /// 새로운 컨텍스트 추가
    func addContext(category: ContextCategory, label: String, value: String, date: Date? = nil, modelContext: ModelContext) {
        let context = PersonContext(
            category: category,
            label: label,
            value: value,
            date: date,
            order: contexts.filter { $0.category == category }.count
        )
        context.person = self
        modelContext.insert(context)
        contexts.append(context)
    }
    
    /// 특정 카테고리의 컨텍스트 가져오기
    func getContexts(for category: ContextCategory) -> [PersonContext] {
        return contexts
            .filter { $0.category == category }
            .sorted { $0.order < $1.order }
    }
    
    /// 관심사 가져오기
    func getInterests() -> [PersonContext] {
        return getContexts(for: .interest)
    }
    
    /// 취향/선호 가져오기
    func getPreferences() -> [PersonContext] {
        return getContexts(for: .preference)
    }
    
    /// 중요한 날짜 가져오기
    func getImportantDates() -> [PersonContext] {
        return getContexts(for: .importantDate)
    }
    
    /// 업무 스타일 가져오기
    func getWorkStyles() -> [PersonContext] {
        return getContexts(for: .workStyle)
    }
    
    /// 배경 정보 가져오기
    func getBackgrounds() -> [PersonContext] {
        return getContexts(for: .background)
    }
    
    /// 비어있지 않은 컨텍스트들만 가져오기
    func getNonEmptyContexts(for category: ContextCategory) -> [PersonContext] {
        return getContexts(for: category).filter { !$0.isEmpty }
    }
    
    /// 다가오는 중요한 날짜들 (30일 이내)
    func getUpcomingImportantDates() -> [PersonContext] {
        return getImportantDates().filter { $0.isUpcoming }
    }
    
    /// 기존 String 필드를 PersonContext로 마이그레이션 (호환성 유지)
    func migrateStringFieldsToContexts(modelContext: ModelContext) {
        // 이미 마이그레이션 되었는지 확인 (contexts가 이미 있으면 스킵)
        if !contexts.isEmpty {
            return
        }
        
        // preferredName
        if !preferredName.isEmpty {
            addContext(category: .preference, label: "선호 호칭", value: preferredName, modelContext: modelContext)
        }
        
        // interests - 쉼표로 분리
        if !interests.isEmpty {
            let interestList = interests.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, interest) in interestList.enumerated() {
                let context = PersonContext(
                    category: .interest,
                    label: "관심사 \(index + 1)",
                    value: interest,
                    order: index
                )
                context.person = self
                modelContext.insert(context)
                contexts.append(context)
            }
        }
        
        // preferences - 쉼표로 분리
        if !preferences.isEmpty {
            let prefList = preferences.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, pref) in prefList.enumerated() {
                let context = PersonContext(
                    category: .preference,
                    label: "선호 \(index + 1)",
                    value: pref,
                    order: index
                )
                context.person = self
                modelContext.insert(context)
                contexts.append(context)
            }
        }
        
        // importantDates - 쉼표로 분리
        if !importantDates.isEmpty {
            let dateList = importantDates.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, dateStr) in dateList.enumerated() {
                let context = PersonContext(
                    category: .importantDate,
                    label: "중요한 날짜 \(index + 1)",
                    value: dateStr,
                    order: index
                )
                context.person = self
                modelContext.insert(context)
                contexts.append(context)
            }
        }
        
        // workStyle - 쉼표로 분리
        if !workStyle.isEmpty {
            let styleList = workStyle.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, style) in styleList.enumerated() {
                let context = PersonContext(
                    category: .workStyle,
                    label: "업무 스타일 \(index + 1)",
                    value: style,
                    order: index
                )
                context.person = self
                modelContext.insert(context)
                contexts.append(context)
            }
        }
        
        // background - 쉼표로 분리
        if !background.isEmpty {
            let bgList = background.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            for (index, bg) in bgList.enumerated() {
                let context = PersonContext(
                    category: .background,
                    label: "배경 \(index + 1)",
                    value: bg,
                    order: index
                )
                context.person = self
                modelContext.insert(context)
                contexts.append(context)
            }
        }
        
        print("✅ [\(name)] String 필드를 PersonContext로 마이그레이션 완료 (\(contexts.count)개)")
    }
    
    /// 편의 메서드: 선호 호칭 가져오기
    var displayName: String {
        let preferredNameContext = getPreferences().first { $0.label == "선호 호칭" }
        return preferredNameContext?.value.isEmpty == false ? preferredNameContext!.value : name
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
