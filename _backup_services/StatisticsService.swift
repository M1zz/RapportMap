//
//  StatisticsService.swift
//  RapportMap
//
//  멘토링 활동 통계 계산 서비스
//

import Foundation
import SwiftData
import Combine

/// 통계 데이터를 담는 구조체
struct MentoringStatistics {
    // MARK: - 전체 현황
    var totalMentees: Int = 0
    var activeMentees: Int = 0
    var neglectedMentees: Int = 0
    var tagDistribution: [TagStatItem] = []
    
    // MARK: - 상담 활동
    var thisMonthInteractions: Int = 0
    var lastMonthInteractions: Int = 0
    var weeklyInteractions: [DailyInteraction] = []
    var dailyAverage: Double = 0
    
    // MARK: - 멘티별 통계
    var topInteractedMentees: [MenteeRank] = []
    var leastContactedMentees: [MenteeRank] = []
    var menteesWithUnresolved: [MenteeRank] = []
    
    // MARK: - 상호작용 타입별 통계
    var interactionTypeStats: [InteractionTypeStat] = []
    
    // MARK: - 계산된 값
    var activeRatio: Double {
        guard totalMentees > 0 else { return 0 }
        return Double(activeMentees) / Double(totalMentees)
    }
    
    var neglectedRatio: Double {
        guard totalMentees > 0 else { return 0 }
        return Double(neglectedMentees) / Double(totalMentees)
    }
    
    var monthlyGrowth: Int {
        return thisMonthInteractions - lastMonthInteractions
    }
    
    var monthlyGrowthPercentage: Double {
        guard lastMonthInteractions > 0 else {
            return thisMonthInteractions > 0 ? 100 : 0
        }
        return Double(thisMonthInteractions - lastMonthInteractions) / Double(lastMonthInteractions) * 100
    }
}

/// 태그별 통계 항목
struct TagStatItem: Identifiable {
    let id = UUID()
    let tagName: String
    let tagColor: String
    let count: Int
    let percentage: Double
}

/// 일별 상호작용 수
struct DailyInteraction: Identifiable {
    let id = UUID()
    let date: Date
    let count: Int
    let dayOfWeek: String
}

/// 멘티 순위 항목
struct MenteeRank: Identifiable {
    let id: UUID
    let name: String
    let value: Int  // 상호작용 수 또는 일수
    let subtitle: String
    let imageData: Data?
}

/// 상호작용 타입별 통계
struct InteractionTypeStat: Identifiable {
    let id = UUID()
    let type: InteractionType
    let count: Int
    let percentage: Double
}

/// 통계 계산 서비스
@MainActor
class StatisticsService: ObservableObject {
    @Published var statistics: MentoringStatistics = MentoringStatistics()
    @Published var isLoading: Bool = false
    
    private let calendar = Calendar.current
    
    /// 모든 통계 데이터 계산
    func calculateStatistics(people: [Person]) async {
        isLoading = true
        defer { isLoading = false }
        
        // 기본 현황
        statistics.totalMentees = people.count
        statistics.activeMentees = people.filter { !$0.isNeglected }.count
        statistics.neglectedMentees = people.filter { $0.isNeglected }.count
        
        // 태그 분포
        calculateTagDistribution(people: people)
        
        // 상담 활동
        calculateInteractionStats(people: people)
        
        // 멘티별 통계
        calculateMenteeRankings(people: people)
        
        // 상호작용 타입별 통계
        calculateInteractionTypeStats(people: people)
    }
    
    // MARK: - Private Methods
    
    private func calculateTagDistribution(people: [Person]) {
        var tagCounts: [String: (color: String, count: Int)] = [:]
        
        for person in people {
            for tag in person.tags {
                if let existing = tagCounts[tag.name] {
                    tagCounts[tag.name] = (existing.color, existing.count + 1)
                } else {
                    tagCounts[tag.name] = (tag.color, 1)
                }
            }
        }
        
        // 태그가 없는 멘티 수 계산
        let noTagCount = people.filter { $0.tags.isEmpty }.count
        if noTagCount > 0 {
            tagCounts["태그 없음"] = ("#8E8E93", noTagCount)
        }
        
        let total = people.count
        statistics.tagDistribution = tagCounts.map { name, data in
            TagStatItem(
                tagName: name,
                tagColor: data.color,
                count: data.count,
                percentage: total > 0 ? Double(data.count) / Double(total) * 100 : 0
            )
        }.sorted { $0.count > $1.count }
    }
    
