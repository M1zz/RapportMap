import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID
    var name: String
    var contact: String
    var state: RelationshipState
    var lastMentoring: Date?
    var lastMeal: Date?
    var lastQuestion: String?
    var unansweredCount: Int
    var lastContact: Date?
    var isNeglected: Bool

    init(
        id: UUID = UUID(),
        name: String,
        contact: String = "",
        state: RelationshipState = .distant,
        lastMentoring: Date? = nil,
        lastMeal: Date? = nil,
        lastQuestion: String? = nil,
        unansweredCount: Int = 0,
        lastContact: Date? = nil,
        isNeglected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.contact = contact
        self.state = state
        self.lastMentoring = lastMentoring
        self.lastMeal = lastMeal
        self.lastQuestion = lastQuestion
        self.unansweredCount = unansweredCount
        self.lastContact = lastContact
        self.isNeglected = isNeglected
    }
}

enum RelationshipState: String, Codable, CaseIterable {
    case distant
    case warming
    case close
}
