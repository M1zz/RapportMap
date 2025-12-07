//
//  CloudKitManager.swift
//  RapportMap
//
//  CloudKit을 사용한 데이터 백업, 복원, 삭제 관리자
//

import Foundation
import CloudKit
import SwiftData
import Combine

@MainActor
class CloudKitManager: ObservableObject {
    static let shared = CloudKitManager()

    // 명시적으로 container identifier 지정
    private let container = CKContainer(identifier: "iCloud.com.ysoup.RapportMap")
    private let database: CKDatabase

    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var isDeleting = false
    @Published var lastBackupDate: Date?

    private init() {
        self.database = container.privateCloudDatabase
        loadLastBackupDate()
    }

    // MARK: - UserDefaults Keys

    private let lastBackupDateKey = "lastCloudKitBackupDate"

    private func loadLastBackupDate() {
        if let date = UserDefaults.standard.object(forKey: lastBackupDateKey) as? Date {
            lastBackupDate = date
        }
    }

    private func saveLastBackupDate(_ date: Date) {
        UserDefaults.standard.set(date, forKey: lastBackupDateKey)
        lastBackupDate = date
    }

    // MARK: - Backup

    func backupToCloud(context: ModelContext) async throws {
        guard !isBackingUp else { return }
        isBackingUp = true
        defer { isBackingUp = false }

        print("☁️ [CloudKit] 백업 시작...")

        // Person 데이터 가져오기
        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        print("☁️ [CloudKit] 백업할 Person 수: \(people.count)")

        // Person 데이터를 JSON으로 변환
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        var backupData: [[String: Any]] = []

        for person in people {
            var personDict: [String: Any] = [
                "id": person.id.uuidString,
                "name": person.name,
                "contact": person.contact,
                "state": person.state.rawValue,
                "currentPhase": person.currentPhase.rawValue,
                "relationshipStartDate": ISO8601DateFormatter().string(from: person.relationshipStartDate),
                "preferredName": person.preferredName,
                "interests": person.interests,
                "preferences": person.preferences,
                "importantDates": person.importantDates,
                "workStyle": person.workStyle,
                "background": person.background,
                "quickMemo": person.quickMemo
            ]

            // Optional 날짜들
            if let lastMentoring = person.lastMentoring {
                personDict["lastMentoring"] = ISO8601DateFormatter().string(from: lastMentoring)
            }
            if let lastMeal = person.lastMeal {
                personDict["lastMeal"] = ISO8601DateFormatter().string(from: lastMeal)
            }
            if let lastContact = person.lastContact {
                personDict["lastContact"] = ISO8601DateFormatter().string(from: lastContact)
            }

            // Optional 노트들
            if let mentoringNotes = person.mentoringNotes {
                personDict["mentoringNotes"] = mentoringNotes
            }
            if let mealNotes = person.mealNotes {
                personDict["mealNotes"] = mealNotes
            }
            if let contactNotes = person.contactNotes {
                personDict["contactNotes"] = contactNotes
            }

            // 프로필 이미지 데이터
            if let imageData = person.profileImageData {
                personDict["profileImageData"] = imageData.base64EncodedString()
            }

            // InteractionRecords (상호작용 기록)
            let interactions = person.interactionRecords.map { interaction -> [String: Any] in
                var dict: [String: Any] = [
                    "id": interaction.id.uuidString,
                    "type": interaction.type.rawValue,
                    "date": ISO8601DateFormatter().string(from: interaction.date),
                    "isImportant": interaction.isImportant
                ]
                if let notes = interaction.notes {
                    dict["notes"] = notes
                }
                if let duration = interaction.duration {
                    dict["duration"] = duration
                }
                if let location = interaction.location {
                    dict["location"] = location
                }
                return dict
            }
            personDict["interactionRecords"] = interactions

            // MeetingRecords (미팅 기록)
            let meetings = person.meetingRecords.map { meeting -> [String: Any] in
                var dict: [String: Any] = [
                    "id": meeting.id.uuidString,
                    "date": ISO8601DateFormatter().string(from: meeting.date),
                    "meetingType": meeting.meetingType.rawValue,
                    "transcribedText": meeting.transcribedText,
                    "summary": meeting.summary,
                    "duration": meeting.duration,
                    "isImportant": meeting.isImportant
                ]
                if let audioFileURL = meeting.audioFileURL {
                    dict["audioFileURL"] = audioFileURL
                }
                return dict
            }
            personDict["meetingRecords"] = meetings

            // PersonContexts (개인 컨텍스트)
            let contexts = person.contexts.map { context -> [String: Any] in
                var dict: [String: Any] = [
                    "id": context.id.uuidString,
                    "category": context.category.rawValue,
                    "label": context.label,
                    "value": context.value,
                    "reminderEnabled": context.reminderEnabled,
                    "order": context.order
                ]
                if let date = context.date {
                    dict["date"] = ISO8601DateFormatter().string(from: date)
                }
                return dict
            }
            personDict["contexts"] = contexts

            // ConversationRecords (대화 기록)
            let conversations = person.conversationRecords.map { conv -> [String: Any] in
                [
                    "id": conv.id.uuidString,
                    "type": conv.type.rawValue,
                    "content": conv.content,
                    "date": ISO8601DateFormatter().string(from: conv.date),
                    "isResolved": conv.isResolved
                ]
            }
            personDict["conversationRecords"] = conversations

            // QuickMemoArchive (빠른 메모 아카이브)
            let memos = person.archivedMemos.map { memo -> [String: Any] in
                [
                    "id": memo.id.uuidString,
                    "content": memo.content,
                    "createdDate": ISO8601DateFormatter().string(from: memo.createdDate)
                ]
            }
            personDict["archivedMemos"] = memos

            backupData.append(personDict)
        }

        // JSON 데이터로 변환
        let jsonData = try JSONSerialization.data(withJSONObject: backupData)

        // CloudKit 레코드 생성 또는 업데이트
        let recordID = CKRecord.ID(recordName: "RapportMapBackup")

        // 기존 레코드가 있는지 확인하고, 있으면 가져와서 업데이트
        let record: CKRecord
        do {
            // 기존 레코드 가져오기
            let existingRecord = try await database.record(for: recordID)
            record = existingRecord
            print("☁️ [CloudKit] 기존 백업을 덮어씁니다...")
        } catch let error as CKError where error.code == .unknownItem {
            // 기존 레코드가 없으면 새로 생성
            record = CKRecord(recordType: "Backup", recordID: recordID)
            print("☁️ [CloudKit] 새 백업을 생성합니다...")
        }

        // 레코드 데이터 설정
        record["data"] = jsonData as CKRecordValue
        record["backupDate"] = Date() as CKRecordValue
        record["peopleCount"] = people.count as CKRecordValue
        record["platform"] = "iOS" as CKRecordValue

        // CloudKit에 저장 (덮어쓰기 정책 사용)
        let modifyOperation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)
        modifyOperation.savePolicy = .changedKeys  // 변경된 키만 업데이트
        modifyOperation.qualityOfService = .userInitiated

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            modifyOperation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            database.add(modifyOperation)
        }

        saveLastBackupDate(Date())
        print("✅ [CloudKit] 백업 완료 (\(people.count)명)")
    }

    // MARK: - Restore

    /// 클라우드에서 데이터 복원
    /// - Parameters:
    ///   - context: SwiftData ModelContext
    ///   - replaceExisting: true면 기존 데이터를 모두 삭제하고 복원, false면 중복 제외하고 추가만
    func restoreFromCloud(context: ModelContext, replaceExisting: Bool = false) async throws {
        guard !isRestoring else { return }
        isRestoring = true
        defer { isRestoring = false }

        print("☁️ [CloudKit] 복원 시작... (기존 데이터 \(replaceExisting ? "삭제 후" : "유지하며") 복원)")

        // CloudKit에서 백업 데이터 가져오기
        let recordID = CKRecord.ID(recordName: "RapportMapBackup")
        let record = try await database.record(for: recordID)

        guard let jsonData = record["data"] as? Data else {
            throw CloudKitError.noBackupFound
        }

        // JSON 파싱
        let backupData = try JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]]
        guard let peopleData = backupData else {
            throw CloudKitError.invalidBackupData
        }

        print("☁️ [CloudKit] 복원할 Person 수: \(peopleData.count)")

        // 기존 데이터 삭제 옵션
        if replaceExisting {
            print("☁️ [CloudKit] 기존 로컬 데이터 삭제 중...")
            let descriptor = FetchDescriptor<Person>()
            let existingPeople = try context.fetch(descriptor)
            for person in existingPeople {
                context.delete(person)
            }
            try context.save()
            print("✅ [CloudKit] 기존 로컬 데이터 삭제 완료")
        }

        // 기존 Person ID들 가져오기 (중복 방지)
        let descriptor = FetchDescriptor<Person>()
        let existingPeople = try context.fetch(descriptor)
        let existingIDs = Set(existingPeople.map { $0.id })

        let dateFormatter = ISO8601DateFormatter()
        var restoredCount = 0

        for personDict in peopleData {
            guard let idString = personDict["id"] as? String,
                  let id = UUID(uuidString: idString),
                  !existingIDs.contains(id),  // 이미 존재하는 Person은 건너뛰기
                  let name = personDict["name"] as? String else {
                continue
            }

            let person = Person(
                id: id,
                name: name,
                contact: personDict["contact"] as? String ?? "",
                state: RelationshipState(rawValue: personDict["state"] as? String ?? "") ?? .distant,
                lastMentoring: (personDict["lastMentoring"] as? String).flatMap { dateFormatter.date(from: $0) },
                lastMeal: (personDict["lastMeal"] as? String).flatMap { dateFormatter.date(from: $0) },
                lastContact: (personDict["lastContact"] as? String).flatMap { dateFormatter.date(from: $0) },
                currentPhase: ActionPhase(rawValue: personDict["currentPhase"] as? String ?? "") ?? .surface,
                relationshipStartDate: (personDict["relationshipStartDate"] as? String).flatMap { dateFormatter.date(from: $0) } ?? Date(),
                preferredName: personDict["preferredName"] as? String ?? "",
                interests: personDict["interests"] as? String ?? "",
                preferences: personDict["preferences"] as? String ?? "",
                importantDates: personDict["importantDates"] as? String ?? "",
                workStyle: personDict["workStyle"] as? String ?? "",
                background: personDict["background"] as? String ?? "",
                mentoringNotes: personDict["mentoringNotes"] as? String,
                mealNotes: personDict["mealNotes"] as? String,
                contactNotes: personDict["contactNotes"] as? String
            )

            // 프로필 이미지 복원
            if let imageBase64 = personDict["profileImageData"] as? String,
               let imageData = Data(base64Encoded: imageBase64) {
                person.profileImageData = imageData
            }

            // 빠른 메모 복원
            if let quickMemo = personDict["quickMemo"] as? String {
                person.quickMemo = quickMemo
            }

            // InteractionRecords 복원
            if let interactions = personDict["interactionRecords"] as? [[String: Any]] {
                for interactionDict in interactions {
                    guard let idString = interactionDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let typeString = interactionDict["type"] as? String,
                          let type = InteractionType(rawValue: typeString),
                          let dateString = interactionDict["date"] as? String,
                          let date = dateFormatter.date(from: dateString) else {
                        continue
                    }

                    let interaction = InteractionRecord(
                        id: id,
                        date: date,
                        type: type,
                        notes: interactionDict["notes"] as? String,
                        duration: interactionDict["duration"] as? TimeInterval,
                        location: interactionDict["location"] as? String,
                        isImportant: interactionDict["isImportant"] as? Bool ?? false
                    )
                    person.interactionRecords.append(interaction)
                    context.insert(interaction)
                }
            }

            // MeetingRecords 복원
            if let meetings = personDict["meetingRecords"] as? [[String: Any]] {
                for meetingDict in meetings {
                    guard let idString = meetingDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let dateString = meetingDict["date"] as? String,
                          let date = dateFormatter.date(from: dateString),
                          let typeString = meetingDict["meetingType"] as? String,
                          let meetingType = MeetingType(rawValue: typeString) else {
                        continue
                    }

                    let meeting = MeetingRecord(
                        id: id,
                        date: date,
                        meetingType: meetingType,
                        audioFileURL: meetingDict["audioFileURL"] as? String,
                        transcribedText: meetingDict["transcribedText"] as? String ?? "",
                        summary: meetingDict["summary"] as? String ?? "",
                        duration: meetingDict["duration"] as? TimeInterval ?? 0,
                        isImportant: meetingDict["isImportant"] as? Bool ?? false
                    )
                    person.meetingRecords.append(meeting)
                    context.insert(meeting)
                }
            }

            // PersonContexts 복원
            if let contexts = personDict["contexts"] as? [[String: Any]] {
                for contextDict in contexts {
                    guard let idString = contextDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let categoryString = contextDict["category"] as? String,
                          let category = ContextCategory(rawValue: categoryString),
                          let label = contextDict["label"] as? String,
                          let value = contextDict["value"] as? String else {
                        continue
                    }

                    let date: Date? = (contextDict["date"] as? String).flatMap { dateFormatter.date(from: $0) }

                    let personContext = PersonContext(
                        id: id,
                        category: category,
                        label: label,
                        value: value,
                        date: date,
                        reminderEnabled: contextDict["reminderEnabled"] as? Bool ?? false,
                        order: contextDict["order"] as? Int ?? 0
                    )
                    person.contexts.append(personContext)
                    context.insert(personContext)
                }
            }

            // ConversationRecords 복원
            if let conversations = personDict["conversationRecords"] as? [[String: Any]] {
                for convDict in conversations {
                    guard let idString = convDict["id"] as? String,
                          let id = UUID(uuidString: idString),
                          let typeString = convDict["type"] as? String,
                          let type = ConversationType(rawValue: typeString),
                          let content = convDict["content"] as? String,
                          let dateString = convDict["date"] as? String,
                          let date = dateFormatter.date(from: dateString) else {
                        continue
                    }

                    let conversation = ConversationRecord(
                        id: id,
                        date: date,
                        type: type,
                        content: content,
                        isResolved: convDict["isResolved"] as? Bool ?? false
                    )
                    person.conversationRecords.append(conversation)
                    context.insert(conversation)
                }
            }

            // QuickMemoArchive 복원
            if let memos = personDict["archivedMemos"] as? [[String: Any]] {
                for memoDict in memos {
                    guard let content = memoDict["content"] as? String,
                          let dateString = memoDict["createdDate"] as? String,
                          let createdDate = dateFormatter.date(from: dateString) else {
                        continue
                    }

                    let memo = QuickMemoArchive(
                        content: content,
                        createdDate: createdDate
                    )
                    person.archivedMemos.append(memo)
                    context.insert(memo)
                }
            }

            context.insert(person)
            restoredCount += 1
        }

        try context.save()
        print("✅ [CloudKit] 복원 완료: \(restoredCount)명 추가됨")
    }

    // MARK: - Delete

    /// 로컬 데이터만 삭제
    func deleteLocalData(context: ModelContext) async throws {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        print("📱 [Local] 로컬 데이터 삭제 시작...")

        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        for person in people {
            context.delete(person)
        }

        try context.save()
        print("✅ [Local] 로컬 데이터 삭제 완료 (\(people.count)명)")
    }

    /// 클라우드 백업 데이터만 삭제
    func deleteCloudBackup() async throws {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        print("☁️ [CloudKit] 클라우드 백업 삭제 시작...")

        let recordID = CKRecord.ID(recordName: "RapportMapBackup")
        do {
            try await database.deleteRecord(withID: recordID)
            print("✅ [CloudKit] 클라우드 백업 삭제 완료")
        } catch let error as CKError where error.code == .unknownItem {
            print("ℹ️ [CloudKit] 클라우드에 백업이 없음 (이미 삭제됨)")
        }

        // 마지막 백업 날짜 초기화
        UserDefaults.standard.removeObject(forKey: lastBackupDateKey)
        lastBackupDate = nil
    }

    /// 로컬 데이터와 클라우드 백업 모두 삭제
    func deleteAllData(context: ModelContext) async throws {
        guard !isDeleting else { return }
        isDeleting = true
        defer { isDeleting = false }

        print("🗑️ [CloudKit] 전체 데이터 삭제 시작...")

        // 1. 로컬 데이터 삭제
        let descriptor = FetchDescriptor<Person>()
        let people = try context.fetch(descriptor)

        for person in people {
            context.delete(person)
        }

        try context.save()
        print("✅ [Local] 로컬 데이터 삭제 완료 (\(people.count)명)")

        // 2. CloudKit 데이터 삭제
        let recordID = CKRecord.ID(recordName: "RapportMapBackup")
        do {
            try await database.deleteRecord(withID: recordID)
            print("✅ [CloudKit] 클라우드 백업 삭제 완료")
        } catch let error as CKError where error.code == .unknownItem {
            print("ℹ️ [CloudKit] 클라우드에 백업이 없음 (이미 삭제됨)")
        }

        // 3. 마지막 백업 날짜 초기화
        UserDefaults.standard.removeObject(forKey: lastBackupDateKey)
        lastBackupDate = nil

        print("✅ [CloudKit] 전체 데이터 삭제 완료")
    }

    // MARK: - Backup Info

    func getBackupInfo() async throws -> (date: Date, peopleCount: Int)? {
        let recordID = CKRecord.ID(recordName: "RapportMapBackup")

        do {
            let record = try await database.record(for: recordID)

            guard let backupDate = record["backupDate"] as? Date,
                  let peopleCount = record["peopleCount"] as? Int else {
                return nil
            }

            return (date: backupDate, peopleCount: peopleCount)
        } catch let error as CKError where error.code == .unknownItem {
            // 백업이 없는 경우
            return nil
        }
    }
}

// MARK: - Error Types

enum CloudKitError: LocalizedError {
    case noBackupFound
    case invalidBackupData

    var errorDescription: String? {
        switch self {
        case .noBackupFound:
            return "백업된 데이터를 찾을 수 없습니다"
        case .invalidBackupData:
            return "백업 데이터가 손상되었습니다"
        }
    }
}
