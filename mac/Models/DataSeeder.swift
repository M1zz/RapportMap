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

    /// 테스트용 더미 데이터 생성
    static func seedDummyData(context: ModelContext) {
        print("🎲 더미 데이터 생성 시작...")

        // 기본 액션 먼저 확인
        seedDefaultActionsIfNeeded(context: context)

        do {
            let allActions = try context.fetch(FetchDescriptor<RapportAction>())

            // 샘플 사람 3명 생성
            let samplePeople = [
                ("김민준", "010-1234-5678", ["개발", "게임", "운동"]),
                ("이서연", "010-2345-6789", ["디자인", "요리", "여행"]),
                ("박지훈", "010-3456-7890", ["기획", "독서", "영화"])
            ]

            for (name, contact, interests) in samplePeople {
                let person = Person(name: name, contact: contact)
                person.interests = interests.joined(separator: ", ")
                person.relationshipStartDate = Calendar.current.date(byAdding: .month, value: -Int.random(in: 3...12), to: Date()) ?? Date()
                context.insert(person)

                // PersonAction들 생성 (일부만 visible)
                for action in allActions.prefix(10) {
                    let personAction = PersonAction(
                        person: person,
                        action: action,
                        isVisibleInDetail: Int.random(in: 0...2) == 0 // 33% 확률로 visible
                    )

                    // 일부는 완료 처리
                    if Bool.random() {
                        personAction.completedDate = Calendar.current.date(byAdding: .day, value: -Int.random(in: 1...30), to: Date())
                        personAction.note = "완료했습니다"
                    }

                    context.insert(personAction)
                }

                // 상호작용 기록 3-5개
                for i in 0..<Int.random(in: 3...5) {
                    let interaction = InteractionRecord(
                        date: Calendar.current.date(byAdding: .day, value: -i * 7, to: Date()) ?? Date(),
                        type: [InteractionType.meeting, .meal, .call, .contact, .message].randomElement()!,
                        notes: "샘플 상호작용 기록 #\(i+1)",
                        isImportant: Bool.random()
                    )
                    interaction.person = person
                    context.insert(interaction)
                }

                // 미팅 기록 2-3개
                for i in 0..<Int.random(in: 2...3) {
                    let meeting = MeetingRecord(
                        date: Calendar.current.date(byAdding: .day, value: -i * 10, to: Date()) ?? Date(),
                        meetingType: [MeetingType.oneOnOne, .mentoring, .coffee, .general, .meal].randomElement()!,
                        summary: "샘플 미팅 #\(i+1): 미팅 요약",
                        isImportant: Bool.random()
                    )
                    meeting.person = person
                    context.insert(meeting)
                }

                // 대화 기록 2-4개
                for i in 0..<Int.random(in: 2...4) {
                    let conversation = ConversationRecord(
                        date: Calendar.current.date(byAdding: .day, value: -i * 5, to: Date()) ?? Date(),
                        type: [ConversationType.question, .concern, .promise, .update, .feedback, .achievement].randomElement()!,
                        content: "샘플 대화 내용 #\(i+1): 주요 내용 포인트",
                        isImportant: Bool.random()
                    )
                    conversation.person = person
                    context.insert(conversation)
                }

                // 빠른 메모 1-2개
                for i in 0..<Int.random(in: 1...2) {
                    let memo = QuickMemoArchive(
                        content: "샘플 빠른 메모 #\(i+1): 기억해둘 내용",
                        createdDate: Calendar.current.date(byAdding: .day, value: -i * 3, to: Date()) ?? Date()
                    )
                    memo.person = person
                    context.insert(memo)
                }
            }

            try context.save()
            print("✅ 더미 데이터 생성 완료: \(samplePeople.count)명의 사람과 관련 기록들")

        } catch {
            print("❌ 더미 데이터 생성 실패: \(error)")
        }
    }
}
