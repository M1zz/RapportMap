import Foundation
import SwiftData
import SwiftUI

/// 사람 정보를 관리하는 메인 모델
/// 개인의 기본 정보, 관계 상태, 상호작용 기록 등을 포함
@Model
final class Person {
    // MARK: - 기본 정보
    var id: UUID                        // 고유 식별자
    var name: String                    // 이름
    var contact: String                 // 연락처 (전화번호, 이메일 등)
    var state: RelationshipState        // 현재 관계 상태 (멀어짐/따뜻해지는중/끈끈함)
    
    // MARK: - 상호작용 기록 (기존 호환성 - 자동 계산됨)
    var lastMentoring: Date?            // 마지막 멘토링 날짜 (InteractionRecord에서 자동 계산)
    var lastMeal: Date?                 // 마지막 식사 날짜 (InteractionRecord에서 자동 계산)
    var lastContact: Date?              // 마지막 연락 날짜 (InteractionRecord에서 자동 계산)
    var isNeglected: Bool               // 소홀함 플래그 (자동 계산됨)
    
    // MARK: - 관계 진행 단계
    var currentPhase: ActionPhase       // 현재 관계 단계 (표면적/개인적/깊이있는 등)
    var relationshipStartDate: Date     // 관계 시작일
    
    // MARK: - 개인 컨텍스트 (외장 두뇌 역할 - PersonContext로 마이그레이션됨)
    var preferredName: String           // 선호 호칭 (PersonContext로 마이그레이션 예정)
    var interests: String               // 관심사 (PersonContext로 마이그레이션 예정)
    var preferences: String             // 취향/선호 (PersonContext로 마이그레이션 예정)
    var importantDates: String          // 중요한 날짜들 (PersonContext로 마이그레이션 예정)
    var workStyle: String               // 업무 스타일 (PersonContext로 마이그레이션 예정)
    var background: String              // 배경 정보 (PersonContext로 마이그레이션 예정)
    
    // MARK: - 상호작용별 노트 (InteractionRecord로 마이그레이션됨)
    var mentoringNotes: String?         // 멘토링 관련 메모 (InteractionRecord로 마이그레이션 예정)
    var mealNotes: String?              // 식사 관련 메모 (InteractionRecord로 마이그레이션 예정)
    var contactNotes: String?           // 연락 관련 메모 (InteractionRecord로 마이그레이션 예정)
    
    // MARK: - 관계형 데이터 (SwiftData Relationships)
    
    /// 이 사람과 관련된 액션들 (할 일, 메모 등)
    /// cascade 삭제: 사람이 삭제되면 관련 액션들도 모두 삭제됨
    @Relationship(deleteRule: .cascade, inverse: \PersonAction.person)
    var actions: [PersonAction] = []
    
    /// 이 사람과의 미팅/만남 기록들
    /// cascade 삭제: 사람이 삭제되면 관련 미팅 기록들도 모두 삭제됨
    @Relationship(deleteRule: .cascade, inverse: \MeetingRecord.person)
    var meetingRecords: [MeetingRecord] = []
    
    /// 이 사람과의 상호작용 기록들 (식사, 전화, 메시지 등)
    /// cascade 삭제: 사람이 삭제되면 관련 상호작용 기록들도 모두 삭제됨
    @Relationship(deleteRule: .cascade, inverse: \InteractionRecord.person)
    var interactionRecords: [InteractionRecord] = []
    
    /// 이 사람의 상세한 컨텍스트 정보들 (관심사, 선호도, 중요한 날짜 등)
    /// cascade 삭제: 사람이 삭제되면 관련 컨텍스트들도 모두 삭제됨
    @Relationship(deleteRule: .cascade, inverse: \PersonContext.person)
    var contexts: [PersonContext] = []
    
