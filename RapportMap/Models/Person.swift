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
    
    // MARK: - 프로필 사진
    @Attribute(.externalStorage)
    var profileImageData: Data?         // 프로필 사진 데이터 (JPEG/PNG)
    
    // MARK: - 상호작용 기록 (기존 호환성 - 자동 계산됨)
    var lastMentoring: Date?            // 마지막 멘토링 날짜 (InteractionRecord에서 자동 계산)
    var lastMeal: Date?                 // 마지막 식사 날짜 (InteractionRecord에서 자동 계산)
    var lastContact: Date?              // 마지막 연락 날짜 (InteractionRecord에서 자동 계산)
    // isNeglected는 computed property로 자동 계산됨
    
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

    // MARK: - 빠른 메모
    var quickMemo: String = ""          // 대화 후 빠른 메모 (나중에 분석하여 약속, 정보 등으로 분류)
    
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

    /// 아카이브된 빠른 메모들
    /// cascade 삭제: 사람이 삭제되면 관련 메모들도 모두 삭제됨
    @Relationship(deleteRule: .cascade, inverse: \QuickMemoArchive.person)
    var archivedMemos: [QuickMemoArchive] = []

    // MARK: - 초기화
    /// Person 객체 생성자
    /// - Parameters:
    ///   - id: 고유 식별자 (기본값: 새로운 UUID)
    ///   - name: 이름 (필수)
    ///   - contact: 연락처 정보 (기본값: 빈 문자열)
    ///   - currentPhase: 현재 관계 단계 (기본값: .surface)
    ///   - relationshipStartDate: 관계 시작일 (기본값: 현재 날짜)
    ///   - 기타 레거시 필드들 (호환성을 위해 유지, 점진적으로 제거 예정)
    init(
        id: UUID = UUID(),
        name: String,
        contact: String = "",
        lastMentoring: Date? = nil,
        lastMeal: Date? = nil,
        lastContact: Date? = nil,
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
        
        // 상호작용 기록 (호환성)
        self.lastMentoring = lastMentoring
        self.lastMeal = lastMeal
        self.lastContact = lastContact
        
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


// MARK: - 상호작용 기록 시스템
/// Person 모델의 상호작용 기록을 관리하는 확장
extension Person {

    /// 새로운 상호작용 기록 추가
    /// 다양한 상호작용 타입(멘토링, 식사, 연락 등)을 기록하고 기존 필드도 동기화
    /// - Parameters:
    ///   - type: 상호작용 타입 (InteractionType enum)
    ///   - date: 상호작용 발생 날짜 (기본값: 현재 시간)
    ///   - notes: 상호작용에 대한 메모
    ///   - duration: 상호작용 지속 시간
    ///   - location: 상호작용 발생 장소
    ///   - relatedMeetingRecord: 연관된 미팅 기록 (멘토링의 경우 녹음 파일)
    /// - Returns: 생성된 InteractionRecord 인스턴스
    func addInteractionRecord(
        type: InteractionType, 
        date: Date = Date(), 
        notes: String? = nil, 
        duration: TimeInterval? = nil, 
        location: String? = nil,
        relatedMeetingRecord: MeetingRecord? = nil
    ) -> InteractionRecord {
        // 새로운 상호작용 기록 생성
        let record = InteractionRecord(
            date: date,
            type: type,
            notes: notes,
            duration: duration,
            location: location,
            relatedMeetingRecord: relatedMeetingRecord
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
        case .contact, .call, .message, .quickNote:
            lastContact = date
            if let notes = notes {
                contactNotes = notes
            }
        case .meeting:
            // meeting은 별도의 MeetingRecord로 처리
            break
        }
        
        return record
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
    
    /// 중요한 상호작용 기록들만 반환
    /// "놓치면 안되는 것들" 섹션에서 사용
    /// - Returns: 중요하다고 표시된 상호작용 기록들 (최신순)
    func getImportantInteractionRecords() -> [InteractionRecord] {
        return interactionRecords
            .filter { $0.isImportant }
            .sorted { $0.date > $1.date }
    }
    
    /// 중요한 미팅 기록들만 반환
    /// "놓치면 안되는 것들" 섹션에서 사용
    /// - Returns: 중요하다고 표시된 미팅 기록들 (최신순)
    func getImportantMeetingRecords() -> [MeetingRecord] {
        return meetingRecords
            .filter { $0.isImportant }
            .sorted { $0.date > $1.date }
    }
    
    /// 중요한 대화 기록들만 반환
    /// "놓치면 안되는 것들" 섹션에서 사용
    /// - Returns: 중요하다고 표시되고 아직 해결되지 않은 대화 기록들 (최신순)
    func getImportantConversationRecords() -> [ConversationRecord] {
        return conversationRecords
            .filter { $0.isImportant && !$0.isResolved }
            .sorted { $0.createdDate > $1.createdDate }
    }
    
    /// 중요한 기록이 있는지 확인
    /// UI에서 "놓치면 안되는 것들" 섹션을 표시할지 결정할 때 사용
    /// - Returns: 중요한 상호작용이나 미팅 기록이 하나라도 있으면 true
    var hasImportantRecords: Bool {
        return interactionRecords.contains { $0.isImportant } || 
               meetingRecords.contains { $0.isImportant } ||
               conversationRecords.contains { $0.isImportant }
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
        isImportant: Bool = false,
        tags: [String] = [],
        date: Date = Date()
    ) -> ConversationRecord {
        let record = ConversationRecord(
            date: date,
            type: type,
            content: content,
            notes: notes,
            isImportant: isImportant,
            priority: priority,
            tags: tags
        )
        record.person = self
        conversationRecords.append(record)
        
        // 기존 필드들도 호환성을 위해 업데이트
        updateLegacyConversationFields(from: record)
        
        // 중요한 기록이 추가되었을 때 알림 발송
        if isImportant {
            NotificationCenter.default.post(
                name: .importantRecordingAdded,
                object: self
            )
        }
        
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
        record.resolvedDate = Date()
        print("✅ [Conversation] \(record.type.title) 해결됨: \(record.content)")
    }
    
    /// 대화 기록을 미해결 상태로 되돌리기
    /// 해결했다고 표시했던 것을 다시 미해결로 변경할 때 사용
    /// - Parameter record: 미해결로 되돌릴 대화 기록
    func unresolveConversationRecord(_ record: ConversationRecord) {
        record.isResolved = false
        record.resolvedDate = nil
        print("🔄 [Conversation] \(record.type.title) 미해결로 변경됨: \(record.content)")
    }
    
    /// 대화 기록의 내용 수정
    /// - Parameters:
    ///   - record: 수정할 대화 기록
    ///   - newContent: 새로운 내용
    ///   - newNotes: 새로운 메모 (선택사항)
    ///   - newPriority: 새로운 우선순위 (선택사항)
    ///   - newTags: 새로운 태그들 (선택사항)
    func updateConversationRecord(
        _ record: ConversationRecord,
        content newContent: String? = nil,
        notes newNotes: String? = nil,
        priority newPriority: ConversationPriority? = nil,
        tags newTags: [String]? = nil
    ) {
        if let newContent = newContent {
            record.content = newContent
        }
        
        if let newNotes = newNotes {
            record.notes = newNotes
        }
        
        if let newPriority = newPriority {
            record.priority = newPriority
        }
        
        if let newTags = newTags {
            record.tags = newTags
        }
        
        print("🔄 [Conversation] \(record.type.title) 수정됨: \(record.content)")
    }
    
    /// 대화 기록의 타입 변경 (질문 → 고민, 약속 → 질문 등)
    /// - Parameters:
    ///   - record: 수정할 대화 기록
    ///   - newType: 새로운 대화 타입
    func changeConversationRecordType(_ record: ConversationRecord, to newType: ConversationType) {
        let oldType = record.type
        record.type = newType
        print("🔄 [Conversation] 타입 변경: \(oldType.title) → \(newType.title) - \(record.content)")
    }
    
    /// 대화 기록 삭제
    /// - Parameters:
    ///   - record: 삭제할 대화 기록
    ///   - modelContext: SwiftData 모델 컨텍스트
    func deleteConversationRecord(_ record: ConversationRecord, modelContext: ModelContext) {
        if let index = conversationRecords.firstIndex(of: record) {
            conversationRecords.remove(at: index)
            modelContext.delete(record)
            print("🗑️ [Conversation] \(record.type.title) 삭제됨: \(record.content)")
        }
    }
    
    /// ID를 통해 특정 대화 기록 찾기
    /// - Parameter id: 찾을 대화 기록의 UUID
    /// - Returns: 해당하는 ConversationRecord 또는 nil
    func findConversationRecord(by id: UUID) -> ConversationRecord? {
        return conversationRecords.first { $0.id == id }
    }
    
    /// ID를 통해 대화 기록 수정 (편의 메서드)
    /// - Parameters:
    ///   - id: 수정할 대화 기록의 UUID
    ///   - content: 새로운 내용 (선택사항)
    ///   - notes: 새로운 메모 (선택사항)
    ///   - priority: 새로운 우선순위 (선택사항)
    ///   - tags: 새로운 태그들 (선택사항)
    /// - Returns: 수정 성공 여부
    @discardableResult
    func updateConversationRecord(
        withId id: UUID,
        content: String? = nil,
        notes: String? = nil,
        priority: ConversationPriority? = nil,
        tags: [String]? = nil
    ) -> Bool {
        guard let record = findConversationRecord(by: id) else {
            print("❌ [Conversation] ID \(id)에 해당하는 대화 기록을 찾을 수 없음")
            return false
        }
        
        updateConversationRecord(record, content: content, notes: notes, priority: priority, tags: tags)
        return true
    }
    
    /// ID를 통해 대화 기록 해결/미해결 토글
    /// - Parameter id: 토글할 대화 기록의 UUID
    /// - Returns: 변경 후 해결 상태 (성공한 경우)
    @discardableResult
    func toggleConversationRecordResolution(withId id: UUID) -> Bool? {
        guard let record = findConversationRecord(by: id) else {
            print("❌ [Conversation] ID \(id)에 해당하는 대화 기록을 찾을 수 없음")
            return nil
        }
        
        if record.isResolved {
            unresolveConversationRecord(record)
            return false
        } else {
            resolveConversationRecord(record)
            return true
        }
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
    
    /// 미해결 대화 수 (질문, 고민, 약속 모두 포함)
    var currentUnansweredCount: Int {
        return conversationRecords
            .filter { !$0.isResolved && ($0.type == .question || $0.type == .concern || $0.type == .promise) }
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
    
    /// 최근 받은 질문들 (질문 타입만 포함)
    var allReceivedQuestions: [String] {
        return conversationRecords
            .filter { $0.type == .question }
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
    
    /// 모든 상호작용 중 가장 최근 날짜
    /// 멘토링, 식사, 연락 등 모든 실제 접촉점 중 가장 최신을 반환
    var mostRecentInteractionDate: Date? {
        let allInteractionDates = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
        
        // InteractionRecord들의 날짜도 포함
        let recordDates = interactionRecords.map { $0.date }
        
        // 모든 날짜를 합쳐서 가장 최근 것을 찾기
        let allDates = allInteractionDates + recordDates
        return allDates.max()
    }
    
    /// 소홀함 상태 (자동 계산됨)
    /// 고민이 방치되거나, 중요한 액션이 놓치거나, 오래 연락이 없는 경우 true
        var isNeglected: Bool {
        let now = Date()
        let calendar = Calendar.current
        
        // 1. 고민이 있는데 1주일 이상 방치된 경우
        let unresolvedConcerns = conversationRecords.filter { 
            $0.type == .concern && !$0.isResolved 
        }
        for concern in unresolvedConcerns {
            let daysSinceConcern = calendar.dateComponents([.day], from: concern.createdDate, to: now).day ?? 0
            if daysSinceConcern >= 7 {
                return true
            }
        }
        
        // 2. 긴급/높은 우선순위 약속이 3일 이상 방치된 경우
        let highPriorityPromises = conversationRecords.filter { 
            $0.type == .promise && !$0.isResolved && 
            ($0.priority == .urgent || $0.priority == .high)
        }
        for promise in highPriorityPromises {
            let daysSincePromise = calendar.dateComponents([.day], from: promise.createdDate, to: now).day ?? 0
            if daysSincePromise >= 3 {
                return true
            }
        }
        
        // 3. 중요 액션이 리마인더 날짜를 1일 이상 지난 경우
        let today = calendar.startOfDay(for: now)
        let overdueCriticalActions = actions.filter { action in
            guard !action.isCompleted,
                  action.action?.type == .critical,
                  let reminderDate = action.reminderDate else {
                return false
            }
            let reminderDay = calendar.startOfDay(for: reminderDate)
            return reminderDay < today
        }
        if !overdueCriticalActions.isEmpty {
            return true
        }
        
        // 4. 마지막 상호작용이 3주 이상 지난 경우
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        if daysSinceLastInteraction >= 21 {
            return true
        }
        
        // 5. 미해결 질문이 5개 이상 누적된 경우
        let unresolvedQuestions = conversationRecords.filter { 
            $0.type == .question && !$0.isResolved 
        }.count
        if unresolvedQuestions >= 5 {
            return true
        }
        
        return false
    }
    
    /**
     1. 고민 방치 (7일 기준)
     • 미해결된 고민(concern)이 1주일(7일) 이상 방치된 경우
     • 상대방의 고민을 들었지만 해결되지 않은 채로 오래 놔둔 상황

     2. 긴급/중요 약속 방치 (3일 기준)
     • 긴급(urgent) 또는 높은 우선순위(high) 약속이 3일 이상 방치된 경우
     • 중요한 약속을 지키지 않거나 연기하고 있는 상황

     3. 중요 액션 지연 (1일 기준)
     • 중요(critical) 액션의 리마인더 날짜를 1일 이상 지난 경우
     • 해야 할 중요한 일들을 미루고 있는 상황

     4. 장기간 접촉 없음 (21일 기준)
     • 마지막 상호작용(멘토링, 식사, 연락)이 3주(21일) 이상 지난 경우
     • 너무 오랫동안 연락하지 않은 상황

     5. 미해결 질문 누적 (5개 기준)
     • 미해결된 질문이 5개 이상 누적된 경우
     • 상대방에게 물어본 것들에 대한 답을 받지 못한 상황
     */
    
    /// 소홀함의 이유를 설명하는 텍스트
    var neglectedReason: String {
        if !isNeglected {
            return "관계가 잘 관리되고 있습니다. 계속 이런 상태를 유지해보세요!"
        }
        
        let now = Date()
        let calendar = Calendar.current
        var reasons: [String] = []
        
        // 1. 고민 방치 체크
        let unresolvedConcerns = conversationRecords.filter { 
            $0.type == .concern && !$0.isResolved 
        }
        let oldConcerns = unresolvedConcerns.filter { concern in
            let daysSince = calendar.dateComponents([.day], from: concern.createdDate, to: now).day ?? 0
            return daysSince >= 7
        }
        if !oldConcerns.isEmpty {
            reasons.append("🧠 \(oldConcerns.count)개의 고민이 1주일 이상 방치됨")
        }
        
        // 2. 높은 우선순위 약속 방치 체크
        let highPriorityPromises = conversationRecords.filter { 
            $0.type == .promise && !$0.isResolved && 
            ($0.priority == .urgent || $0.priority == .high)
        }
        let oldPromises = highPriorityPromises.filter { promise in
            let daysSince = calendar.dateComponents([.day], from: promise.createdDate, to: now).day ?? 0
            return daysSince >= 3
        }
        if !oldPromises.isEmpty {
            reasons.append("🤝 중요한 약속 \(oldPromises.count)개가 3일 이상 방치됨")
        }
        
        // 3. 중요 액션 놓침 체크
        let today = calendar.startOfDay(for: now)
        let overdueCriticalActions = actions.filter { action in
            guard !action.isCompleted,
                  action.action?.type == .critical,
                  let reminderDate = action.reminderDate else {
                return false
            }
            let reminderDay = calendar.startOfDay(for: reminderDate)
            let daysPastDue = calendar.dateComponents([.day], from: reminderDay, to: today).day ?? 0
            return daysPastDue > 0
        }
        if !overdueCriticalActions.isEmpty {
            let maxOverdue = overdueCriticalActions.compactMap { action -> Int? in
                guard let reminderDate = action.reminderDate else { return nil }
                let reminderDay = calendar.startOfDay(for: reminderDate)
                return calendar.dateComponents([.day], from: reminderDay, to: today).day
            }.max() ?? 0
            reasons.append("⚠️ 중요 액션 \(overdueCriticalActions.count)개가 최대 \(maxOverdue)일 지남")
        }
        
        // 4. 장기간 연락 없음 체크
        let recentInteractionDate = [lastContact, lastMeal, lastMentoring]
            .compactMap { $0 }
            .max() ?? relationshipStartDate
        let daysSinceLastInteraction = calendar.dateComponents([.day], from: recentInteractionDate, to: now).day ?? 0
        if daysSinceLastInteraction >= 21 {
            reasons.append("📞 마지막 상호작용이 \(daysSinceLastInteraction)일 전")
        }
        
        // 5. 미해결 질문 누적 체크
        let unresolvedQuestions = conversationRecords.filter { 
            $0.type == .question && !$0.isResolved 
        }.count
        if unresolvedQuestions >= 5 {
            reasons.append("❓ 미해결 질문이 \(unresolvedQuestions)개 누적됨")
        }
        
        if reasons.isEmpty {
            return "관계 관리에 약간의 주의가 필요합니다."
        } else {
            return reasons.joined(separator: "\n")
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


// MARK: - Timeline Support
extension Person {
    /// 모든 타임라인 아이템 가져오기 (필터링 및 중요도 옵션 포함)
    /// - Parameters:
    ///   - filter: 표시할 기록 타입 (기본값: 전체)
    ///   - importantOnly: true면 중요 표시된 항목만 (기본값: false)
    /// - Returns: 날짜 내림차순으로 정렬된 타임라인 아이템 배열
    func getAllTimelineItems(filter: TimelineFilter = .all, importantOnly: Bool = false) -> [TimelineItem] {
        var items: [TimelineItem] = []

        // 1. 상호작용 기록
        if filter.includes(.interaction) {
            let interactions = getAllInteractionRecordsSorted()
                .filter { !importantOnly || $0.isImportant }
                .map { TimelineItem(type: .interaction($0)) }
            items.append(contentsOf: interactions)
        }

        // 2. 미팅 기록
        if filter.includes(.meeting) {
            let meetings = meetingRecords
                .filter { !importantOnly || $0.isImportant }
                .sorted { $0.date > $1.date }
                .map { TimelineItem(type: .meeting($0)) }
            items.append(contentsOf: meetings)
        }

        // 3. 대화 기록
        if filter.includes(.conversation) {
            let conversations = getAllConversationRecordsSorted()
                .filter { !importantOnly || $0.isImportant }
                .map { TimelineItem(type: .conversation($0)) }
            items.append(contentsOf: conversations)
        }

        // 4. 빠른 메모 아카이브
        if filter.includes(.memo) {
            let memos = archivedMemos
                .sorted { $0.createdDate > $1.createdDate }
                .map { TimelineItem(type: .memo($0)) }
            items.append(contentsOf: memos)
        }

        // 5. 액션 아이템 (날짜가 있는 것만)
        if filter.includes(.action) {
            let actions = actions
                .filter { action in
                    let hasDate = action.completedDate != nil ||
                                  action.lastActionDate != nil ||
                                  action.reminderDate != nil
                    let matchesImportant = !importantOnly || action.action?.type == .critical
                    return hasDate && matchesImportant
                }
                .sorted {
                    let date1 = $0.completedDate ?? $0.lastActionDate ?? $0.reminderDate ?? Date.distantPast
                    let date2 = $1.completedDate ?? $1.lastActionDate ?? $1.reminderDate ?? Date.distantPast
                    return date1 > date2
                }
                .map { TimelineItem(type: .action($0)) }
            items.append(contentsOf: actions)
        }

        // 전체 아이템을 날짜 내림차순으로 정렬 (최신 우선)
        return items.sorted { $0.date > $1.date }
    }

    /// 날짜별로 그룹화된 타임라인 아이템 가져오기
    /// - Parameters:
    ///   - filter: 표시할 기록 타입 (기본값: 전체)
    ///   - importantOnly: true면 중요 표시된 항목만 (기본값: false)
    /// - Returns: 날짜 그룹별로 정리된 GroupedTimelineItems 배열
    func getGroupedTimelineItems(filter: TimelineFilter = .all, importantOnly: Bool = false) -> [GroupedTimelineItems] {
        return getAllTimelineItems(filter: filter, importantOnly: importantOnly)
            .groupedByDate()
    }
}

/// 타임라인 필터 옵션
struct TimelineFilter: OptionSet {
    let rawValue: Int

    static let interaction = TimelineFilter(rawValue: 1 << 0)
    static let meeting = TimelineFilter(rawValue: 1 << 1)
    static let conversation = TimelineFilter(rawValue: 1 << 2)
    static let memo = TimelineFilter(rawValue: 1 << 3)
    static let action = TimelineFilter(rawValue: 1 << 4)

    static let all: TimelineFilter = [.interaction, .meeting, .conversation, .memo, .action]

    /// 특정 필터가 포함되어 있는지 확인
    func includes(_ filter: TimelineFilter) -> Bool {
        return self.contains(filter)
    }

    /// 필터 표시 이름
    var displayName: String {
        if self == .all { return "전체" }
        if self == .interaction { return "상호작용" }
        if self == .meeting { return "미팅" }
        if self == .conversation { return "대화" }
        if self == .memo { return "메모" }
        if self == .action { return "액션" }
        return "필터"
    }
}

// MARK: - Badge Support
extension Person {
    /// 미완료 액션 개수
    var incompleteActionsCount: Int {
        return actions.filter { $0.completedDate == nil }.count
    }

    /// 중요 표시된 아이템 개수 (모든 기록 타입 포함)
    var importantItemsCount: Int {
        var count = 0

        // 상호작용 기록
        count += getAllInteractionRecordsSorted().filter { $0.isImportant }.count

        // 미팅 기록
        count += meetingRecords.filter { $0.isImportant }.count

        // 대화 기록
        count += conversationRecords.filter { $0.isImportant }.count

        return count
    }

    /// 크리티컬 액션 개수 (미완료만)
    var criticalActionsCount: Int {
        return actions.filter {
            $0.completedDate == nil && $0.action?.type == .critical
        }.count
    }

    /// 총 배지 카운트 (표시할 알림 개수)
    var totalBadgeCount: Int {
        return incompleteActionsCount + importantItemsCount
    }

    /// 배지가 있는지 여부
    var hasBadges: Bool {
        return totalBadgeCount > 0
    }

    /// 타임라인 탭 뱃지 카운트 (중요 항목)
    var timelineBadgeCount: Int {
        return importantItemsCount
    }

    /// 활동 탭 뱃지 카운트 (미완료 액션)
    var actionsBadgeCount: Int {
        return incompleteActionsCount
    }

    /// 뱃지 상세 정보 (알림 버튼용)
    struct BadgeDetail: Identifiable {
        let id = UUID()
        let category: String
        let count: Int
        let description: String
        let tabIndex: Int
        let color: Color
    }

    /// 모든 뱃지 상세 정보 가져오기
    func getBadgeDetails() -> [BadgeDetail] {
        var details: [BadgeDetail] = []

        // 크리티컬 액션
        if criticalActionsCount > 0 {
            details.append(BadgeDetail(
                category: "긴급 액션",
                count: criticalActionsCount,
                description: "즉시 처리가 필요한 긴급 액션",
                tabIndex: 0,
                color: .red
            ))
        }

        // 미완료 액션
        if incompleteActionsCount > 0 {
            details.append(BadgeDetail(
                category: "미완료 액션",
                count: incompleteActionsCount,
                description: "아직 완료하지 않은 액션",
                tabIndex: 0,
                color: .blue
            ))
        }

        // 중요 항목
        if importantItemsCount > 0 {
            details.append(BadgeDetail(
                category: "중요 항목",
                count: importantItemsCount,
                description: "중요 표시된 상호작용, 미팅, 대화",
                tabIndex: 1,
                color: .yellow
            ))
        }

        return details
    }
}
