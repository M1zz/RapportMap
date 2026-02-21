//
//  Record.swift
//  RapportMap
//
//  통합 기록 모델 - InteractionRecord, ConversationRecord, MeetingRecord, QuickMemoArchive를 하나로 통합
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - 접촉 타입

/// 접촉 타입 (선택 - nil이면 메모만)
enum ContactType: String, Codable, CaseIterable {
    case meeting = "미팅"      // 대면 만남
    case meal = "식사"         // 식사
    case call = "전화"         // 통화
    case message = "메시지"    // 문자/카톡
    
    var title: String { rawValue }
    
    var emoji: String {
        switch self {
        case .meeting: return "🤝"
        case .meal: return "🍽️"
        case .call: return "📞"
        case .message: return "💌"
        }
    }
    
    var icon: String { systemImage }
    
    var systemImage: String {
        switch self {
        case .meeting: return "person.2"
        case .meal: return "fork.knife"
        case .call: return "phone"
        case .message: return "message"
        }
    }
    
    var color: Color {
        switch self {
        case .meeting: return .purple
        case .meal: return .green
        case .call: return .blue
        case .message: return .pink
        }
    }
}

// MARK: - 기록 태그

/// 기록 태그 (복수 선택 가능)
enum RecordTag: String, Codable, CaseIterable {
    case promise = "약속"      // 해야 할 것
    case question = "질문"     // 답해야 할 것
    case concern = "고민"      // 들어줘야 할 것
    case achievement = "성취"  // 축하할 것
    case feedback = "피드백"   // 피드백
    case important = "중요"    // 중요 표시
    
    var title: String { rawValue }
    
    var emoji: String {
        switch self {
        case .promise: return "🤝"
        case .question: return "❓"
        case .concern: return "😰"
        case .achievement: return "🎉"
        case .feedback: return "💭"
        case .important: return "⭐"
        }
    }
    
    var icon: String { systemImage }
    
    var systemImage: String {
        switch self {
        case .promise: return "hand.raised"
        case .question: return "questionmark.circle"
        case .concern: return "heart"
        case .achievement: return "star.circle"
        case .feedback: return "bubble.left.and.bubble.right"
        case .important: return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .promise: return .green
        case .question: return .blue
        case .concern: return .orange
        case .achievement: return .yellow
        case .feedback: return .pink
        case .important: return .red
        }
    }
}

// MARK: - 통합 Record 모델

@Model
final class Record {
    var id: UUID
    var date: Date
    
    // 접촉 타입 (선택 - nil이면 메모만)
    var contactTypeRawValue: String?
    
    // 내용
    var content: String
    var notes: String?
    
    // 태그 (복수 선택 가능)
    @Attribute
    var tagsRawValues: [String] = []
    
    // 상태
    var isResolved: Bool = false    // 약속/질문 해결 여부
    var isImportant: Bool = false   // 중요 표시
    
    // 부가 정보
    var duration: TimeInterval?     // 소요 시간
    var location: String?           // 장소
    
    // 음성 녹음 (선택)
    var audioFileName: String?
    var transcription: String?
    
    // 이미지 (선택)
    @Attribute(.externalStorage)
    var imageDataArray: [Data]?
    
    // 메타
    var createdDate: Date
    var resolvedDate: Date?
    
    // 마이그레이션 소스 추적 (디버깅용)
    var migratedFrom: String?       // "InteractionRecord", "ConversationRecord", "MeetingRecord", "QuickMemoArchive"
    var originalId: UUID?           // 원본 ID
    
    // 참석자 (함께한 다른 사람들의 ID)
    @Attribute
    var participantIds: [String] = []
    
    // 관계
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    // MARK: - Computed Properties
    
    var contactType: ContactType? {
        get {
            guard let rawValue = contactTypeRawValue else { return nil }
            return ContactType(rawValue: rawValue)
        }
        set {
            contactTypeRawValue = newValue?.rawValue
        }
    }
    
    var tags: [RecordTag] {
        get {
            tagsRawValues.compactMap { RecordTag(rawValue: $0) }
        }
        set {
            tagsRawValues = newValue.map { $0.rawValue }
        }
    }
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        contactType: ContactType? = nil,
        content: String,
        notes: String? = nil,
        tags: [RecordTag] = [],
        isResolved: Bool = false,
        isImportant: Bool = false,
        duration: TimeInterval? = nil,
        location: String? = nil,
        audioFileName: String? = nil,
        transcription: String? = nil,
        imageDataArray: [Data]? = nil,
        createdDate: Date = Date(),
        resolvedDate: Date? = nil,
        migratedFrom: String? = nil,
        originalId: UUID? = nil
    ) {
        self.id = id
        self.date = date
        self.contactTypeRawValue = contactType?.rawValue
        self.content = content
        self.notes = notes
        self.tagsRawValues = tags.map { $0.rawValue }
        self.isResolved = isResolved
        self.isImportant = isImportant
        self.duration = duration
        self.location = location
        self.audioFileName = audioFileName
        self.transcription = transcription
        self.imageDataArray = imageDataArray
        self.createdDate = createdDate
        self.resolvedDate = resolvedDate
        self.migratedFrom = migratedFrom
        self.originalId = originalId
    }
}