    /// 이 사람과의 대화/상태 기록들 (질문, 고민, 약속 등)
    /// cascade 삭제: 사람이 삭제되면 관련 대화 기록들도 모두 삭제됨
    @Relationship(deleteRule: .cascade, inverse: \ConversationRecord.person)
    var conversationRecords: [ConversationRecord] = []
    // MARK: - 초기화
    /// Person 객체 생성자
    /// - Parameters:
    ///   - id: 고유 식별자 (기본값: 새로운 UUID)
    ///   - name: 이름 (필수)
    ///   - contact: 연락처 정보 (기본값: 빈 문자열)
    ///   - state: 관계 상태 (기본값: .distant)
    ///   - currentPhase: 현재 관계 단계 (기본값: .surface)
    ///   - relationshipStartDate: 관계 시작일 (기본값: 현재 날짜)
    ///   - 기타 레거시 필드들 (호환성을 위해 유지, 점진적으로 제거 예정)
    init(
        id: UUID = UUID(),
        name: String,
        contact: String = "",
        state: RelationshipState = .distant,
        lastMentoring: Date? = nil,
        lastMeal: Date? = nil,
        lastContact: Date? = nil,
        isNeglected: Bool = false,
        currentPhase: ActionPhase = .surface,
        relationshipStartDate: Date = Date(),
        preferredName: String = "",
        interests: String = "",
        preferences: String = "",
        importantDates: String = "",
        workStyle: String = "",
        background: String = "",
        mentoringNotes: String? = nil,
        mealNotes: String? = nil,
        contactNotes: String? = nil
    ) {
        // 기본 정보 초기화
        self.id = id
        self.name = name
        self.contact = contact
        self.state = state
        
        // 상호작용 기록 (호환성)
        self.lastMentoring = lastMentoring
        self.lastMeal = lastMeal
        self.lastContact = lastContact
        self.isNeglected = isNeglected
        
        // 관계 진행 정보
        self.currentPhase = currentPhase
        self.relationshipStartDate = relationshipStartDate
        
        // 개인 컨텍스트 (레거시 필드 - 마이그레이션 예정)
        self.preferredName = preferredName
        self.interests = interests
        self.preferences = preferences
        self.importantDates = importantDates
        self.workStyle = workStyle
        self.background = background
        
        // 상호작용 노트 (레거시 필드 - 마이그레이션 예정)
        self.mentoringNotes = mentoringNotes
        self.mealNotes = mealNotes
        self.contactNotes = contactNotes
    }
}

/// 관계 상태를 나타내는 열거형
/// 사람과의 관계 정도를 세 단계로 구분
enum RelationshipState: String, Codable, CaseIterable {
    case distant = "distant"    // 멀어진 상태 - 연락이 뜸하거나 관계가 소홀해진 상태
    case warming = "warming"    // 따뜻해지는 중 - 관계가 발전하고 있는 상태
    case close = "close"        // 끈끈한 상태 - 좋은 관계를 유지하고 있는 상태
    
    /// 각 상태에 맞는 이모지 반환
    var emoji: String {
        switch self {
        case .distant: return "😐"
        case .warming: return "🙂"
        case .close: return "😊"
        }
    }
    
    /// 한국어로 된 관계 상태 이름
    var localizedName: String {
        switch self {
        case .distant: return "멀어짐"
        case .warming: return "따뜻해지는 중"
        case .close: return "끈끈함"
        }
    }
    
    /// 각 관계 상태에 대한 설명 텍스트
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
    
    /// 각 관계 상태에 해당하는 색상
    var color: Color {
        switch self {
        case .distant: return .blue
        case .warming: return .orange
        case .close: return .pink
        }
    }
}

// MARK: - 관계 상태 자동 계산 시스템
/// Person 모델의 관계 상태를 자동으로 분석하고 업데이트하는 확장
extension Person {
    
    /// 현재 관계 상태를 자동으로 계산하여 반환
    /// 관계 점수(0-100)를 기반으로 세 가지 상태 중 하나를 결정
    /// - Returns: 계산된 관계 상태 (distant/warming/close)
    func calculateRelationshipState() -> RelationshipState {
        let score = calculateRelationshipScore()
        
        // 점수 기준으로 관계 상태 결정 (관대한 기준 적용)
        switch score {
        case 65...:         // 65점 이상: 끈끈한 관계
            return .close
        case 35..<65:       // 35-64점: 발전 중인 관계
            return .warming
        default:            // 35점 미만: 멀어진 관계
            return .distant
        }
    }
    