    private func calculateInteractionStats(people: [Person]) {
        let now = Date()
        let startOfThisMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let startOfLastMonth = calendar.date(byAdding: .month, value: -1, to: startOfThisMonth)!
        
        // 모든 상호작용 기록 수집
        var allInteractions: [InteractionRecord] = []
        for person in people {
            allInteractions.append(contentsOf: person.interactionRecords)
        }
        
        // 이번 달 상호작용 수
        statistics.thisMonthInteractions = allInteractions.filter { 
            $0.date >= startOfThisMonth 
        }.count
        
        // 지난 달 상호작용 수
        statistics.lastMonthInteractions = allInteractions.filter { 
            $0.date >= startOfLastMonth && $0.date < startOfThisMonth 
        }.count
        
        // 최근 7일간 일별 상호작용
        var weeklyData: [DailyInteraction] = []
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ko_KR")
        dateFormatter.dateFormat = "E"
        
        for i in 0..<7 {
            let date = calendar.date(byAdding: .day, value: -6 + i, to: now)!
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            
            let count = allInteractions.filter { 
                $0.date >= startOfDay && $0.date < endOfDay 
            }.count
            
            weeklyData.append(DailyInteraction(
                date: date,
                count: count,
                dayOfWeek: dateFormatter.string(from: date)
            ))
        }
        statistics.weeklyInteractions = weeklyData
        
        // 이번 달 일평균
        let daysInMonth = calendar.component(.day, from: now)
        statistics.dailyAverage = daysInMonth > 0 ? 
            Double(statistics.thisMonthInteractions) / Double(daysInMonth) : 0
    }
    
    private func calculateMenteeRankings(people: [Person]) {
        let now = Date()
        
        // 가장 많이 상담한 멘티 TOP 5
        let interactionCounts = people.map { person -> (Person, Int) in
            let thisMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let count = person.interactionRecords.filter { $0.date >= thisMonthStart }.count
            return (person, count)
        }.sorted { $0.1 > $1.1 }
        
        statistics.topInteractedMentees = Array(interactionCounts.prefix(5)).map { person, count in
            MenteeRank(
                id: person.id,
                name: person.name,
                value: count,
                subtitle: "이번 달 \(count)회 상담",
                imageData: person.profileImageData
            )
        }
        
        // 오래 연락 안 한 멘티 TOP 5
        let daysSinceContact = people.map { person -> (Person, Int) in
            let lastInteraction = person.mostRecentInteractionDate ?? person.relationshipStartDate
            let days = calendar.dateComponents([.day], from: lastInteraction, to: now).day ?? 0
            return (person, days)
        }.sorted { $0.1 > $1.1 }
        
        statistics.leastContactedMentees = Array(daysSinceContact.prefix(5)).map { person, days in
            MenteeRank(
                id: person.id,
                name: person.name,
                value: days,
                subtitle: "\(days)일 전 마지막 연락",
                imageData: person.profileImageData
            )
        }
        
        // 미해결 항목 많은 멘티
        let unresolvedCounts = people.map { person -> (Person, Int) in
            let unresolvedConversations = person.conversationRecords.filter { !$0.isResolved }.count
            let unresolvedActions = person.actions.filter { !$0.isCompleted }.count
            return (person, unresolvedConversations + unresolvedActions)
        }.filter { $0.1 > 0 }.sorted { $0.1 > $1.1 }
        
        statistics.menteesWithUnresolved = Array(unresolvedCounts.prefix(5)).map { person, count in
            MenteeRank(
                id: person.id,
                name: person.name,
                value: count,
                subtitle: "\(count)개 미해결 항목",
                imageData: person.profileImageData
            )
        }
    }
    
    private func calculateInteractionTypeStats(people: [Person]) {
        var typeCounts: [InteractionType: Int] = [:]
        var total = 0
        
        for person in people {
            for interaction in person.interactionRecords {
                typeCounts[interaction.type, default: 0] += 1
                total += 1
            }
        }
        
        statistics.interactionTypeStats = InteractionType.allCases.compactMap { type in
            let count = typeCounts[type] ?? 0
            guard count > 0 else { return nil }
            return InteractionTypeStat(
                type: type,
                count: count,
                percentage: total > 0 ? Double(count) / Double(total) * 100 : 0
            )
        }.sorted { $0.count > $1.count }
    }
}
