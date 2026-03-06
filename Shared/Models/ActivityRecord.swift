//
//  ActivityRecord.swift
//  RapportMap
//
//  이 사람과의 활동 기록
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - ActivityRecord Model

@Model
final class ActivityRecord {
    var id: UUID
    var date: Date
    var typeRawValue: String
    var notes: String

    @Relationship(deleteRule: .nullify)
    var person: Person?

    init(date: Date = Date(), type: ActivityType, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.typeRawValue = type.rawValue
        self.notes = notes
    }

    var type: ActivityType {
        get { ActivityType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }
}

// MARK: - ActivityType

enum ActivityType: String, CaseIterable, Identifiable {
    case meeting    = "meeting"
    case call       = "call"
    case meal       = "meal"
    case message    = "message"
    case travel     = "travel"
    case gift       = "gift"
    case other      = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .meeting:  return "만남"
        case .call:     return "통화"
        case .meal:     return "식사"
        case .message:  return "메시지"
        case .travel:   return "여행"
        case .gift:     return "선물"
        case .other:    return "기타"
        }
    }

    var emoji: String {
        switch self {
        case .meeting:  return "👋"
        case .call:     return "📞"
        case .meal:     return "🍽️"
        case .message:  return "💬"
        case .travel:   return "✈️"
        case .gift:     return "🎁"
        case .other:    return "📝"
        }
    }

    var color: Color {
        switch self {
        case .meeting:  return .blue
        case .call:     return .green
        case .meal:     return .orange
        case .message:  return .purple
        case .travel:   return .cyan
        case .gift:     return .pink
        case .other:    return .secondary
        }
    }
}