    /// 관계 점수 계산 (0-100점)
    /// 여러 요소를 종합하여 관계의 건강도를 수치로 평가
    /// - 시간 경과, 액션 완료도, 상호작용 빈도, 미해결 대화 등을 고려
    /// - Returns: 0-100 사이의 관계 점수
    func calculateRelationshipScore() -> Double {
        var totalScore: Double = 40 // 기본 점수 40점 (관대한 시작점)
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 시간 경과 점수: 최근 상호작용으로부터 경과된 시간 (-25 ~ +20점)
        let timeDecayScore = calculateTimeDecayScore()
        totalScore += timeDecayScore
        
        // 2. 액션 완료도 점수: 할 일과 약속의 이행 정도 (0-25점)
        let actionScore = calculateActionCompletionScore()
        totalScore += actionScore
        
        // 3. 상호작용 빈도 점수: 최근 한 달간의 만남/연락 빈도 (0-20점)
        let interactionScore = calculateInteractionFrequencyScore()
        totalScore += interactionScore
        
        // 4. 새로운 대화 기록 시스템의 미해결 대화 감점 (최대 -12점)
        let unresolvedConversations = getUnresolvedConversationRecords().count
        let unsolvedPenalty = min(Double(unresolvedConversations) * 2.0, 12)
        totalScore -= unsolvedPenalty
        
        // 5. 소홀함 플래그 감점: 시스템이 판단한 관계 소홀 (-8점)
        if isNeglected {
            totalScore -= 8
        }
        
        // 6. 관계 지속 기간 보너스: 오래된 관계에 대한 가산점 (0-15점)
        let relationshipDuration = calendar.dateComponents([.day], from: relationshipStartDate, to: now).day ?? 0
        let durationBonus = min(Double(relationshipDuration) / 20.0 * 15, 15) // 20일당 최대 15점
        totalScore += durationBonus
        
        // 7. 최근 상호작용 보너스: 3일 내 활발한 소통에 대한 추가 점수 (0-10점)
        let recentInteractionBonus = calculateRecentInteractionBonus()
        totalScore += recentInteractionBonus
        
        // 최종 점수를 0-100 범위로 제한
        return max(0, min(100, totalScore))
    }
    
    /// 시간 경과에 따른 점수 계산
    /// 마지막 상호작용으로부터 얼마나 시간이 지났는지에 따라 점수 산정
    /// - Returns: -25점(2달 이상 소원) ~ +20점(최근 1일 이내) 범위의 점수
    private func calculateTimeDecayScore() -> Double {
        let now = Date()
        let calendar = Calendar.current
        
        // 가장 최근 상호작용 날짜 찾기 (연락, 식사, 멘토링 중 가장 최근)
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        // 시간 경과에 따른 단계별 점수 (관대한 기준 적용)
        switch daysSinceLastInteraction {
        case 0...1:         // 최근 1일: 매우 좋음
            return 20
        case 2...3:         // 2-3일: 좋음
            return 15
        case 4...7:         // 4-7일: 보통 좋음
            return 10
        case 8...14:        // 1-2주: 약간 좋음
            return 5
        case 15...21:       // 2-3주: 중립
            return 0
        case 22...35:       // 3-5주: 약간 나쁨
            return -8
        case 36...60:       // 5주-2달: 나쁨
            return -15
        default:            // 2달 이상: 매우 나쁨
            return -25
        }
    }
    
    /// 액션(할 일) 완료도 점수 계산
    /// 이 사람과 관련된 액션들의 완료율을 기반으로 점수 산정
    /// Critical 액션의 완료도에 더 높은 가중치 적용
    /// - Returns: 0-25점 범위의 점수
    private func calculateActionCompletionScore() -> Double {
        let totalActions = actions.count
        guard totalActions > 0 else { return 0 }
        
        // 전체 액션 완료율 계산
        let completedActions = actions.filter { $0.isCompleted }.count
        let completionRate = Double(completedActions) / Double(totalActions)
        
        // Critical 액션들의 완료도는 더 높은 가중치로 계산
        let criticalActions = actions.filter { $0.action?.type == .critical }
        let completedCriticalActions = criticalActions.filter { $0.isCompleted }
        
        let criticalBonus = criticalActions.isEmpty ? 0 : 
            Double(completedCriticalActions.count) / Double(criticalActions.count) * 10
        
        // 기본 완료율(15점) + Critical 액션 보너스(10점) = 최대 25점
        return completionRate * 15 + criticalBonus
    }
    
    /// 상호작용 빈도 점수 계산
    /// 최근 30일 내의 다양한 상호작용(연락, 식사, 멘토링, 미팅) 빈도 측정
    /// - Returns: 0-20점 범위의 점수
    private func calculateInteractionFrequencyScore() -> Double {
        let now = Date()
        let calendar = Calendar.current
        let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        
        var interactionCount = 0
        
        // 최근 30일 내 기본 상호작용 카운트 (연락, 식사, 멘토링)
        [lastContact, lastMeal, lastMentoring].forEach { date in
            if let date = date, date >= thirtyDaysAgo {
                interactionCount += 1
            }
        }
        
        // 미팅 기록도 상호작용에 포함
        let recentMeetings = meetingRecords.filter { $0.date >= thirtyDaysAgo }.count
        interactionCount += recentMeetings
        
        // 상호작용 빈도에 따른 단계별 점수
        switch interactionCount {
        case 8...:      // 8회 이상: 매우 활발한 관계
            return 20
        case 5...7:     // 5-7회: 활발한 관계
            return 15
        case 3...4:     // 3-4회: 적당한 관계
            return 10
        case 1...2:     // 1-2회: 소극적인 관계
            return 5
        default:        // 0회: 상호작용 없음
            return 0
        }
    }
    
