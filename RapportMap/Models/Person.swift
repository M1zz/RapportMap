//
//  Person.swift
//  RapportMap
//
//  Created by hyunho lee on 11/2/25.
//

import SwiftUI
import SwiftData

@Model
final class Person {
    var id: UUID
    var name: String
    var contact: String
    var lastContact: Date?
    var rapportScore: Double
    @Relationship(deleteRule: .cascade) var interactions: [Interaction] = []

    init(id: UUID = UUID(), name: String, contact: String = "", lastContact: Date? = nil, rapportScore: Double = 0.6) {
        self.id = id
        self.name = name
        self.contact = contact
        self.lastContact = lastContact
        self.rapportScore = rapportScore
    }
}

@Model
final class Interaction {
    enum Kind: String, CaseIterable, Identifiable, Codable {
        case message = "메시지"
        case meeting = "멘토링"
        case meal = "식사"
        var id: String { rawValue }
    }

    var id: UUID
    var kind: Kind
    var date: Date
    var note: String
    var unresolved: Bool

    init(id: UUID = UUID(), kind: Kind, date: Date = .now, note: String = "", unresolved: Bool = false) {
        self.id = id
        self.kind = kind
        self.date = date
        self.note = note
        self.unresolved = unresolved
    }
}

struct RelationshipHint {
    let person: Person
    let lastInteractionKind: Interaction.Kind?
    let lastInteractionDate: Date?
    let unresolvedCount: Int
    let nextRecommendedContact: Date?
    let rapportScore: Double
    let statusLabel: String
    let color: Color
}

extension Person {
    func relationshipHint() -> RelationshipHint {
        let sorted = interactions.sorted { $0.date > $1.date }
        let lastKind = sorted.first?.kind
        let lastDate = sorted.first?.date
        let unresolvedCount = interactions.filter { $0.unresolved }.count

        // 간단한 감쇠 기반 라포 업데이트
        let daysSince = lastDate.map { Date().timeIntervalSince($0) / 86400 } ?? 999
        let decayLambda = 0.035
        let decayed = max(0, rapportScore * exp(-decayLambda * daysSince))

        // 다음 연락 추천일
        let nextDate = Calendar.current.date(byAdding: .day, value: Int(ceil(-log(0.5/rapportScore)/decayLambda)), to: lastDate ?? .now)

        // 상태 문구 & 색상
        let (label, color): (String, Color) = {
            switch decayed {
            case ..<0.3: return ("조금 멀어졌어요", .blue)
            case 0.3..<0.6: return ("균형 유지 중", .orange)
            default: return ("끈끈한 관계", .pink)
            }
        }()

        return RelationshipHint(person: self,
                                 lastInteractionKind: lastKind,
                                 lastInteractionDate: lastDate,
                                 unresolvedCount: unresolvedCount,
                                 nextRecommendedContact: nextDate,
                                 rapportScore: decayed,
                                 statusLabel: label,
                                 color: color)
    }
}
