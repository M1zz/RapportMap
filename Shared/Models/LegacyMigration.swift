//
//  LegacyMigration.swift
//  RapportMap
//
//  기존 데이터를 새 모델로 마이그레이션
//

import Foundation
import SwiftData

// MARK: - 레거시 모델들 (마이그레이션 전용)

/// 기존 Person 모델 (읽기 전용)
@Model
final class LegacyPerson {
    var id: UUID
    var name: String
    var contact: String
    
    @Attribute(.externalStorage)
    var profileImageData: Data?
    
    var lastMentoring: Date?
    var lastMeal: Date?
    var lastContact: Date?
    var currentPhase: Int  // ActionPhase rawValue
    var relationshipStartDate: Date
    var preferredName: String
    var interests: String
    var preferences: String
    var importantDates: String
    var workStyle: String
    var background: String
    var mentoringNotes: String?
    var mealNotes: String?
    var contactNotes: String?
    var quickMemo: String
    
    init() {
        self.id = UUID()
        self.name = ""
        self.contact = ""
        self.currentPhase = 0
        self.relationshipStartDate = Date()
        self.preferredName = ""
        self.interests = ""
        self.preferences = ""
        self.importantDates = ""
        self.workStyle = ""
        self.background = ""
        self.quickMemo = ""
    }
}

/// 기존 ConversationRecord 모델 (읽기 전용)
@Model
final class LegacyConversationRecord {
    var id: UUID
    var date: Date
    var typeRawValue: String  // question, concern, promise 등
    var content: String
    var notes: String?
    var isResolved: Bool
    var isImportant: Bool
    
    @Relationship
    var person: LegacyPerson?
    
    init() {
        self.id = UUID()
        self.date = Date()
        self.typeRawValue = ""
        self.content = ""
        self.isResolved = false
        self.isImportant = false
    }
}

/// 기존 InteractionRecord 모델 (읽기 전용)
@Model
final class LegacyInteractionRecord {
    var id: UUID
    var date: Date
    var typeRawValue: String  // mentoring, meal, contact 등
    var notes: String?
    var isImportant: Bool
    var location: String?
    var duration: TimeInterval?
    
    @Relationship
    var person: LegacyPerson?
    
    init() {
        self.id = UUID()
        self.date = Date()
        self.typeRawValue = ""
        self.isImportant = false
    }
}

// MARK: - 마이그레이션 로직

struct LegacyMigration {
    
    /// 레거시 스키마로 기존 DB 열기
    static func openLegacyDatabase() -> ModelContainer? {
        let schema = Schema([
            LegacyPerson.self,
            LegacyConversationRecord.self,
            LegacyInteractionRecord.self
        ])
        
        // 기존 DB 경로 (기본 SwiftData 경로)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let possiblePaths = [
            appSupport.appendingPathComponent("default.store"),
            appSupport.appendingPathComponent("RapportMap/default.store"),
        ]
        
        for dbURL in possiblePaths {
            if FileManager.default.fileExists(atPath: dbURL.path) {
                print("📂 [Migration] 기존 DB 발견: \(dbURL.path)")
                
                let config = ModelConfiguration(
                    schema: schema,
                    url: dbURL,
                    cloudKitDatabase: .none
                )
                
                do {
                    let container = try ModelContainer(for: schema, configurations: [config])
                    print("✅ [Migration] 레거시 DB 열기 성공")
                    return container
                } catch {
                    print("⚠️ [Migration] 이 경로 실패: \(error)")
                    continue
                }
            }
        }
        