    /// 최근 상호작용 보너스 점수 계산
    /// 최근 3일 내의 활발한 소통에 대한 추가 보너스 점수
    /// - Returns: 0-10점 범위의 보너스 점수
    private func calculateRecentInteractionBonus() -> Double {
        let now = Date()
        let calendar = Calendar.current
        let threeDaysAgo = calendar.date(byAdding: .day, value: -3, to: now) ?? now
        
        var recentBonus: Double = 0
        
        // 최근 3일 내 각 상호작용 타입별 보너스 점수
        if let lastContact = lastContact, lastContact >= threeDaysAgo {
            recentBonus += 3    // 최근 연락 보너스
        }
        if let lastMeal = lastMeal, lastMeal >= threeDaysAgo {
            recentBonus += 3    // 최근 식사 보너스
        }
        if let lastMentoring = lastMentoring, lastMentoring >= threeDaysAgo {
            recentBonus += 4    // 최근 멘토링 보너스 (더 높은 가중치)
        }
        
        return min(recentBonus, 10) // 최대 10점으로 제한
    }
    
    /// 관계 상태를 자동으로 업데이트하는 메인 메서드
    /// 계산된 점수를 바탕으로 관계 상태를 갱신하고, 소홀함 플래그도 관리
    /// 상태 변경 시 콘솔에 로그를 출력하여 디버깅 지원
    func updateRelationshipState() {
        let calculatedState = calculateRelationshipState()
        let currentScore = calculateRelationshipScore()
        
        // 상태가 실제로 변경된 경우에만 업데이트 수행
        if state != calculatedState {
            let oldState = state
            state = calculatedState
            
            print("🔄 [RelationshipState] \(name)님과의 관계 상태 변경: \(oldState.rawValue) → \(calculatedState.rawValue) (점수: \(Int(currentScore)))")
            
            // 관계가 개선되어 멀어짐 상태를 벗어난 경우 소홀함 플래그 해제
            if calculatedState != .distant && isNeglected {
                isNeglected = false
                print("✅ [RelationshipState] \(name)님과의 관계가 개선되어 소홀함 플래그를 해제했습니다")
            }
            // 관계가 크게 악화된 경우에만 소홀함 플래그 설정 (기존보다 완화된 조건)
            else if calculatedState == .distant && oldState == .close && currentScore < 30 {
                isNeglected = true
                print("⚠️ [RelationshipState] \(name)님과의 관계가 많이 소홀해졌습니다")
            }
        } else {
            // 상태 변경은 없지만 현재 점수를 로그로 출력
            print("📊 [RelationshipState] \(name)님 관계 점수: \(Int(currentScore)) (\(calculatedState.rawValue))")
        }
    }
    
    /// 관계 상태에 대한 종합적인 분석 정보를 반환
    /// UI에서 관계 상태를 표시하거나 개선 방안을 제시할 때 사용
    /// - Returns: 현재 점수, 상태, 분석 결과, 추천사항을 포함한 RelationshipAnalysis 객체
    func getRelationshipAnalysis() -> RelationshipAnalysis {
        let score = calculateRelationshipScore()
        let now = Date()
        let calendar = Calendar.current
        
        // 마지막 상호작용으로부터 경과된 일수 계산
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        // 분석 결과를 구조체로 반환
        return RelationshipAnalysis(
            currentScore: score,
            currentState: calculateRelationshipState(),
            daysSinceLastInteraction: daysSinceLastInteraction,
            actionCompletionRate: calculateActionCompletionRate(),
            criticalActionCompletionRate: calculateCriticalActionCompletionRate(),
            recommendations: generateRecommendations()
        )
    }
    
