//
//  TimelineGrouping.swift
//  RapportMap
//
//  Created by Claude on 12/13/25.
//

import Foundation

/// 타임라인 날짜 그룹화 카테고리
/// 메시지 앱처럼 상대적 시간 그룹으로 분류
enum TimelineGroup: String, CaseIterable {
    case today = "오늘"
    case yesterday = "어제"
    case thisWeek = "이번 주"
    case lastWeek = "지난 주"
    case thisMonth = "이번 달"
    case lastMonth = "지난 달"
    case earlier = "이전"

    /// 주어진 날짜가 어느 그룹에 속하는지 계산
    /// - Parameter date: 분류할 날짜
    /// - Returns: 해당 날짜가 속한 TimelineGroup
    static func group(for date: Date) -> TimelineGroup {
        let calendar = Calendar.current
        let now = Date()

        // 오늘
        if calendar.isDateInToday(date) {
            return .today
        }

        // 어제
        if calendar.isDateInYesterday(date) {
            return .yesterday
        }

        // 이번 주 (최근 7일, 오늘/어제 제외)
        if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           date >= weekAgo {
            return .thisWeek
        }

        // 지난 주 (7-14일 전)
        if let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now),
           let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
           date >= twoWeeksAgo && date < weekAgo {
            return .lastWeek
        }

        // 이번 달
        if calendar.isDate(date, equalTo: now, toGranularity: .month) {
            return .thisMonth
        }

        // 지난 달
        if let lastMonth = calendar.date(byAdding: .month, value: -1, to: now),
           calendar.isDate(date, equalTo: lastMonth, toGranularity: .month) {
            return .lastMonth
        }

        // 그 이전
        return .earlier
    }

    /// 정렬 순서 (오늘이 가장 위)
    var sortOrder: Int {
        switch self {
        case .today: return 0
        case .yesterday: return 1
        case .thisWeek: return 2
        case .lastWeek: return 3
        case .thisMonth: return 4
        case .lastMonth: return 5
        case .earlier: return 6
        }
    }
}

/// 날짜별로 그룹화된 타임라인 아이템들
struct GroupedTimelineItems: Identifiable {
    let id = UUID()
    let group: TimelineGroup
    let items: [TimelineItem]
}

/// TimelineItem 배열에 대한 확장: 날짜별 그룹화 기능 제공
extension Array where Element == TimelineItem {
    /// 타임라인 아이템들을 날짜 그룹별로 분류
    /// - Returns: 날짜 그룹별로 정리된 GroupedTimelineItems 배열 (최신 그룹 우선)
    func groupedByDate() -> [GroupedTimelineItems] {
        // 날짜 그룹별로 딕셔너리로 분류
        let grouped = Dictionary(grouping: self) { item in
            TimelineGroup.group(for: item.date)
        }

        // 각 그룹 내에서 날짜 내림차순 정렬하고, 그룹별로도 정렬
        return grouped
            .map { group, items in
                GroupedTimelineItems(
                    group: group,
                    items: items.sorted { $0.date > $1.date }
                )
            }
            .sorted { $0.group.sortOrder < $1.group.sortOrder }
    }
}
