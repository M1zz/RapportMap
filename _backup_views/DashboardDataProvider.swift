//
//  DashboardDataProvider.swift
//  RapportMap
//
//  대시보드 데이터를 계산하고 제공하는 서비스
//

import Foundation
import SwiftData
import SwiftUI
import Combine

/// 대시보드에 표시할 데이터를 계산하는 프로바이더
@MainActor
class DashboardDataProvider: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var todayContacts: [Person] = []          // 🔴 오늘 연락해야 할 사람
    @Published var weeklyAttention: [Person] = []        // 🟡 이번 주 주의 필요
    @Published var monthlyStats: MonthlyStats = MonthlyStats()  // 📊 이번 달 현황
    @Published var tagStats: [TagStat] = []              // 🏷️ 태그별 현황
    @Published var recentActivities: [RecentActivity] = [] // 최근 활동
    
    // MARK: - Types
    
    struct MonthlyStats {
        var totalMentoringSessions: Int = 0
        var newMentees: Int = 0
        var totalInteractions: Int = 0
        var resolvedConversations: Int = 0
    }
    
    struct TagStat: Identifiable {
        let id: UUID
        let tag: PersonTag
        let count: Int
        let isWarning: Bool  // 위험 상태 태그인지
    }
    
    struct RecentActivity: Identifiable {
        let id = UUID()
        let personName: String
        let personId: UUID
        let activityType: ActivityType
        let content: String
        let date: Date
        
        enum ActivityType {
            case quickMemo
            case conversation
            case interaction
            case action
            
            var icon: String {
                switch self {
                case .quickMemo: return "note.text"
                case .conversation: return "bubble.left.and.bubble.right"
                case .interaction: return "person.2"
                case .action: return "checkmark.circle"
                }
            }
            
            var color: Color {
                switch self {
                case .quickMemo: return .orange
                case .conversation: return .blue
                case .interaction: return .green
                case .action: return .purple
                }
            }
        }
    }
    
    // MARK: - Data Calculation
    
    /// 모든 대시보드 데이터 새로고침
    func refresh(people: [Person], tags: [PersonTag]) {
        calculateTodayContacts(people: people)
        calculateWeeklyAttention(people: people)
        calculateMonthlyStats(people: people)
        calculateTagStats(people: people, tags: tags)
        calculateRecentActivities(people: people)
    }
    
    // MARK: - Private Calculation Methods
    
    /// 🔴 오늘 연락해야 할 사람들 (소홀함 + 긴급 액션)
    private func calculateTodayContacts(people: [Person]) {
        let today = Calendar.current.startOfDay(for: Date())
        
        todayContacts = people.filter { person in
            // 1. 소홀한 상태
            if person.isNeglected {
                return true
            }
            
            // 2. 오늘 또는 지난 리마인더가 있는 긴급 액션
            let hasUrgentAction = person.actions.contains { action in
                guard !action.isCompleted,
                      action.action?.type == .critical,
                      let reminderDate = action.reminderDate else {
                    return false
                }
                let reminderDay = Calendar.current.startOfDay(for: reminderDate)
                return reminderDay <= today
            }
            
            if hasUrgentAction {
                return true
            }
            
            // 3. 긴급 우선순위의 미해결 약속
            let hasUrgentPromise = person.conversationRecords.contains { record in
                !record.isResolved &&
                record.type == .promise &&
                record.priority == .urgent
            }
            
            return hasUrgentPromise
        }
        .sorted { p1, p2 in
            // 소홀함 정도로 정렬 (더 오래 연락 안한 순)
            let date1 = p1.mostRecentInteractionDate ?? p1.relationshipStartDate
            let date2 = p2.mostRecentInteractionDate ?? p2.relationshipStartDate
            return date1 < date2
        }
    }
    
    /// 🟡 이번 주 주의 필요한 사람들 (소홀해지기 시작한 사람)
    private func calculateWeeklyAttention(people: [Person]) {
        let calendar = Calendar.current
        let now = Date()
        
        weeklyAttention = people.filter { person in
            // todayContacts에 이미 포함된 사람은 제외
            guard !todayContacts.contains(where: { $0.id == person.id }) else {
                return false
            }
            
            // 마지막 상호작용이 10-21일 사이인 사람 (소홀해지기 시작)
            guard let lastInteraction = person.mostRecentInteractionDate else {
                // 접촉 기록이 없으면 관계 시작일 기준
                let days = calendar.dateComponents([.day], from: person.relationshipStartDate, to: now).day ?? 0
                return days >= 10 && days < 21
            }
            
            let daysSince = calendar.dateComponents([.day], from: lastInteraction, to: now).day ?? 0
            
            // 10-21일 사이 (소홀해지기 시작하는 시점)
            if daysSince >= 10 && daysSince < 21 {
                return true
            }
            
            // 미해결 고민이 3-7일 된 경우 (방치 시작)
            let hasAgingConcern = person.conversationRecords.contains { record in
                guard !record.isResolved && record.type == .concern else { return false }
                let days = calendar.dateComponents([.day], from: record.createdDate, to: now).day ?? 0
                return days >= 3 && days < 7
            }
            
            return hasAgingConcern
        }
        .sorted { p1, p2 in
            let date1 = p1.mostRecentInteractionDate ?? p1.relationshipStartDate
            let date2 = p2.mostRecentInteractionDate ?? p2.relationshipStartDate
            return date1 < date2
        }
    }
    
    /// 📊 이번 달 상담/활동 현황
    private func calculateMonthlyStats(people: [Person]) {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        
        var stats = MonthlyStats()
        
        for person in people {
            // 멘토링 세션 카운트
            stats.totalMentoringSessions += person.interactionRecords
                .filter { $0.type == .mentoring && $0.date >= startOfMonth }
                .count
            
            // 총 상호작용 카운트
            stats.totalInteractions += person.interactionRecords
                .filter { $0.date >= startOfMonth }
                .count
            
            // 이번 달에 추가된 멘티
            if person.relationshipStartDate >= startOfMonth {
                stats.newMentees += 1
            }
            
            // 해결된 대화 기록
            stats.resolvedConversations += person.conversationRecords
                .filter { record in
                    guard let resolvedDate = record.resolvedDate else { return false }
                    return resolvedDate >= startOfMonth
                }
                .count
        }
        
        monthlyStats = stats
    }
    
    /// 🏷️ 태그별 현황
    private func calculateTagStats(people: [Person], tags: [PersonTag]) {
        // 위험 상태 관련 태그 이름들
        let warningTagNames = ["위험", "소홀", "주의", "긴급"]
        
        tagStats = tags
            .map { tag in
                let count = tag.people.count
                let isWarning = warningTagNames.contains(where: { tag.name.contains($0) })
                return TagStat(
                    id: tag.id,
                    tag: tag,
                    count: count,
                    isWarning: isWarning && count > 0
                )
            }
            .filter { $0.count > 0 }
            .sorted { $0.count > $1.count }
    }
    
    /// 최근 활동 (최근 기록한 메모/대화 등)
    private func calculateRecentActivities(people: [Person]) {
        var activities: [RecentActivity] = []
        
        for person in people {
            // 빠른 메모 (quickMemo가 있고 최근에 수정된 경우)
            if !person.quickMemo.isEmpty {
                activities.append(RecentActivity(
                    personName: person.name,
                    personId: person.id,
                    activityType: .quickMemo,
                    content: String(person.quickMemo.prefix(50)),
                    date: person.mostRecentInteractionDate ?? Date()
                ))
            }
            
            // 최근 대화 기록 (3일 이내)
            let recentConversations = person.conversationRecords
                .filter { $0.isRecent }
                .prefix(2)
            
            for record in recentConversations {
                activities.append(RecentActivity(
                    personName: person.name,
                    personId: person.id,
                    activityType: .conversation,
                    content: "\(record.type.emoji) \(String(record.content.prefix(40)))",
                    date: record.createdDate
                ))
            }
            
            // 최근 상호작용 (3일 이내)
            let recentInteractions = person.interactionRecords
                .filter { interaction in
                    let days = Calendar.current.dateComponents([.day], from: interaction.date, to: Date()).day ?? 0
                    return days <= 3
                }
                .prefix(1)
            
            for interaction in recentInteractions {
                activities.append(RecentActivity(
                    personName: person.name,
                    personId: person.id,
                    activityType: .interaction,
                    content: interaction.type.title,
                    date: interaction.date
                ))
            }
        }
        
        // 날짜순 정렬 후 최근 5개만
        recentActivities = activities
            .sorted { $0.date > $1.date }
            .prefix(5)
            .map { $0 }
    }
}

// MARK: - Helper Extensions

extension DashboardDataProvider {
    /// 대시보드 요약 텍스트
    var summaryText: String {
        let urgent = todayContacts.count
        let attention = weeklyAttention.count
        
        if urgent == 0 && attention == 0 {
            return "모든 관계가 잘 관리되고 있어요! 👍"
        } else if urgent > 0 {
            return "오늘 \(urgent)명에게 연락이 필요해요"
        } else {
            return "이번 주 \(attention)명에게 주의가 필요해요"
        }
    }
    
    /// 전체 상태 레벨
    var overallStatus: OverallStatus {
        if todayContacts.count >= 3 {
            return .critical
        } else if todayContacts.count > 0 || weeklyAttention.count >= 3 {
            return .warning
        } else if weeklyAttention.count > 0 {
            return .attention
        } else {
            return .good
        }
    }
    
    enum OverallStatus {
        case good, attention, warning, critical
        
        var color: Color {
            switch self {
            case .good: return .green
            case .attention: return .blue
            case .warning: return .orange
            case .critical: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .good: return "checkmark.circle.fill"
            case .attention: return "info.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.octagon.fill"
            }
        }
    }
}
