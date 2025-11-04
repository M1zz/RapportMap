//
//  NotificationManager.swift
//  RapportMap
//
//  Created by Assistant on 11/4/25.
//

import Foundation
import UserNotifications
import SwiftData

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            print("알림 권한 요청 실패: \(error)")
            return false
        }
    }
    
    func scheduleActionReminder(
        for personAction: PersonAction,
        at date: Date,
        title: String,
        body: String
    ) async -> Bool {
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        // 개인 정보를 포함한 추가 정보
        if let personName = personAction.person?.name {
            content.subtitle = personName
        }
        
        // 특정 날짜와 시간으로 트리거 생성
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        // 고유 식별자 생성
        let identifier = "action_reminder_\(personAction.id?.uuidString ?? UUID().uuidString)"
        
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("알림 스케줄링 실패: \(error)")
            return false
        }
    }
    
    func cancelActionReminder(for personAction: PersonAction) {
        let identifier = "action_reminder_\(personAction.id?.uuidString ?? UUID().uuidString)"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}