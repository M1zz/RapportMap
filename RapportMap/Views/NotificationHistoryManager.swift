//
//  NotificationHistoryManager.swift
//  RapportMap
//
//  Created by hyunho lee on 11/10/25.
//

import Foundation
import SwiftData
import UserNotifications

@MainActor
class NotificationHistoryManager {
    static let shared = NotificationHistoryManager()
    
    private init() {}
    
    /// 알림을 히스토리에 저장
    func saveNotification(
        title: String,
        body: String,
        person: Person? = nil,
        action: PersonAction? = nil,
        notificationType: NotificationHistory.NotificationType,
        context: ModelContext
    ) {
        let notification = NotificationHistory(
            title: title,
            body: body,
            deliveredDate: Date(),
            personID: person?.id,
            personName: person?.name,
            actionID: action?.id,
            actionTitle: action?.action?.title,
            notificationType: notificationType,
            isRead: false
        )
        
        context.insert(notification)
        
        do {
            try context.save()
            print("✅ 알림 히스토리 저장 완료: \(title)")
        } catch {
            print("❌ 알림 히스토리 저장 실패: \(error)")
        }
    }
    
    /// 긴급 액션 알림 저장
    func saveCriticalActionNotification(
        person: Person,
        action: PersonAction,
        context: ModelContext
    ) {
        saveNotification(
            title: "긴급 액션 알림",
            body: "\(person.name)님의 '\(action.action?.title ?? "액션")' 완료 기한이 되었습니다.",
            person: person,
            action: action,
            notificationType: .criticalAction,
            context: context
        )
    }
    
    /// 소홀한 관계 알림 저장
    func saveNeglectedPersonNotification(
        person: Person,
        context: ModelContext
    ) {
        saveNotification(
            title: "관계 관리 필요",
            body: "\(person.name)님과의 관계가 소홀해지고 있습니다. 연락해보는 건 어떨까요?",
            person: person,
            notificationType: .neglectedPerson,
            context: context
        )
    }
    
    /// 미답변 질문 알림 저장
    func saveUnansweredQuestionNotification(
        person: Person,
        questionCount: Int,
        context: ModelContext
    ) {
        saveNotification(
            title: "미답변 질문 알림",
            body: "\(person.name)님으로부터 \(questionCount)개의 질문이 답변을 기다리고 있습니다.",
            person: person,
            notificationType: .unansweredQuestion,
            context: context
        )
    }
    
    /// 미해결 약속 알림 저장
    func saveUnresolvedPromiseNotification(
        person: Person,
        promiseCount: Int,
        context: ModelContext
    ) {
        saveNotification(
            title: "약속 이행 알림",
            body: "\(person.name)님과의 \(promiseCount)개의 약속을 확인해주세요.",
            person: person,
            notificationType: .unresolvedPromise,
            context: context
        )
    }
    
    /// 관계 체크 알림 저장
    func saveRelationshipCheckNotification(
        person: Person,
        context: ModelContext
    ) {
        saveNotification(
            title: "관계 체크",
            body: "\(person.name)님과 오랜만에 연락해보는 건 어떨까요?",
            person: person,
            notificationType: .relationshipCheck,
            context: context
        )
    }
    
    /// 전달된 알림을 가져와서 히스토리에 저장 (앱 실행 시 호출)
    func syncDeliveredNotifications(context: ModelContext) async {
        let center = UNUserNotificationCenter.current()
        let deliveredNotifications = await center.deliveredNotifications()
        
        print("📬 전달된 알림 \(deliveredNotifications.count)개 확인 중...")
        
        for notification in deliveredNotifications {
            let userInfo = notification.request.content.userInfo
            let title = notification.request.content.title
            let body = notification.request.content.body
            
            // 이미 히스토리에 저장된 알림인지 확인 (중복 방지)
            let identifier = notification.request.identifier
            
            // userInfo에서 person 및 action 정보 추출
            let personIDString = userInfo["personID"] as? String
            let personName = userInfo["personName"] as? String
            let actionIDString = userInfo["actionID"] as? String
            let actionTitle = userInfo["actionTitle"] as? String
            let typeString = userInfo["notificationType"] as? String
            
            let notificationType: NotificationHistory.NotificationType
            if let typeString = typeString,
               let type = NotificationHistory.NotificationType(rawValue: typeString) {
                notificationType = type
            } else {
                notificationType = .other
            }
            
            let personID = personIDString.flatMap { UUID(uuidString: $0) }
            let actionID = actionIDString.flatMap { UUID(uuidString: $0) }
            
            // 히스토리에 저장
            let historyNotification = NotificationHistory(
                title: title,
                body: body,
                deliveredDate: notification.date,
                personID: personID,
                personName: personName,
                actionID: actionID,
                actionTitle: actionTitle,
                notificationType: notificationType,
                isRead: false
            )
            
            context.insert(historyNotification)
        }
        
        do {
            try context.save()
            print("✅ 알림 히스토리 동기화 완료")
        } catch {
            print("❌ 알림 히스토리 동기화 실패: \(error)")
        }
    }
    
    /// 오래된 알림 히스토리 정리 (30일 이상)
    func cleanupOldNotifications(context: ModelContext) {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        let descriptor = FetchDescriptor<NotificationHistory>(
            predicate: #Predicate { notification in
                notification.deliveredDate < thirtyDaysAgo
            }
        )
        
        do {
            let oldNotifications = try context.fetch(descriptor)
            
            for notification in oldNotifications {
                context.delete(notification)
            }
            
            try context.save()
            print("🧹 \(oldNotifications.count)개의 오래된 알림 히스토리 정리 완료")
        } catch {
            print("❌ 알림 히스토리 정리 실패: \(error)")
        }
    }
}