    /// 새로운 상호작용 기록 추가
    /// 다양한 상호작용 타입(멘토링, 식사, 연락 등)을 기록하고 기존 필드도 동기화
    /// - Parameters:
    ///   - type: 상호작용 타입 (InteractionType enum)
    ///   - date: 상호작용 발생 날짜 (기본값: 현재 시간)
    ///   - notes: 상호작용에 대한 메모
    ///   - duration: 상호작용 지속 시간
    ///   - location: 상호작용 발생 장소
    func addInteractionRecord(type: InteractionType, date: Date = Date(), notes: String? = nil, duration: TimeInterval? = nil, location: String? = nil) {
        // 새로운 상호작용 기록 생성
        let record = InteractionRecord(
            date: date,
            type: type,
            notes: notes,
            duration: duration,
            location: location
        )
        record.person = self
        interactionRecords.append(record)
        
        // 기존 lastXXX 필드도 업데이트 (기존 코드와의 호환성 유지)
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
            // meeting은 별도의 MeetingRecord로 처리
            break
        }
    }
    
    /// 특정 타입의 상호작용 기록들을 날짜 역순으로 반환
    /// - Parameter type: 조회할 상호작용 타입
    /// - Returns: 해당 타입의 상호작용 기록들 (최신순)
    func getInteractionRecords(ofType type: InteractionType) -> [InteractionRecord] {
        return interactionRecords
            .filter { $0.type == type }
            .sorted { $0.date > $1.date }
    }
    
    /// 모든 상호작용 기록을 날짜 역순으로 정렬하여 반환
    /// 타임라인 뷰나 전체 기록 보기에서 사용
    /// - Returns: 모든 상호작용 기록들 (최신순)
    func getAllInteractionRecordsSorted() -> [InteractionRecord] {
        return interactionRecords.sorted { $0.date > $1.date }
    }
    
    // MARK: - 대화/상태 기록 관리 메서드들
    
    /// 새로운 대화/상태 기록 추가
    /// 질문, 고민, 약속 등의 대화 내용을 구조화하여 저장
    /// - Parameters:
    ///   - type: 대화 타입 (질문, 고민, 약속 등)
    ///   - content: 대화 내용
    ///   - notes: 추가 메모
    ///   - priority: 우선순위 (기본값: normal)
    ///   - tags: 태그들 (기본값: 빈 배열)
    ///   - date: 기록 날짜 (기본값: 현재 시간)
    /// - Returns: 생성된 ConversationRecord 객체
    func addConversationRecord(
        type: ConversationType,
        content: String,
        notes: String? = nil,
        priority: ConversationPriority = .normal,
        tags: [String] = [],
        date: Date = Date()
    ) -> ConversationRecord {
        let record = ConversationRecord(
            date: date,
            type: type,
            content: content,
            notes: notes,
            priority: priority,
            tags: tags
        )
        record.person = self
        conversationRecords.append(record)
        
        // 기존 필드들도 호환성을 위해 업데이트
        updateLegacyConversationFields(from: record)
        
        return record
    }
    
    /// 기존 레거시 필드들 업데이트 (호환성 유지)
    /// 새로운 대화 기록이 추가될 때 기존 String 필드들도 함께 업데이트
    /// 점진적으로 제거 예정 - 현재는 호환성을 위해서만 유지
    /// - Parameter record: 새로 추가된 대화 기록
    private func updateLegacyConversationFields(from record: ConversationRecord) {
        // 더 이상 사용하지 않는 레거시 필드 업데이트는 제거됨
        // ConversationRecord 시스템으로 완전 전환
        
        // 향후 이 메서드 자체도 제거될 예정
        print("🔄 [Legacy] 대화 기록이 새로운 시스템에 추가됨: \(record.type.title)")
    }
    
    /// 대화 기록을 해결됨으로 표시
    /// 질문에 답변했거나 약속을 이행했을 때 호출
    /// - Parameter record: 해결할 대화 기록
    func resolveConversationRecord(_ record: ConversationRecord) {
        record.isResolved = true
        print("✅ [Conversation] \(record.type.title) 해결됨: \(record.content)")
    }
    
    /// 특정 타입의 대화 기록들을 날짜 역순으로 반환
    /// - Parameter type: 조회할 대화 타입
    /// - Returns: 해당 타입의 대화 기록들 (최신순)
    func getConversationRecords(ofType type: ConversationType) -> [ConversationRecord] {
        return conversationRecords
            .filter { $0.type == type }
            .sorted { $0.date > $1.date }
    }
    
    /// 모든 대화 기록을 날짜 역순으로 정렬하여 반환
    /// - Returns: 모든 대화 기록들 (최신순)
    func getAllConversationRecordsSorted() -> [ConversationRecord] {
        return conversationRecords.sorted { $0.date > $1.date }
    }
    
    /// 미해결된 대화 기록들만 반환
    /// 답변하지 않은 질문이나 이행하지 않은 약속들을 조회할 때 사용
    /// - Returns: 미해결 대화 기록들 (우선순위 및 날짜순)
    func getUnresolvedConversationRecords() -> [ConversationRecord] {
        return conversationRecords
            .filter { !$0.isResolved }
            .sorted { record1, record2 in
                // 우선순위가 높은 것부터, 같으면 날짜가 오래된 것부터
                if record1.priority.sortOrder != record2.priority.sortOrder {
                    return record1.priority.sortOrder > record2.priority.sortOrder
                }
                return record1.date < record2.date
            }
    }
    
    /// 높은 우선순위의 미해결 대화 기록들 반환
    /// - Returns: 긴급/높음 우선순위의 미해결 기록들
    func getHighPriorityUnresolvedConversations() -> [ConversationRecord] {
        return getUnresolvedConversationRecords()
            .filter { $0.priority == .urgent || $0.priority == .high }
    }
    
    /// 최근 대화 기록들 반환 (7일 이내)
    /// - Returns: 최근 1주일 내의 대화 기록들
    func getRecentConversationRecords() -> [ConversationRecord] {
        return conversationRecords
            .filter { $0.isRecent }
            .sorted { $0.date > $1.date }
    }
    
    /// 특정 태그를 포함한 대화 기록들 반환
    /// - Parameter tag: 검색할 태그
    /// - Returns: 해당 태그가 포함된 대화 기록들
    func getConversationRecords(withTag tag: String) -> [ConversationRecord] {
        return conversationRecords
            .filter { $0.tags.contains(tag) }
            .sorted { $0.date > $1.date }
    }
    
    /// 대화 기록 통계 정보 반환
    /// - Returns: 대화 기록 통계를 담은 딕셔너리
    func getConversationStatistics() -> [String: Int] {
        let total = conversationRecords.count
        let resolved = conversationRecords.filter { $0.isResolved }.count
        let unresolved = total - resolved
        let questions = conversationRecords.filter { $0.type == .question }.count
        let concerns = conversationRecords.filter { $0.type == .concern }.count
        let promises = conversationRecords.filter { $0.type == .promise }.count
        let recent = conversationRecords.filter { $0.isRecent }.count
        let highPriority = conversationRecords.filter { $0.priority == .urgent || $0.priority == .high }.count
        
        return [
            "총 기록": total,
            "해결됨": resolved,
            "미해결": unresolved,
            "질문": questions,
            "고민": concerns,
            "약속": promises,
            "최근 기록": recent,
            "높은 우선순위": highPriority
        ]
    }
    
    /// 전체 액션의 완료율 계산 (내부 헬퍼 메서드)
    /// - Returns: 0.0-1.0 사이의 완료율
    private func calculateActionCompletionRate() -> Double {
        guard !actions.isEmpty else { return 0 }
        let completed = actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(actions.count)
    }
    
    /// Critical 액션의 완료율 계산 (내부 헬퍼 메서드)
    /// - Returns: 0.0-1.0 사이의 Critical 액션 완료율
    private func calculateCriticalActionCompletionRate() -> Double {
        let criticalActions = actions.filter { $0.action?.type == .critical }
        guard !criticalActions.isEmpty else { return 0 }
        let completed = criticalActions.filter { $0.isCompleted }.count
        return Double(completed) / Double(criticalActions.count)
    }
    
    /// 관계 개선을 위한 추천 사항들을 생성
    /// 현재 상황을 분석하여 구체적인 행동 제안을 제공
    /// - Returns: 추천 메시지들의 배열
    private func generateRecommendations() -> [String] {
        var recommendations: [String] = []
        let now = Date()
        let calendar = Calendar.current
        
        // 마지막 상호작용으로부터 경과 시간 확인
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        
        // 1. 시간 기반 추천
        if daysSinceLastInteraction > 14 {
            recommendations.append("🚨 2주 이상 연락이 없었어요. 안부 인사를 보내보세요")
        } else if daysSinceLastInteraction > 7 {
            recommendations.append("📱 일주일이 지났어요. 가벼운 연락을 해보세요")
        }
        
        // 2. 액션 기반 추천
        let incompleteCritical = actions.filter { $0.action?.type == .critical && !$0.isCompleted }.count
        if incompleteCritical > 0 {
            recommendations.append("⚠️ 중요한 액션 \(incompleteCritical)개가 미완료입니다")
        }
        
        // 3. 새로운 대화 시스템 기반 추천
        let unresolvedConversations = getUnresolvedConversationRecords()
        if unresolvedConversations.count > 2 {
            recommendations.append("💬 미해결 대화가 \(unresolvedConversations.count)개 있어요. 답변해보세요")
        }
        
        // 높은 우선순위 대화가 있는 경우
        let highPriorityCount = getHighPriorityUnresolvedConversations().count
        if highPriorityCount > 0 {
            recommendations.append("🚨 긴급/중요한 대화 \(highPriorityCount)개를 확인해보세요")
        }
        
        // 4. 식사/만남 추천
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

// MARK: - PersonContext 관리 헬퍼 메서드들
/// Person 모델의 세부 컨텍스트 정보를 관리하는 확장
/// 관심사, 선호도, 중요한 날짜 등의 구조화된 개인 정보 관리
extension Person {
    /// 새로운 컨텍스트 정보 추가
    /// PersonContext 모델을 사용하여 구조화된 개인 정보를 저장
    /// - Parameters:
    ///   - category: 컨텍스트 카테고리 (관심사, 선호도, 중요한 날짜 등)
    ///   - label: 컨텍스트 라벨 (예: "취미", "생일")
    ///   - value: 실제 값 (예: "등산", "5월 15일")
    ///   - date: 관련 날짜 (선택사항)
    ///   - modelContext: SwiftData 모델 컨텍스트
    func addContext(category: ContextCategory, label: String, value: String, date: Date? = nil, modelContext: ModelContext) {
        // 해당 카테고리 내에서의 순서를 결정 (기존 항목 수 + 1)
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
    
    /// 특정 카테고리의 컨텍스트들을 순서대로 가져오기
    /// - Parameter category: 조회할 컨텍스트 카테고리
    /// - Returns: 해당 카테고리의 PersonContext 배열 (순서대로 정렬)
    func getContexts(for category: ContextCategory) -> [PersonContext] {
        return contexts
            .filter { $0.category == category }
            .sorted { $0.order < $1.order }
    }
    
    // MARK: - 카테고리별 컨텍스트 편의 메서드들
    
    /// 관심사 목록 가져오기
    /// - Returns: 이 사람의 관심사들 (취미, 좋아하는 것들)
    func getInterests() -> [PersonContext] {
        return getContexts(for: .interest)
    }
    
    /// 취향/선호도 목록 가져오기
    /// - Returns: 이 사람의 선호사항들 (좋아하는/싫어하는 것들)
    func getPreferences() -> [PersonContext] {
        return getContexts(for: .preference)
    }
    
    /// 중요한 날짜들 가져오기
    /// - Returns: 이 사람과 관련된 중요한 날짜들 (생일, 기념일 등)
    func getImportantDates() -> [PersonContext] {
        return getContexts(for: .importantDate)
    }
    
    /// 업무 스타일 정보 가져오기
    /// - Returns: 이 사람의 업무 스타일이나 일하는 방식들
    func getWorkStyles() -> [PersonContext] {
        return getContexts(for: .workStyle)
    }
    
    /// 배경 정보 가져오기
    /// - Returns: 이 사람의 배경 정보들 (출신, 경력, 가족 사항 등)
    func getBackgrounds() -> [PersonContext] {
        return getContexts(for: .background)
    }
    
    /// 내용이 있는 컨텍스트들만 필터링하여 반환
    /// 빈 값이나 의미 없는 데이터를 제외하고 실제 정보가 있는 것들만 조회
    /// - Parameter category: 조회할 카테고리
    /// - Returns: 비어있지 않은 컨텍스트들
    func getNonEmptyContexts(for category: ContextCategory) -> [PersonContext] {
        return getContexts(for: category).filter { !$0.isEmpty }
    }
    
    /// 다가오는 중요한 날짜들 조회 (30일 이내)
    /// 생일, 기념일 등 곧 다가올 중요한 날짜들을 미리 확인할 수 있음
    /// - Returns: 30일 이내에 다가오는 중요한 날짜들
    func getUpcomingImportantDates() -> [PersonContext] {
        return getImportantDates().filter { $0.isUpcoming }
    }
    
    /// 기존 String 필드를 새로운 PersonContext 구조로 마이그레이션
    /// 앱 업데이트 시 기존 데이터의 호환성을 유지하기 위한 메서드
    /// 기존의 interests, preferences 등의 String 필드를 구조화된 PersonContext로 변환
    /// - Parameter modelContext: SwiftData 모델 컨텍스트
    func migrateStringFieldsToContexts(modelContext: ModelContext) {
        // 이미 마이그레이션 되었는지 확인 (contexts가 이미 있으면 중복 실행 방지)
        if !contexts.isEmpty {
            return
        }
        
        // 1. preferredName (선호 호칭) 마이그레이션
        if !preferredName.isEmpty {
            addContext(category: .preference, label: "선호 호칭", value: preferredName, modelContext: modelContext)
        }
        
        // 2. interests (관심사) - 쉼표로 분리하여 각각 별도 컨텍스트로 생성
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
        
        // 3. preferences (취향/선호) - 쉼표로 분리
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
        
        // 4. importantDates (중요한 날짜) - 쉼표로 분리
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
        
        // 5. workStyle (업무 스타일) - 쉼표로 분리
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
        
        // 6. background (배경 정보) - 쉼표로 분리
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
        
        print("✅ [\(name)] String 필드를 PersonContext로 마이그레이션 완료 (\(contexts.count)개)")}
    
    /// 편의 메서드: 표시할 이름 결정
    /// preferredName이 설정되어 있으면 그것을 사용하고, 없으면 기본 name 사용
    /// - Returns: 화면에 표시할 이름 (선호 호칭 또는 기본 이름)
    var displayName: String {
        let preferredNameContext = getPreferences().first { $0.label == "선호 호칭" }
        return preferredNameContext?.value.isEmpty == false ? preferredNameContext!.value : name
    }
    
    // MARK: - 대화/상태 관련 편의 프로퍼티들
    
    /// 미해결 질문 수 (새로운 방식으로 계산)
    var currentUnansweredCount: Int {
        return conversationRecords
            .filter { $0.type == .question && !$0.isResolved }
            .count
    }
    
    /// 최근 받은 질문 (최신 1개)
    var latestQuestion: String? {
        return conversationRecords
            .filter { $0.type == .question }
            .sorted { $0.date > $1.date }
            .first?.content
    }
    
    /// 최근 고민사항들 (해결되지 않은 것들)
    var currentConcerns: [String] {
        return conversationRecords
            .filter { $0.type == .concern && !$0.isResolved }
            .sorted { $0.date > $1.date }
            .map { $0.content }
    }
    
    /// 미해결 약속들
    var currentUnresolvedPromises: [String] {
        return conversationRecords
            .filter { $0.type == .promise && !$0.isResolved }
            .sorted { $0.date > $1.date }
            .map { $0.content }
    }
    
    /// 최근 받은 질문들 (모든 요청 타입 포함)
    var allReceivedQuestions: [String] {
        return conversationRecords
            .filter { $0.type == .question || $0.type == .request }
            .sorted { $0.date > $1.date }
            .map { $0.content }
    }
    
    /// 대화 기록이 있는지 확인
    var hasConversationRecords: Bool {
        return !conversationRecords.isEmpty
    }
    
    /// 미해결 대화가 있는지 확인
    var hasUnresolvedConversations: Bool {
        return conversationRecords.contains { !$0.isResolved }
    }
    
    /// 높은 우선순위 미해결 대화가 있는지 확인
    var hasHighPriorityUnresolvedConversations: Bool {
        return conversationRecords.contains { 
            !$0.isResolved && ($0.priority == .urgent || $0.priority == .high)
        }
    }
    
    /// 대화 기록 요약 텍스트
    var conversationSummary: String {
        let total = conversationRecords.count
        let unresolved = getUnresolvedConversationRecords().count
        
        if total == 0 {
            return "대화 기록 없음"
        } else if unresolved == 0 {
            return "총 \(total)개 기록 (모두 해결됨)"
        } else {
            return "총 \(total)개 기록 (\(unresolved)개 미해결)"
        }
    }
    
    // MARK: - 레거시 호환 프로퍼티들 (자동 계산됨)
    
    /// 레거시 호환: 미답변 질문 수 (currentUnansweredCount로 대체됨)
    var unansweredCount: Int {
        return currentUnansweredCount
    }
    
    /// 레거시 호환: 마지막 질문 (latestQuestion으로 대체됨)
    var lastQuestion: String? {
        return latestQuestion
    }
    
    /// 레거시 호환: 최근 고민 (currentConcerns의 첫 번째 항목)
    var recentConcerns: String? {
        return currentConcerns.first
    }
    
    /// 레거시 호환: 받은 질문들 (allReceivedQuestions의 요약)
    var receivedQuestions: String? {
        let questions = allReceivedQuestions.prefix(3)
        return questions.isEmpty ? nil : questions.joined(separator: "; ")
    }
    
    /// 레거시 호환: 미해결 약속들 (currentUnresolvedPromises의 요약)
    var unresolvedPromises: String? {
        let promises = currentUnresolvedPromises.prefix(3)
        return promises.isEmpty ? nil : promises.joined(separator: "; ")
    }
}


/// 관계 분석 결과를 담는 구조체
/// 관계 상태의 상세한 분석 정보와 개선 제안사항들을 포함
struct RelationshipAnalysis {
    let currentScore: Double                    // 현재 관계 점수 (0-100)
    let currentState: RelationshipState         // 현재 관계 상태 (distant/warming/close)
    let daysSinceLastInteraction: Int           // 마지막 상호작용으로부터 경과된 일수
    let actionCompletionRate: Double            // 전체 액션 완료율 (0.0-1.0)
    let criticalActionCompletionRate: Double    // Critical 액션 완료율 (0.0-1.0)
    let recommendations: [String]               // 관계 개선을 위한 추천사항들
}
