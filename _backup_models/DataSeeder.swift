//
//  DataSeeder.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation
import SwiftData

@MainActor
class DataSeeder {
    
    /// 기존 데이터의 한국어 ActionType을 영어로 마이그레이션
    static func migrateKoreanActionTypes(context: ModelContext) {
        // 마이그레이션이 이미 완료되었는지 확인
        let migrationKey = "ActionTypeMigrationCompleted"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return
        }
        
        print("🔄 ActionType 마이그레이션 시작...")
        
        do {
            // 모든 RapportAction을 가져와서 수동으로 마이그레이션
            let allActions = try context.fetch(FetchDescriptor<RapportAction>())
            var migrationCount = 0
            
            for action in allActions {
                // SwiftData에서는 enum 값을 직접 변경하기 어려우므로
                // 새로운 액션으로 교체하는 방식 사용
                let currentTypeString = action.type.rawValue
                
                let newType: ActionType
                switch currentTypeString {
                case "크리티컬", "중요":
                    newType = .critical
                    migrationCount += 1
                case "정보수집":
                    newType = .tracking
                    migrationCount += 1
                case "관계유지":
                    newType = .maintenance
                    migrationCount += 1
                default:
                    continue // 이미 영어 값이면 건너뛰기
                }
                
                // 새로운 액션 생성 (기존 값 복사)
                let newAction = RapportAction(
                    id: action.id,
                    title: action.title,
                    actionDescription: action.actionDescription,
                    phase: action.phase,
                    type: newType,
                    order: action.order,
                    isDefault: action.isDefault,
                    isActive: action.isActive,
                    placeholder: action.placeholder
                )
                
                // 기존 PersonAction들을 새로운 액션으로 연결
                let personActions = action.personActions
                for personAction in personActions {
                    personAction.action = newAction
                }
                
                // 기존 액션 삭제 후 새로운 액션 삽입
                context.delete(action)
                context.insert(newAction)
            }
            
            try context.save()
            
            // 마이그레이션 완료 플래그 설정
            UserDefaults.standard.set(true, forKey: migrationKey)
            
            print("✅ ActionType 마이그레이션 완료: \(migrationCount)개 변경됨")
            
        } catch {
            print("❌ ActionType 마이그레이션 실패: \(error)")
        }
    }
    
    /// 모든 기본 액션을 삭제하고 다시 생성 (데이터 문제 해결용)
    static func resetDefaultActions(context: ModelContext) {
        print("🔥 기본 액션들을 모두 삭제하고 다시 생성합니다...")
        
        do {
            // 모든 기본 액션들 삭제
            let allDefaultActions = try context.fetch(FetchDescriptor<RapportAction>(
                predicate: #Predicate { $0.isDefault == true }
            ))
            
            for action in allDefaultActions {
                context.delete(action)
            }
            
            try context.save()
            print("🗑️ 기존 기본 액션 \(allDefaultActions.count)개 삭제 완료")
            
            // 새로운 기본 액션 30개 생성
            let defaultActions = RapportAction.createDefaultActions()
            for action in defaultActions {
                context.insert(action)
            }
            
            try context.save()
            print("✅ 새로운 기본 액션 30개 생성 완료")
            
            // 모든 Person들의 액션도 다시 생성
            let allPeople = try context.fetch(FetchDescriptor<Person>())
            for person in allPeople {
                // 기존 PersonAction들 삭제
                for personAction in person.actions {
                    context.delete(personAction)
                }
                
                // 새로운 PersonAction들 생성
                createPersonActionsForNewPerson(person: person, context: context)
            }
            
            try context.save()
            print("✅ 모든 사람들의 액션도 다시 생성 완료")
            
        } catch {
            print("❌ 기본 액션 리셋 실패: \(error)")
        }
    }
    
    /// 기본 액션이 없으면 30개를 생성
    static func seedDefaultActionsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.isDefault == true }
        )
        
        do {
            let existingActions = try context.fetch(descriptor)
            
            // 기본 액션이 30개 미만이거나 "개인적 맥락 파악" 단계 액션이 없으면 리셋
            let phase3Actions = existingActions.filter { $0.phase == .personal }
            
            if existingActions.count < 30 || phase3Actions.isEmpty {
                print("⚠️ 기본 액션이 불완전합니다 (현재: \(existingActions.count)개, Phase3: \(phase3Actions.count)개)")
                print("🔄 기본 액션을 다시 생성합니다...")
                
                // 모든 기존 기본 액션 삭제
                for action in existingActions {
                    context.delete(action)
                }
                
                // 새로운 기본 액션 30개 생성
                let defaultActions = RapportAction.createDefaultActions()
                for action in defaultActions {
                    context.insert(action)
                }
                
                try context.save()
                print("✅ 기본 액션 30개를 새로 생성했습니다")
                return
            }
            
            print("✅ 기본 액션들이 완전히 존재합니다 (\(existingActions.count)개)")
            
        } catch {
            print("❌ 기본 액션 확인/생성 실패: \(error)")
        }
    }
    
    /// 새로운 Person을 생성할 때 해당 Person의 액션 인스턴스들도 함께 생성
    static func createPersonActionsForNewPerson(person: Person, context: ModelContext) {
        print("🔧 [DataSeeder] createPersonActionsForNewPerson 시작 - \(person.name)")
        
        // 이미 PersonAction이 있으면 스킵 (중복 방지)
        if !person.actions.isEmpty {
            print("🔧 [DataSeeder] 이미 PersonAction이 존재함 (\(person.actions.count)개) - 스킵")
            return
        }
        
        let descriptor = FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        do {
            let allActions = try context.fetch(descriptor)
            print("🔧 [DataSeeder] 활성 액션 \(allActions.count)개 발견")
            
            if allActions.isEmpty {
                print("🔧 [DataSeeder] 활성 액션이 없음 - 기본 액션 먼저 생성")
                seedDefaultActionsIfNeeded(context: context)
                
                // 다시 시도
                let retryAllActions = try context.fetch(descriptor)
                print("🔧 [DataSeeder] 재시도 후 활성 액션 \(retryAllActions.count)개 발견")
                
                for action in retryAllActions {
                    let personAction = PersonAction(
                        person: person,
                        action: action,
                        isVisibleInDetail: false // 기본적으로 PersonDetailView에 표시하지 않음
                    )
                    context.insert(personAction)
                }
            } else {
                for action in allActions {
                    let personAction = PersonAction(
                        person: person,
                        action: action,
                        isVisibleInDetail: false // 기본적으로 PersonDetailView에 표시하지 않음
                    )
                    context.insert(personAction)
                }
            }
            
            // PersonContext 기본 템플릿도 생성
            PersonContext.createDefaultContextsForPerson(person: person, context: context)
            
            try context.save()
            print("✅ \(person.name)님의 액션 \(allActions.count)개와 컨텍스트 템플릿을 생성했습니다")
            
        } catch {
            print("❌ Person 액션 생성 실패: \(error)")
            
            // 에러가 발생해도 기본 액션들은 시도해보자
            do {
                seedDefaultActionsIfNeeded(context: context)
                try context.save()
                print("🔄 기본 액션 생성 후 재시도")
                // 재귀 호출 (무한루프 방지를 위해 한번만)
                createPersonActionsForNewPerson(person: person, context: context)
            } catch {
                print("❌ 재시도도 실패: \(error)")
            }
        }
    }
    
    /// 기존 Person들의 String 필드를 PersonContext로 마이그레이션
    static func migratePersonStringFieldsToContexts(context: ModelContext) {
        let migrationKey = "PersonContextMigrationCompleted"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("✅ PersonContext 마이그레이션이 이미 완료되었습니다")
            return
        }

        print("🔄 PersonContext 마이그레이션 시작...")

        do {
            let allPeople = try context.fetch(FetchDescriptor<Person>())
            var migrationCount = 0

            for person in allPeople {
                person.migrateStringFieldsToContexts(modelContext: context)
                migrationCount += 1
            }

            try context.save()

            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ PersonContext 마이그레이션 완료: \(migrationCount)명 처리됨")

        } catch {
            print("❌ PersonContext 마이그레이션 실패: \(error)")
        }
    }

    // seedDummyData는 아래 "개발용 더미 데이터" 섹션에 정의됨
    
    // MARK: - 태그 시스템
    
    /// 기본 태그가 없으면 프리셋 태그들을 생성
    static func seedDefaultTagsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<PersonTag>()
        
        do {
            let existingTags = try context.fetch(descriptor)
            
            // 태그가 없으면 기본 태그 생성
            if existingTags.isEmpty {
                print("🏷️ 기본 태그가 없습니다. 프리셋 태그를 생성합니다...")
                
                let defaultTags = PersonTag.createDefaultTags()
                for tag in defaultTags {
                    context.insert(tag)
                }
                
                try context.save()
                print("✅ 기본 태그 \(defaultTags.count)개를 생성했습니다")
            } else {
                print("✅ 기존 태그가 있습니다 (\(existingTags.count)개)")
            }
            
        } catch {
            print("❌ 태그 확인/생성 실패: \(error)")
        }
    }
    
    /// 모든 태그를 삭제하고 기본 태그로 리셋
    static func resetDefaultTags(context: ModelContext) {
        print("🔥 모든 태그를 삭제하고 기본 태그로 리셋합니다...")
        
        do {
            // 기존 태그 모두 삭제
            let existingTags = try context.fetch(FetchDescriptor<PersonTag>())
            for tag in existingTags {
                context.delete(tag)
            }
            
            try context.save()
            print("🗑️ 기존 태그 \(existingTags.count)개 삭제 완료")
            
            // 새 기본 태그 생성
            let defaultTags = PersonTag.createDefaultTags()
            for tag in defaultTags {
                context.insert(tag)
            }
            
            try context.save()
            print("✅ 새로운 기본 태그 \(defaultTags.count)개 생성 완료")
            
        } catch {
            print("❌ 태그 리셋 실패: \(error)")
        }
    }
    
    // MARK: - Record 통합 마이그레이션
    
    /// 기존 4개 기록 모델을 새로운 통합 Record 모델로 마이그레이션
    /// - InteractionRecord → Record (contactType 매핑)
    /// - ConversationRecord → Record (tags로 변환)
    /// - MeetingRecord → Record (음성파일 포함)
    /// - QuickMemoArchive → Record (content로)
    static func migrateToUnifiedRecords(context: ModelContext) {
        let migrationKey = "UnifiedRecordMigrationCompleted_v1"
        if UserDefaults.standard.bool(forKey: migrationKey) {
            print("✅ 통합 Record 마이그레이션이 이미 완료되었습니다")
            return
        }
        
        print("🔄 통합 Record 마이그레이션 시작...")
        
        do {
            var totalMigrated = 0
            
            // 1. InteractionRecord → Record
            let interactionMigrated = migrateInteractionRecords(context: context)
            totalMigrated += interactionMigrated
            
            // 2. ConversationRecord → Record
            let conversationMigrated = migrateConversationRecords(context: context)
            totalMigrated += conversationMigrated
            
            // 3. MeetingRecord → Record
            let meetingMigrated = migrateMeetingRecords(context: context)
            totalMigrated += meetingMigrated
            
            // 4. QuickMemoArchive → Record
            let memoMigrated = migrateQuickMemoArchives(context: context)
            totalMigrated += memoMigrated
            
            try context.save()
            
            UserDefaults.standard.set(true, forKey: migrationKey)
            print("✅ 통합 Record 마이그레이션 완료: 총 \(totalMigrated)개 기록 변환됨")
            print("   - InteractionRecord: \(interactionMigrated)개")
            print("   - ConversationRecord: \(conversationMigrated)개")
            print("   - MeetingRecord: \(meetingMigrated)개")
            print("   - QuickMemoArchive: \(memoMigrated)개")
            
        } catch {
            print("❌ 통합 Record 마이그레이션 실패: \(error)")
        }
    }
    
    /// InteractionRecord → Record 변환
    private static func migrateInteractionRecords(context: ModelContext) -> Int {
        do {
            let interactions = try context.fetch(FetchDescriptor<InteractionRecord>())
            var count = 0
            
            for interaction in interactions {
                // InteractionType → ContactType 매핑
                let contactType: ContactType? = {
                    switch interaction.type {
                    case .meal:
                        return .meal
                    case .call:
                        return .call
                    case .message:
                        return .message
                    case .meeting, .mentoring, .contact:
                        return .meeting
                    case .quickNote:
                        return nil  // quickNote는 contactType 없이 메모로
                    }
                }()
                
                // 태그 결정
                var tags: [RecordTag] = []
                if interaction.isImportant {
                    tags.append(.important)
                }
                // 멘토링인 경우 피드백 태그 추가
                if interaction.type == .mentoring {
                    tags.append(.feedback)
                }
                
                let record = Record(
                    id: UUID(),
                    date: interaction.date,
                    contactType: contactType,
                    content: interaction.notes ?? "\(interaction.type.title) 기록",
                    notes: nil,
                    tags: tags,
                    isResolved: false,
                    isImportant: interaction.isImportant,
                    duration: interaction.duration,
                    location: interaction.location,
                    audioFileName: interaction.relatedMeetingRecord?.audioFileURL,
                    transcription: interaction.relatedMeetingRecord?.transcribedText,
                    imageDataArray: interaction.allPhotosData.isEmpty ? nil : interaction.allPhotosData,
                    createdDate: interaction.date,
                    migratedFrom: "InteractionRecord",
                    originalId: interaction.id
                )
                
                record.person = interaction.person
                context.insert(record)
                
                // Person의 records 배열에도 추가
                if let person = interaction.person {
                    person.records.append(record)
                }
                
                count += 1
            }
            
            print("   ✅ InteractionRecord \(count)개 변환 완료")
            return count
            
        } catch {
            print("   ❌ InteractionRecord 마이그레이션 실패: \(error)")
            return 0
        }
    }
    
    /// ConversationRecord → Record 변환
    private static func migrateConversationRecords(context: ModelContext) -> Int {
        do {
            let conversations = try context.fetch(FetchDescriptor<ConversationRecord>())
            var count = 0
            
            for conversation in conversations {
                // ConversationType → RecordTag 매핑
                var tags: [RecordTag] = []
                switch conversation.type {
                case .question:
                    tags.append(.question)
                case .concern:
                    tags.append(.concern)
                case .promise:
                    tags.append(.promise)
                case .feedback:
                    tags.append(.feedback)
                case .achievement:
                    tags.append(.achievement)
                case .update:
                    // update는 특별한 태그 없음
                    break
                }
                
                if conversation.isImportant {
                    tags.append(.important)
                }
                
                let record = Record(
                    id: UUID(),
                    date: conversation.date,
                    contactType: nil,  // ConversationRecord는 contactType 없음
                    content: conversation.content,
                    notes: conversation.notes,
                    tags: tags,
                    isResolved: conversation.isResolved,
                    isImportant: conversation.isImportant,
                    duration: nil,
                    location: nil,
                    audioFileName: nil,
                    transcription: nil,
                    imageDataArray: conversation.imageDataArray,
                    createdDate: conversation.createdDate,
                    resolvedDate: conversation.resolvedDate,
                    migratedFrom: "ConversationRecord",
                    originalId: conversation.id
                )
                
                record.person = conversation.person
                context.insert(record)
                
                if let person = conversation.person {
                    person.records.append(record)
                }
                
                count += 1
            }
            
            print("   ✅ ConversationRecord \(count)개 변환 완료")
            return count
            
        } catch {
            print("   ❌ ConversationRecord 마이그레이션 실패: \(error)")
            return 0
        }
    }
    
    /// MeetingRecord → Record 변환
    private static func migrateMeetingRecords(context: ModelContext) -> Int {
        do {
            let meetings = try context.fetch(FetchDescriptor<MeetingRecord>())
            var count = 0
            
            for meeting in meetings {
                // MeetingType → ContactType 매핑
                let contactType: ContactType = {
                    switch meeting.meetingType {
                    case .meal:
                        return .meal
                    case .coffee:
                        return .meal  // 커피도 식사로 분류
                    case .mentoring, .oneOnOne, .presentation, .general:
                        return .meeting
                    }
                }()
                
                // 태그 결정
                var tags: [RecordTag] = []
                if meeting.isImportant {
                    tags.append(.important)
                }
                if meeting.meetingType == .mentoring {
                    tags.append(.feedback)
                }
                
                // 약속들을 태그로 추가
                if !meeting.mentorPromises.isEmpty || !meeting.menteePromises.isEmpty {
                    tags.append(.promise)
                }
                
                // 내용 구성
                var content = meeting.summary.isEmpty ? "\(meeting.meetingType.rawValue) 미팅" : meeting.summary
                
                // 약속과 액션 아이템이 있으면 notes에 추가
                var notesComponents: [String] = []
                if !meeting.mentorPromises.isEmpty {
                    notesComponents.append("멘토 약속: \(meeting.mentorPromises.joined(separator: ", "))")
                }
                if !meeting.menteePromises.isEmpty {
                    notesComponents.append("멘티 약속: \(meeting.menteePromises.joined(separator: ", "))")
                }
                if !meeting.actionItems.isEmpty {
                    notesComponents.append("액션 아이템: \(meeting.actionItems.joined(separator: ", "))")
                }
                let notes = notesComponents.isEmpty ? nil : notesComponents.joined(separator: "\n")
                
                let record = Record(
                    id: UUID(),
                    date: meeting.date,
                    contactType: contactType,
                    content: content,
                    notes: notes,
                    tags: tags,
                    isResolved: meeting.workflowStatus == .completed,
                    isImportant: meeting.isImportant,
                    duration: meeting.duration,
                    location: nil,
                    audioFileName: meeting.audioFileURL,
                    transcription: meeting.transcribedText.isEmpty ? meeting.diarizedText : meeting.transcribedText,
                    imageDataArray: nil,
                    createdDate: meeting.date,
                    resolvedDate: meeting.workflowCompletedDate,
                    migratedFrom: "MeetingRecord",
                    originalId: meeting.id
                )
                
                record.person = meeting.person
                context.insert(record)
                
                if let person = meeting.person {
                    person.records.append(record)
                }
                
                count += 1
            }
            
            print("   ✅ MeetingRecord \(count)개 변환 완료")
            return count
            
        } catch {
            print("   ❌ MeetingRecord 마이그레이션 실패: \(error)")
            return 0
        }
    }
    
    /// QuickMemoArchive → Record 변환
    private static func migrateQuickMemoArchives(context: ModelContext) -> Int {
        do {
            let memos = try context.fetch(FetchDescriptor<QuickMemoArchive>())
            var count = 0
            
            for memo in memos {
                let record = Record(
                    id: UUID(),
                    date: memo.createdDate,
                    contactType: nil,  // 메모는 contactType 없음
                    content: memo.content,
                    notes: nil,
                    tags: [],
                    isResolved: false,
                    isImportant: false,
                    duration: nil,
                    location: nil,
                    audioFileName: nil,
                    transcription: nil,
                    imageDataArray: memo.imageDataArray,
                    createdDate: memo.createdDate,
                    migratedFrom: "QuickMemoArchive",
                    originalId: memo.id
                )
                
                record.person = memo.person
                context.insert(record)
                
                if let person = memo.person {
                    person.records.append(record)
                }
                
                count += 1
            }
            
            print("   ✅ QuickMemoArchive \(count)개 변환 완료")
            return count
            
        } catch {
            print("   ❌ QuickMemoArchive 마이그레이션 실패: \(error)")
            return 0
        }
    }
    
    /// 마이그레이션 리셋 (개발/디버깅용)
    static func resetUnifiedRecordMigration() {
        let migrationKey = "UnifiedRecordMigrationCompleted_v1"
        UserDefaults.standard.removeObject(forKey: migrationKey)
        print("🔄 통합 Record 마이그레이션 플래그 리셋 완료")
    }
    
    // MARK: - 개발용 더미 데이터
    
    /// 더미 데이터 ID를 저장하는 키
    private static let dummyPersonIdsKey = "DummyPersonIds"
    
    /// 저장된 더미 Person ID들 가져오기
    private static func getDummyPersonIds() -> [String] {
        UserDefaults.standard.stringArray(forKey: dummyPersonIdsKey) ?? []
    }
    
    /// 더미 Person ID들 저장하기
    private static func saveDummyPersonIds(_ ids: [UUID]) {
        let stringIds = ids.map { $0.uuidString }
        UserDefaults.standard.set(stringIds, forKey: dummyPersonIdsKey)
    }
    
    /// 더미 Person ID들 초기화
    private static func clearDummyPersonIds() {
        UserDefaults.standard.removeObject(forKey: dummyPersonIdsKey)
    }
    
    /// 개발/테스트용 더미 데이터 생성
    static func seedDummyData(context: ModelContext) {
        print("🎭 더미 데이터 생성 시작...")
        
        // 1. 태그 먼저 확보
        var tags: [PersonTag] = []
        do {
            tags = try context.fetch(FetchDescriptor<PersonTag>())
            if tags.isEmpty {
                seedDefaultTagsIfNeeded(context: context)
                tags = try context.fetch(FetchDescriptor<PersonTag>())
            }
        } catch {
            print("   ⚠️ 태그 로드 실패: \(error)")
        }
        
        // 태그 찾기 헬퍼
        func findTag(_ name: String) -> PersonTag? {
            tags.first { $0.name == name }
        }
        
        // 2. 더미 멘티 데이터 (5명)
        let dummyPeople: [(name: String, contact: String, tagNames: [String], status: String)] = [
            ("김민준", "010-1234-5678", ["1기", "개발", "활발"], "active"),
            ("이서연", "010-2345-6789", ["1기", "디자인", "활발"], "active"),
            ("박지훈", "010-3456-7890", ["1기", "개발", "정체"], "stale"),
            ("최수아", "010-4567-8901", ["2기", "PM", "활발"], "active"),
            ("정예준", "010-5678-9012", ["2기", "개발", "위험"], "danger"),
        ]
        
        var createdPeople: [Person] = []
        
        for data in dummyPeople {
            let person = Person(
                name: data.name,
                contact: data.contact,
                relationshipStartDate: Calendar.current.date(byAdding: .month, value: -Int.random(in: 1...12), to: Date()) ?? Date()
            )
            
            // 태그 추가
            for tagName in data.tagNames {
                if let tag = findTag(tagName) {
                    person.tags.append(tag)
                }
            }
            
            context.insert(person)
            createdPeople.append(person)
        }
        
        print("   ✅ \(createdPeople.count)명 Person 생성")
        
        // 3. 각 Person에 Record 추가
        let now = Date()
        var totalRecords = 0
        
        for (index, person) in createdPeople.enumerated() {
            let status = dummyPeople[index].status
            let recordCount: Int
            
            switch status {
            case "active":
                recordCount = Int.random(in: 5...10)
            case "stale":
                recordCount = Int.random(in: 2...4)
            case "danger":
                recordCount = Int.random(in: 0...2)
            default:
                recordCount = 3
            }
            
            for i in 0..<recordCount {
                let daysAgo: Int
                switch status {
                case "active":
                    daysAgo = Int.random(in: 0...14)
                case "stale":
                    daysAgo = Int.random(in: 14...30)
                case "danger":
                    daysAgo = Int.random(in: 30...60)
                default:
                    daysAgo = Int.random(in: 0...30)
                }
                
                let recordDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now) ?? now
                
                // 랜덤 접촉 타입
                let contactTypes: [ContactType?] = [.meeting, .meal, .call, .message, nil]
                let contactType = contactTypes.randomElement() ?? nil
                
                // 랜덤 내용
                let contents = generateRandomContent(contactType: contactType, personName: person.name)
                
                // 랜덤 태그
                var recordTags: [RecordTag] = []
                if Bool.random() { recordTags.append([.promise, .question, .concern].randomElement()!) }
                if Bool.random() && Bool.random() { recordTags.append(.important) }
                
                let record = Record(
                    date: recordDate,
                    contactType: contactType,
                    content: contents,
                    tags: recordTags,
                    isResolved: recordTags.isEmpty ? false : Bool.random(),
                    isImportant: recordTags.contains(.important),
                    duration: contactType == .meeting || contactType == .meal ? TimeInterval(Int.random(in: 30...120) * 60) : nil,
                    location: contactType == .meeting || contactType == .meal ? ["강남역 카페", "회사 회의실", "홍대 식당", "온라인"].randomElement() : nil
                )
                
                record.person = person
                context.insert(record)
                person.records.append(record)
                totalRecords += 1
            }
            
            // 마지막 상호작용 날짜 업데이트
            if let lastRecord = person.records.sorted(by: { $0.date > $1.date }).first {
                person.lastContact = lastRecord.date
                if lastRecord.contactType == .meal {
                    person.lastMeal = lastRecord.date
                }
                if lastRecord.contactType == .meeting {
                    person.lastMentoring = lastRecord.date
                }
            }
        }
        
        print("   ✅ \(totalRecords)개 Record 생성")
        
        // 4. ConversationRecord 추가 (약속, 고민, 질문)
        var conversationCount = 0
        
        // 다양한 케이스를 위한 시나리오 (5명 기준: 인덱스 0-4)
        let conversationScenarios: [(personIndex: Int, type: ConversationType, content: String, daysAgo: Int, isResolved: Bool, priority: ConversationPriority)] = [
            // 김민준 (0) - 오늘 리마인더 + 미해결 고민
            (0, .promise, "다음 주까지 포트폴리오 피드백 주기로 함", 5, false, .high),
            (0, .concern, "번아웃 징후가 보임", 8, false, .urgent),
            
            // 이서연 (1) - 미해결 약속
            (1, .promise, "이력서 첨삭해주기로 약속", 3, false, .urgent),
            (1, .question, "SwiftUI vs UIKit 어떤 걸 더 공부해야 할지?", 5, false, .normal),
            
            // 박지훈 (2) - 정체 상태 + 미해결 약속
            (2, .promise, "스터디 자료 공유하기로 함", 10, false, .normal),
            (2, .concern, "이직을 해야 할지 고민 중", 10, false, .high),
            
            // 최수아 (3) - 해결된 것들
            (3, .promise, "면접 후기 공유받기", 7, true, .normal),
            (3, .question, "Git 브랜치 전략 질문", 3, true, .normal),
            
            // 정예준 (4) - 위험 상태
            (4, .promise, "커피챗 일정 잡기", 2, true, .normal),
            (4, .concern, "팀 내 갈등으로 스트레스", 8, false, .high),
        ]
        
        for scenario in conversationScenarios {
            guard scenario.personIndex < createdPeople.count else { continue }
            let person = createdPeople[scenario.personIndex]
            
            let conversationDate = Calendar.current.date(byAdding: .day, value: -scenario.daysAgo, to: now) ?? now
            
            let conversation = ConversationRecord(
                date: conversationDate,
                type: scenario.type,
                content: scenario.content,
                notes: nil,
                isImportant: scenario.priority == .urgent || scenario.priority == .high,
                priority: scenario.priority,
                tags: []
            )
            conversation.person = person
            conversation.isResolved = scenario.isResolved
            if scenario.isResolved {
                conversation.resolvedDate = Calendar.current.date(byAdding: .day, value: -1, to: now)
            }
            
            context.insert(conversation)
            person.conversationRecords.append(conversation)
            conversationCount += 1
        }
        
        print("   ✅ \(conversationCount)개 ConversationRecord 생성")
        
        // 5. PersonAction 추가 (리마인더, 긴급 액션)
        // 먼저 기본 액션들 확보
        var allActions: [RapportAction] = []
        do {
            allActions = try context.fetch(FetchDescriptor<RapportAction>(
                predicate: #Predicate { $0.isActive == true }
            ))
            if allActions.isEmpty {
                seedDefaultActionsIfNeeded(context: context)
                allActions = try context.fetch(FetchDescriptor<RapportAction>(
                    predicate: #Predicate { $0.isActive == true }
                ))
            }
        } catch {
            print("   ⚠️ 액션 로드 실패: \(error)")
        }
        
        var actionCount = 0
        
        // 오늘 리마인더가 있는 케이스
        if let criticalAction = allActions.first(where: { $0.type == .critical }),
           createdPeople.count > 0 {
            let todayReminder = PersonAction(
                person: createdPeople[0],
                action: criticalAction,
                isVisibleInDetail: true
            )
            todayReminder.reminderDate = now  // 오늘!
            todayReminder.isCompleted = false
            context.insert(todayReminder)
            createdPeople[0].actions.append(todayReminder)
            actionCount += 1
        }
        
        // 내일 리마인더
        if let trackingAction = allActions.first(where: { $0.type == .tracking }),
           createdPeople.count > 1 {
            let tomorrowReminder = PersonAction(
                person: createdPeople[1],
                action: trackingAction,
                isVisibleInDetail: true
            )
            tomorrowReminder.reminderDate = Calendar.current.date(byAdding: .day, value: 1, to: now)
            tomorrowReminder.isCompleted = false
            context.insert(tomorrowReminder)
            createdPeople[1].actions.append(tomorrowReminder)
            actionCount += 1
        }
        
        // 긴급 액션 마감 지남 (어제)
        if let criticalAction = allActions.first(where: { $0.type == .critical }),
           createdPeople.count > 2 {
            let overdueAction = PersonAction(
                person: createdPeople[2],
                action: criticalAction,
                isVisibleInDetail: true
            )
            overdueAction.reminderDate = Calendar.current.date(byAdding: .day, value: -1, to: now)  // 어제
            overdueAction.isCompleted = false
            context.insert(overdueAction)
            createdPeople[2].actions.append(overdueAction)
            actionCount += 1
        }
        
        // 긴급 액션 마감 3일 지남
        if let criticalAction = allActions.first(where: { $0.type == .critical }),
           createdPeople.count > 3 {
            let veryOverdueAction = PersonAction(
                person: createdPeople[3],
                action: criticalAction,
                isVisibleInDetail: true
            )
            veryOverdueAction.reminderDate = Calendar.current.date(byAdding: .day, value: -3, to: now)
            veryOverdueAction.isCompleted = false
            context.insert(veryOverdueAction)
            createdPeople[3].actions.append(veryOverdueAction)
            actionCount += 1
        }
        
        // 완료된 액션
        if let maintenanceAction = allActions.first(where: { $0.type == .maintenance }),
           createdPeople.count > 4 {
            let completedAction = PersonAction(
                person: createdPeople[4],
                action: maintenanceAction,
                isVisibleInDetail: true
            )
            completedAction.reminderDate = Calendar.current.date(byAdding: .day, value: -2, to: now)
            completedAction.isCompleted = true
            completedAction.completedDate = Calendar.current.date(byAdding: .day, value: -1, to: now)
            context.insert(completedAction)
            createdPeople[4].actions.append(completedAction)
            actionCount += 1
        }
        
        print("   ✅ \(actionCount)개 PersonAction 생성")
        
        // 6. 더미 Person ID들 저장 (나중에 삭제할 때 사용)
        let dummyIds = createdPeople.map { $0.id }
        saveDummyPersonIds(dummyIds)
        print("   💾 \(dummyIds.count)개 더미 ID 저장됨")
        
        // 7. 저장
        do {
            try context.save()
            print("🎭 더미 데이터 생성 완료! (5명)")
            print("   📋 넛지 테스트 케이스:")
            print("      - 김민준: 📅 오늘 리마인더 + 💗 미해결 고민")
            print("      - 이서연: ☑️ 미해결 약속 + ❓ 미해결 질문")
            print("      - 박지훈: ⚡ 긴급 마감 지남 + 💗 오래된 고민")
            print("      - 최수아: ✅ 해결된 약속/질문")
            print("      - 정예준: ⚠️ 위험 상태 + 💗 미해결 고민")
        } catch {
            print("❌ 더미 데이터 저장 실패: \(error)")
        }
    }
    
    /// 랜덤 내용 생성
    private static func generateRandomContent(contactType: ContactType?, personName: String) -> String {
        let meetingContents = [
            "프로젝트 진행 상황 점검. 다음 주까지 프로토타입 완성 목표.",
            "포트폴리오 리뷰. UI 부분 개선 필요.",
            "커리어 상담. 이직 고민 중.",
            "1:1 멘토링. 기술 스택 확장 논의.",
            "스터디 진행 현황 체크.",
            "면접 준비 도움. 예상 질문 리스트 전달.",
        ]
        
        let mealContents = [
            "점심 식사. 근황 이야기 나눔.",
            "저녁 회식. 팀 분위기 좋음.",
            "커피 타임. 가벼운 스몰토크.",
            "브런치 미팅. 새 프로젝트 아이디어 논의.",
        ]
        
        let callContents = [
            "간단한 안부 전화.",
            "급한 질문 있어서 통화.",
            "면접 결과 공유.",
            "프로젝트 이슈 논의.",
            "다음 만남 일정 조율.",
        ]
        
        let messageContents = [
            "자료 전달.",
            "일정 확인 메시지.",
            "생일 축하 메시지 보냄.",
            "취업 축하 메시지.",
            "근황 확인.",
        ]
        
        let memoContents = [
            "다음에 물어볼 것: 요즘 어떤 기술 공부 중인지",
            "선물 아이디어: 개발 관련 책",
            "기억할 것: 3월에 이직 예정",
            "메모: 고양이 2마리 키움",
            "참고: MBTI는 INTJ",
        ]
        
        switch contactType {
        case .meeting:
            return meetingContents.randomElement() ?? "미팅 진행"
        case .meal:
            return mealContents.randomElement() ?? "식사 함께함"
        case .call:
            return callContents.randomElement() ?? "통화함"
        case .message:
            return messageContents.randomElement() ?? "메시지 주고받음"
        case nil:
            return memoContents.randomElement() ?? "메모"
        }
    }
    
    /// 더미 데이터만 삭제 (저장된 ID 기반)
    static func clearAllDummyData(context: ModelContext) {
        print("🗑️ 더미 데이터 삭제 시작...")
        
        // 저장된 더미 ID 가져오기
        let dummyIdStrings = getDummyPersonIds()
        
        if dummyIdStrings.isEmpty {
            print("⚠️ 저장된 더미 데이터 ID가 없습니다. 삭제할 항목이 없습니다.")
            return
        }
        
        let dummyIds = Set(dummyIdStrings.compactMap { UUID(uuidString: $0) })
        print("   🔍 \(dummyIds.count)개의 더미 ID 발견")
        
        do {
            let allPeople = try context.fetch(FetchDescriptor<Person>())
            var deletedCount = 0
            var peopleToDelete: [Person] = []
            
            // 삭제할 Person 목록 수집
            for person in allPeople {
                if dummyIds.contains(person.id) {
                    peopleToDelete.append(person)
                }
            }
            
            // 각 Person의 관계 먼저 정리 (크래시 방지)
            for person in peopleToDelete {
                // 태그 관계 해제 (nullify이므로 수동으로)
                person.tags.removeAll()
                
                // Records의 참석자 관계 정리
                for record in person.records {
                    record.participantIds.removeAll()
                }
            }
            
            // 중간 저장
            try context.save()
            
            // Person 삭제 (cascade로 나머지 자동 삭제)
            for person in peopleToDelete {
                context.delete(person)
                deletedCount += 1
            }
            
            print("   ✅ \(deletedCount)개 더미 Person 삭제")
            
            try context.save()
            
            // 저장된 더미 ID 목록도 초기화
            clearDummyPersonIds()
            
            print("🗑️ 더미 데이터 삭제 완료! (실제 데이터는 보존됨)")
        } catch {
            print("❌ 더미 데이터 삭제 실패: \(error)")
            // 에러가 나도 ID 목록은 초기화 (재시도 가능하게)
            clearDummyPersonIds()
        }
    }
}
