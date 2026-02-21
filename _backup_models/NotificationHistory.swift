//
//  NotificationHistory.swift
//  RapportMap
//
//  Created by hyunho lee on 11/10/25.
//

import Foundation
import SwiftData

@Model
final class NotificationHistory {
    var id: UUID
    var title: String
    var body: String
    var deliveredDate: Date
    var personID: UUID?
    var personName: String?
    var actionID: UUID?
    var actionTitle: String?
    var notificationType: NotificationType
    var isRead: Bool
    
    enum NotificationType: String, Codable {
        case criticalAction = "긴급 액션"
        case neglectedPerson = "소홀한 관계"
        case unansweredQuestion = "미답변 질문"
        case unresolvedPromise = "미해결 약속"
        case relationshipCheck = "관계 체크"
        case other = "기타"
        
        var icon: String {
            switch self {
            case .criticalAction:
                return "exclamationmark.triangle.fill"
            case .neglectedPerson:
                return "person.fill.xmark"
            case .unansweredQuestion:
                return "questionmark.circle.fill"
            case .unresolvedPromise:
                return "hand.raised.fill"
            case .relationshipCheck:
                return "heart.circle.fill"
            case .other:
                return "bell.fill"
            }
        }
        
        var color: String {
            switch self {
            case .criticalAction:
                return "red"
            case .neglectedPerson:
                return "orange"
            case .unansweredQuestion:
                return "blue"
            case .unresolvedPromise:
                return "purple"
            case .relationshipCheck:
                return "green"
            case .other:
                return "gray"
            }
        }
    }
    
    init(
        id: UUID = UUID(),
        title: String,
        body: String,
        deliveredDate: Date = Date(),
        personID: UUID? = nil,
        personName: String? = nil,
        actionID: UUID? = nil,
        actionTitle: String? = nil,
        notificationType: NotificationType = .other,
        isRead: Bool = false
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.deliveredDate = deliveredDate
        self.personID = personID
        self.personName = personName
        self.actionID = actionID
        self.actionTitle = actionTitle
        self.notificationType = notificationType
        self.isRead = isRead
    }
    
    // 알림을 읽음으로 표시
    func markAsRead() {
        isRead = true
    }
    
    // 상대 시간 표시 (예: "2시간 전", "3일 전")
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: deliveredDate, relativeTo: Date())
    }
}