// MARK: - Record Extensions

extension Record {
    /// 최근 기록인지 여부 (7일 이내)
    var isRecent: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince <= 7
    }
    
    /// 해결이 필요한 기록인지 (약속, 질문, 고민 태그가 있는 경우)
    var needsResolution: Bool {
        return tags.contains(.promise) || tags.contains(.question) || tags.contains(.concern)
    }
    
    /// 상대적 날짜 표시
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    /// 소요 시간 포맷팅
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)시간 \(remainingMinutes)분"
        } else {
            return "\(minutes)분"
        }
    }
    
    /// 표시용 제목 (접촉타입 + 내용 일부)
    var displayTitle: String {
        let maxLength = 30
        let prefix: String
        
        if let contactType = contactType {
            prefix = "\(contactType.emoji) \(contactType.rawValue)"
        } else if !tags.isEmpty {
            prefix = tags.first?.emoji ?? "📝"
        } else {
            prefix = "📝 메모"
        }
        
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
        } else if tags.contains(.promise) || tags.contains(.question) {
            return "⏳ 진행중"
        } else {
            return ""
        }
    }
    
    /// 이미지가 있는지 확인
    var hasImages: Bool {
        return !(imageDataArray?.isEmpty ?? true)
    }
    
    /// 오디오가 있는지 확인
    var hasAudio: Bool {
        return audioFileName != nil
    }
    
    /// 태그 추가
    func addTag(_ tag: RecordTag) {
        if !tagsRawValues.contains(tag.rawValue) {
            tagsRawValues.append(tag.rawValue)
        }
    }
    
    /// 태그 제거
    func removeTag(_ tag: RecordTag) {
        tagsRawValues.removeAll { $0 == tag.rawValue }
    }
    
    /// 태그 토글
    func toggleTag(_ tag: RecordTag) {
        if tagsRawValues.contains(tag.rawValue) {
            removeTag(tag)
        } else {
            addTag(tag)
        }
    }
    
    /// 해결 상태 토글
    func toggleResolved() {
        isResolved.toggle()
        if isResolved {
            resolvedDate = Date()
        } else {
            resolvedDate = nil
        }
    }
    
    // MARK: - 참석자 관리
    
    /// 참석자 추가
    func addParticipant(_ personId: UUID) {
        let idString = personId.uuidString
        if !participantIds.contains(idString) {
            participantIds.append(idString)
        }
    }
    
    /// 참석자 제거
    func removeParticipant(_ personId: UUID) {
        participantIds.removeAll { $0 == personId.uuidString }
    }
    
    /// 참석자 토글
    func toggleParticipant(_ personId: UUID) {
        let idString = personId.uuidString
        if participantIds.contains(idString) {
            removeParticipant(personId)
        } else {
            addParticipant(personId)
        }
    }
    
    /// 특정 사람이 참석했는지 확인
    func hasParticipant(_ personId: UUID) -> Bool {
        participantIds.contains(personId.uuidString)
    }
    
    /// 참석자 UUID 목록
    var participantUUIDs: [UUID] {
        participantIds.compactMap { UUID(uuidString: $0) }
    }
    
    /// 참석자 수
    var participantCount: Int {
        participantIds.count
    }
}

// MARK: - Color Extension for Record Display

extension Record {
    /// 기록의 대표 색상 (접촉타입 또는 첫 번째 태그 기준)
    var displayColor: Color {
        if let contactType = contactType {
            return contactType.color
        } else if let firstTag = tags.first {
            return firstTag.color
        } else {
            return .gray
        }
    }
    
    /// 기록의 대표 이모지
    var displayEmoji: String {
        if let contactType = contactType {
            return contactType.emoji
        } else if let firstTag = tags.first {
            return firstTag.emoji
        } else {
            return "📝"
        }
    }
    
    /// 기록의 시스템 이미지
    var displaySystemImage: String {
        if let contactType = contactType {
            return contactType.systemImage
        } else if let firstTag = tags.first {
            return firstTag.systemImage
        } else {
            return "note.text"
        }
    }
}
