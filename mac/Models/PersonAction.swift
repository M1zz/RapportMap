//
//  PersonAction.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation
import SwiftData

@Model
final class PersonAction {
    var id: UUID
    
    // 관계
    var person: Person?
    var action: RapportAction?
    
    // 실행 기록
    var isCompleted: Bool
    var completedDate: Date?
    var lastActionDate: Date?  // 마지막으로 실행한 날짜
    
    // 메모
    var note: String
    var context: String  // 이 액션과 관련된 상황/컨텍스트 (예: "생일 5월 15일", "커피 안 마심")
    
    // 알림
    var reminderDate: Date?  // 크리티컬 액션일 경우 알림 날짜
    var isReminderActive: Bool
    
    // PersonDetailView에 표시 여부
    var isVisibleInDetail: Bool
    
    init(
        id: UUID = UUID(),
        person: Person? = nil,
        action: RapportAction? = nil,
        isCompleted: Bool = false,
        completedDate: Date? = nil,
        lastActionDate: Date? = nil,
        note: String = "",
        context: String = "",
        reminderDate: Date? = nil,
        isReminderActive: Bool = false,
        isVisibleInDetail: Bool = false
    ) {
        self.id = id
        self.person = person
        self.action = action
        self.isCompleted = isCompleted
        self.completedDate = completedDate
        self.lastActionDate = lastActionDate
        self.note = note
        self.context = context
        self.reminderDate = reminderDate
        self.isReminderActive = isReminderActive
        self.isVisibleInDetail = isVisibleInDetail
    }
}

// MARK: - Helpers
extension PersonAction {
    /// 몇 일 전에 마지막으로 실행했는지
    var daysSinceLastAction: Int? {
        guard let lastDate = lastActionDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: lastDate, to: Date())
        return components.day
    }
    
    /// 알림이 필요한가?
    var needsReminder: Bool {
        guard let action = action, action.type == .critical else { return false }
        guard let reminderDate = reminderDate else { return false }
        return isReminderActive && reminderDate <= Date()
    }
    
    /// 이 액션을 지금 완료 처리
    func markCompleted(note: String = "") {
        self.isCompleted = true
        self.completedDate = Date()
        self.lastActionDate = Date()
        if !note.isEmpty {
            self.note = note
        }
    }
    
    /// 완료 취소
    func markIncomplete() {
        self.isCompleted = false
        self.completedDate = nil
    }
}
