//
//  NotificationManager.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation
import UserNotifications

@MainActor
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    /// 알림 권한 요청
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("❌ 알림 권한 요청 실패: \(error)")
            return false
        }
    }
    
    /// 액션 리마인더 스케줄링
    func scheduleActionReminder(for personAction: PersonAction, at date: Date, title: String, body: String) async -> Bool {
        guard let person = personAction.person, let action = personAction.action else {
            return false
        }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // 사용자 정보 추가
        content.userInfo = [
            "personID": person.id.uuidString,
            "actionID": action.id.uuidString,
            "personActionID": personAction.id.uuidString
        ]
        
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date),
            repeats: false
        )
        
        let identifier = "action-reminder-\(personAction.id.uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ 알림 스케줄링 성공: \(title)")
            return true
        } catch {
            print("❌ 알림 스케줄링 실패: \(error)")
            return false
        }
    }
    
    /// 특정 PersonAction의 알림 제거
    func removeActionReminder(for personAction: PersonAction) async {
        let identifier = "action-reminder-\(personAction.id.uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
        print("🗑️ 알림 제거: \(identifier)")
    }
    
    /// 모든 대기 중인 알림 취소
    func cancelAllActionReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        print("🗑️ 모든 알림 제거됨")
    }
    
    /// 모든 대기 중인 알림 확인 (디버깅용)
    func logPendingNotifications() async {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        print("📝 대기 중인 알림 \(requests.count)개:")
        for request in requests {
            if let trigger = request.trigger as? UNCalendarNotificationTrigger {
                let dateString: String
                if let triggerDate = trigger.nextTriggerDate() {
                    let formatter = DateFormatter()
                    formatter.dateStyle = .short
                    formatter.timeStyle = .short
                    dateString = formatter.string(from: triggerDate)
                } else {
                    dateString = "unknown"
                }
                print("  - \(request.identifier): \(request.content.title) at \(dateString)")
            }
        }
    }
}