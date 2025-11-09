import Foundation
import SwiftData
import SwiftUI

@Model
final class InteractionRecord {
    var id: UUID
    var date: Date
    var type: InteractionType
    var notes: String?
    var duration: TimeInterval? // 만남의 경우 지속 시간
    var location: String? // 만남 장소
    var isImportant: Bool = false // 중요도 표시
    
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: InteractionType,
        notes: String? = nil,
        duration: TimeInterval? = nil,
        location: String? = nil,
        isImportant: Bool = false
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.notes = notes
        self.duration = duration
        self.location = location
        self.isImportant = isImportant
    }
}

enum InteractionType: String, Codable, CaseIterable {
    case mentoring = "mentoring"
    case meal = "meal"
    case contact = "contact"
    case meeting = "meeting"
    case call = "call"
    case message = "message"
    
    var title: String {
        switch self {
        case .mentoring: return "멘토링"
        case .meal: return "식사"
        case .contact: return "스몰토크"
        case .meeting: return "만남"
        case .call: return "통화"
        case .message: return "메시지"
        }
    }
    
    var emoji: String {
        switch self {
        case .mentoring: return "🧑‍🏫"
        case .meal: return "🍽️"
        case .contact: return "💬"
        case .meeting: return "🤝"
        case .call: return "📞"
        case .message: return "💌"
        }
    }
    
    var systemImage: String {
        switch self {
        case .mentoring: return "person.badge.clock"
        case .meal: return "fork.knife"
        case .contact: return "bubble.left"
        case .meeting: return "person.2"
        case .call: return "phone"
        case .message: return "message"
        }
    }
    
    var color: Color {
        switch self {
        case .mentoring: return .blue
        case .meal: return .green
        case .contact: return .orange
        case .meeting: return .purple
        case .call: return .red
        case .message: return .pink
        }
    }
}

extension InteractionRecord {
    
    var isRecent: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince <= 3
    }
    
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
}