        print("❌ [Migration] 기존 DB를 찾을 수 없음")
        return nil
    }
    
    /// 기존 데이터를 새 모델로 마이그레이션
    @MainActor
    static func migrateToNewModel(
        legacyContainer: ModelContainer,
        newContext: ModelContext
    ) async -> MigrationResult {
        var result = MigrationResult()
        
        let legacyContext = legacyContainer.mainContext
        
        // 1. 기존 Person 가져오기
        let personDescriptor = FetchDescriptor<LegacyPerson>()
        guard let legacyPeople = try? legacyContext.fetch(personDescriptor) else {
            result.errors.append("Person 데이터 로드 실패")
            return result
        }
        
        print("📊 [Migration] 기존 Person \(legacyPeople.count)명 발견")
        
        for legacyPerson in legacyPeople {
            // 새 Person 생성
            let newPerson = Person(
                id: legacyPerson.id,
                name: legacyPerson.name,
                contact: legacyPerson.contact,
                profileImageData: legacyPerson.profileImageData,
                relationshipStartDate: legacyPerson.relationshipStartDate,
                depth: mapPhaseToDepth(legacyPerson.currentPhase),
                memo: combineMemos(legacyPerson)
            )
            
            newContext.insert(newPerson)
            result.peopleMigrated += 1
            
            // 2. 기존 필드들을 Discovery로 변환
            
            // 관심사 → Discovery
            if !legacyPerson.interests.isEmpty {
                let discovery = Discovery(
                    territory: .hobby,
                    content: legacyPerson.interests,
                    context: "기존 데이터에서 마이그레이션"
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
            
            // 취향/선호 → Discovery
            if !legacyPerson.preferences.isEmpty {
                let discovery = Discovery(
                    territory: .taste,
                    content: legacyPerson.preferences,
                    context: "기존 데이터에서 마이그레이션"
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
            
            // 배경 → Discovery
            if !legacyPerson.background.isEmpty {
                let discovery = Discovery(
                    territory: .job,
                    content: legacyPerson.background,
                    context: "기존 데이터에서 마이그레이션"
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
            
            // 업무 스타일 → Discovery
            if !legacyPerson.workStyle.isEmpty {
                let discovery = Discovery(
                    territory: .values,
                    content: legacyPerson.workStyle,
                    context: "기존 데이터에서 마이그레이션"
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
            
            // 중요한 날짜 → Discovery
            if !legacyPerson.importantDates.isEmpty {
                let discovery = Discovery(
                    territory: .favorites,
                    content: "중요한 날짜: \(legacyPerson.importantDates)",
                    context: "기존 데이터에서 마이그레이션"
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
        }
        
        // 3. ConversationRecord → Discovery 변환
        let convDescriptor = FetchDescriptor<LegacyConversationRecord>()
        if let legacyConversations = try? legacyContext.fetch(convDescriptor) {
            print("📊 [Migration] 기존 ConversationRecord \(legacyConversations.count)개 발견")
            
            for conv in legacyConversations {
                guard let legacyPerson = conv.person else { continue }
                
                // 새 Person 찾기
                let targetId = legacyPerson.id
                let predicate = #Predicate<Person> { $0.id == targetId }
                let newPersonDescriptor = FetchDescriptor<Person>(predicate: predicate)
                guard let newPerson = try? newContext.fetch(newPersonDescriptor).first else { continue }
                
                let territory = mapConversationTypeToTerritory(conv.typeRawValue)
                let discovery = Discovery(
                    date: conv.date,
                    territory: territory,
                    content: conv.content,
                    context: conv.notes,
                    isSignificant: conv.isImportant
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
        }
        
        // 4. InteractionRecord → Discovery 변환 (notes가 있는 것만)
        let interactionDescriptor = FetchDescriptor<LegacyInteractionRecord>()
        if let legacyInteractions = try? legacyContext.fetch(interactionDescriptor) {
            print("📊 [Migration] 기존 InteractionRecord \(legacyInteractions.count)개 발견")
            
            for interaction in legacyInteractions {
                guard let notes = interaction.notes, !notes.isEmpty,
                      let legacyPerson = interaction.person else { continue }
                
                // 새 Person 찾기
                let targetId = legacyPerson.id
                let predicate = #Predicate<Person> { $0.id == targetId }
                let newPersonDescriptor = FetchDescriptor<Person>(predicate: predicate)
                guard let newPerson = try? newContext.fetch(newPersonDescriptor).first else { continue }
                
                let territory = mapInteractionTypeToTerritory(interaction.typeRawValue)
                let discovery = Discovery(
                    date: interaction.date,
                    territory: territory,
                    content: notes,
                    context: interaction.location,
                    isSignificant: interaction.isImportant
                )
                discovery.person = newPerson
                newContext.insert(discovery)
                result.discoveriesMigrated += 1
            }
        }
        
        // 저장
        do {
            try newContext.save()
            result.success = true
            print("✅ [Migration] 마이그레이션 완료!")
        } catch {
            result.errors.append("저장 실패: \(error)")
        }
        
        return result
    }
    
    // MARK: - 헬퍼 함수들
    
    private static func mapPhaseToDepth(_ phase: Int) -> RelationshipDepth {
        switch phase {
        case 0: return .surface
        case 1: return .personal
        case 2: return .deep
        case 3: return .intimate
        default: return .surface
        }
    }
    
    private static func combineMemos(_ person: LegacyPerson) -> String? {
        var parts: [String] = []
        if !person.quickMemo.isEmpty { parts.append(person.quickMemo) }
        if let notes = person.mentoringNotes, !notes.isEmpty { parts.append("멘토링: \(notes)") }
        if let notes = person.mealNotes, !notes.isEmpty { parts.append("식사: \(notes)") }
        if let notes = person.contactNotes, !notes.isEmpty { parts.append("연락: \(notes)") }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }
    
    private static func mapConversationTypeToTerritory(_ type: String) -> Territory {
        switch type.lowercased() {
        case "question", "질문": return .currentConcern
        case "concern", "고민": return .currentConcern
        case "promise", "약속": return .goal
        case "achievement", "성취": return .goal
        case "feedback", "피드백": return .values
        default: return .dailyLife
        }
    }
    
    private static func mapInteractionTypeToTerritory(_ type: String) -> Territory {
        switch type.lowercased() {
        case "mentoring", "멘토링": return .goal
        case "meal", "식사": return .favorites
        case "contact", "연락": return .dailyLife
        case "call", "전화": return .dailyLife
        default: return .dailyLife
        }
    }
}

// MARK: - 마이그레이션 결과

struct MigrationResult {
    var success = false
    var peopleMigrated = 0
    var discoveriesMigrated = 0
    var errors: [String] = []
    
    var summary: String {
        if success {
            return "✅ 마이그레이션 완료: \(peopleMigrated)명, \(discoveriesMigrated)개 발견"
        } else {
            return "❌ 마이그레이션 실패: \(errors.joined(separator: ", "))"
        }
    }
}
