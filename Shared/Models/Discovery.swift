//
//  Discovery.swift
//  RapportMap
//
//  발견 - 관계에서 알게 된 것들
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Discovery {
    var id: UUID = UUID()
    var date: Date = Date()                 // 알게 된 날짜
    var createdAt: Date = Date()            // 기록 생성일

    // 핵심 정보
    var territoryRawValue: String = "nickname" // 어떤 영역?
    var content: String = ""               // 알게 된 내용
    
    // 부가 정보 (선택)
    var context: String?                    // 어떤 상황에서 알게 됐나
    var emotionRawValue: String?            // 그때 느낌
    
    // 플래그
    var isSignificant: Bool = false         // 특별히 중요한 발견
    
    // 관계
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    // MARK: - Computed Properties
    
    var territory: Territory {
        get {
            Territory(rawValue: territoryRawValue) ?? .nickname
        }
        set {
            territoryRawValue = newValue.rawValue
        }
    }
    
    var emotion: DiscoveryEmotion? {
        get {
            guard let raw = emotionRawValue else { return nil }
            return DiscoveryEmotion(rawValue: raw)
        }
        set {
            emotionRawValue = newValue?.rawValue
        }
    }
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        territory: Territory,
        content: String,
        context: String? = nil,
        emotion: DiscoveryEmotion? = nil,
        isSignificant: Bool = false
    ) {
        self.id = id
        self.date = date
        self.createdAt = Date()
        self.territoryRawValue = territory.rawValue
        self.content = content
        self.context = context
        self.emotionRawValue = emotion?.rawValue
        self.isSignificant = isSignificant
    }
}

// MARK: - Discovery Extensions

extension Discovery {
    
    /// 발견의 깊이 (territory 기준)
    var depth: RelationshipDepth {
        territory.depth
    }
    
    /// 표시용 아이콘
    var displayIcon: String {
        territory.icon
    }
    
    /// 표시용 이모지
    var displayEmoji: String {
        territory.emoji
    }
    
    /// 표시용 색상
    var displayColor: Color {
        territory.depth.color
    }
    
    /// 상대적 날짜 표시
    var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    /// 최근 발견인지 (7일 이내)
    var isRecent: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince <= 7
    }
    
    /// 요약 텍스트 (미리보기용)
    var summary: String {
        let maxLength = 50
        if content.count <= maxLength {
            return content
        }
        return String(content.prefix(maxLength)) + "..."
    }
    
    /// 카드 표시용 제목
    var displayTitle: String {
        "\(territory.emoji) \(territory.title)"
    }
}

// MARK: - Discovery + Comparable

extension Discovery: Comparable {
    static func < (lhs: Discovery, rhs: Discovery) -> Bool {
        lhs.date < rhs.date
    }
    
    static func == (lhs: Discovery, rhs: Discovery) -> Bool {
        lhs.id == rhs.id
    }
}
