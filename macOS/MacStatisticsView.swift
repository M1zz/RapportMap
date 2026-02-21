//
//  MacStatisticsView.swift
//  mac
//
//  멘토링 활동 통계 메인 뷰 (macOS)
//

import SwiftUI
import SwiftData
import Charts

struct MacStatisticsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]
    
    @StateObject private var statisticsService = StatisticsService()
    @State private var selectedTab: StatisticsTab = .overview
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("통계")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button {
                    Task {
                        await statisticsService.calculateStatistics(people: people)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(statisticsService.isLoading)
                
                Button("완료") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            if statisticsService.isLoading {
                loadingView
            } else {
                HSplitView {
                    // 사이드바
                    sidebarView
                        .frame(minWidth: 150, idealWidth: 180, maxWidth: 220)
                    
                    // 메인 콘텐츠
                    mainContentView
                        .frame(minWidth: 600)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
        .task {
            await statisticsService.calculateStatistics(people: people)
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("통계 계산 중...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Sidebar
    
    private var sidebarView: some View {
        List(selection: $selectedTab) {
            Section("통계 메뉴") {
                ForEach(StatisticsTab.allCases) { tab in
                    Label(tab.title, systemImage: tab.icon)
                        .tag(tab)
                }
            }
        }
        .listStyle(.sidebar)
    }
    
    // MARK: - Main Content
    
    private var mainContentView: some View {
        ScrollView {
            switch selectedTab {
            case .overview:
                overviewSection
            case .activity:
                activitySection
            case .mentees:
                menteesSection
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    // MARK: - Overview Section
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("전체 현황")
                .font(.title2)
                .fontWeight(.bold)
            
            // 주요 숫자 카드들
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                MacStatCard(
                    title: "총 멘티 수",
                    value: "\(statisticsService.statistics.totalMentees)",
                    subtitle: "전체 관리 인원",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                MacStatCard(
                    title: "이번 달 상담",
                    value: "\(statisticsService.statistics.thisMonthInteractions)",
                    subtitle: "일평균 \(String(format: "%.1f", statisticsService.statistics.dailyAverage))회",
                    icon: "message.fill",
                    color: .green,
                    trend: statisticsService.statistics.monthlyGrowth
                )
                
                MacStatCard(
                    title: "활성 멘티",
                    value: "\(statisticsService.statistics.activeMentees)",
                    subtitle: "\(Int(statisticsService.statistics.activeRatio * 100))%",
                    icon: "bolt.fill",
                    color: .orange
                )
                
                MacStatCard(
                    title: "소홀한 멘티",
                    value: "\(statisticsService.statistics.neglectedMentees)",
                    subtitle: "관심 필요",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
            
            // 하단 차트들
            HStack(alignment: .top, spacing: 20) {
                // 태그 분포
                VStack(alignment: .leading, spacing: 12) {
                    Text("태그별 분포")
                        .font(.headline)
                    
                    if statisticsService.statistics.tagDistribution.isEmpty {
                        Text("태그 데이터가 없습니다")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        MacTagDistributionChart(data: statisticsService.statistics.tagDistribution)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .frame(maxWidth: .infinity)
                
                // 활성화 비율
                VStack(alignment: .leading, spacing: 12) {
                    Text("멘티 상태")
                        .font(.headline)
                    
                    MacRatioChart(
                        activeCount: statisticsService.statistics.activeMentees,
                        neglectedCount: statisticsService.statistics.neglectedMentees
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
    }
    
    // MARK: - Activity Section
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("상담 활동")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(alignment: .top, spacing: 20) {
                // 주간 추이
                VStack(alignment: .leading, spacing: 12) {
                    Text("주간 상담 추이")
                        .font(.headline)
                    
                    if statisticsService.statistics.weeklyInteractions.isEmpty {
                        Text("주간 데이터가 없습니다")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                    } else {
                        MacWeeklyChart(data: statisticsService.statistics.weeklyInteractions)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .frame(maxWidth: .infinity)
                
                // 월별 비교
                VStack(alignment: .leading, spacing: 12) {
                    Text("월별 비교")
                        .font(.headline)
                    
                    MacMonthComparisonChart(
                        thisMonth: statisticsService.statistics.thisMonthInteractions,
                        lastMonth: statisticsService.statistics.lastMonthInteractions
                    )
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .frame(maxWidth: .infinity)
            }
            
            // 상호작용 유형별
            VStack(alignment: .leading, spacing: 12) {
                Text("상호작용 유형별")
                    .font(.headline)
                
                if statisticsService.statistics.interactionTypeStats.isEmpty {
                    Text("상호작용 데이터가 없습니다")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else {
                    MacInteractionTypeChart(data: statisticsService.statistics.interactionTypeStats)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
        }
        .padding()
    }
    
    // MARK: - Mentees Section
    
    private var menteesSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("멘티별 통계")
                .font(.title2)
                .fontWeight(.bold)
            
            HStack(alignment: .top, spacing: 20) {
                // 가장 많이 상담한 멘티
                MacRankingList(
                    title: "가장 많이 상담한 멘티",
                    icon: "flame.fill",
                    iconColor: .orange,
                    data: statisticsService.statistics.topInteractedMentees,
                    emptyMessage: "이번 달 상담 기록이 없습니다",
                    valueFormatter: { "\($0)회" }
                )
                
                // 오래 연락 안 한 멘티
                MacRankingList(
                    title: "오래 연락 안 한 멘티",
                    icon: "clock.badge.exclamationmark.fill",
                    iconColor: .red,
                    data: statisticsService.statistics.leastContactedMentees,
                    emptyMessage: "모든 멘티와 최근 연락했습니다",
                    valueFormatter: { "\($0)일" }
                )
                
                // 미해결 항목이 많은 멘티
                MacRankingList(
                    title: "미해결 항목",
                    icon: "checklist.unchecked",
                    iconColor: .purple,
                    data: statisticsService.statistics.menteesWithUnresolved,
                    emptyMessage: "모든 항목이 해결되었습니다",
                    valueFormatter: { "\($0)개" }
                )
            }
        }
        .padding()
    }
}

// MARK: - macOS Stat Card

struct MacStatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    var trend: Int? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
                if let trend = trend, trend != 0 {
                    HStack(spacing: 2) {
                        Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text("\(abs(trend))")
                            .font(.caption.bold())
                    }
                    .foregroundStyle(trend > 0 ? .green : .red)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(trend > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    )
                }
            }
            
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

// MARK: - macOS Charts

struct MacTagDistributionChart: View {
    let data: [TagStatItem]
    
    var body: some View {
        HStack(spacing: 20) {
            Chart(data) { item in
                SectorMark(
                    angle: .value("멘티 수", item.count),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .cornerRadius(4)
                .foregroundStyle(Color(hex: item.tagColor) ?? .gray)
            }
            .frame(width: 150, height: 150)
            
            VStack(alignment: .leading, spacing: 6) {
                ForEach(data.prefix(6)) { item in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color(hex: item.tagColor) ?? .gray)
                            .frame(width: 10, height: 10)
                        
                        Text(item.tagName)
                            .font(.caption)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text("\(item.count)명")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct MacRatioChart: View {
    let activeCount: Int
    let neglectedCount: Int
    
    private var data: [(label: String, count: Int, color: Color)] {
        [
            ("활성", activeCount, .green),
            ("소홀", neglectedCount, .red)
        ]
    }
    
    var body: some View {
        HStack(spacing: 20) {
            Chart(data, id: \.label) { item in
                SectorMark(
                    angle: .value("멘티 수", item.count),
                    innerRadius: .ratio(0.6),
                    angularInset: 2
                )
                .cornerRadius(4)
                .foregroundStyle(item.color)
            }
            .frame(width: 120, height: 120)
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(data, id: \.label) { item in
                    HStack {
                        Circle()
                            .fill(item.color)
                            .frame(width: 12, height: 12)
                        Text(item.label)
                            .font(.subheadline)
                        Spacer()
                        Text("\(item.count)명")
                            .font(.subheadline.bold())
                    }
                }
            }
        }
    }
}

struct MacWeeklyChart: View {
    let data: [DailyInteraction]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("요일", item.dayOfWeek),
                y: .value("상담 수", item.count)
            )
            .foregroundStyle(Color.blue.gradient)
            .cornerRadius(4)
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
    }
}

struct MacMonthComparisonChart: View {
    let thisMonth: Int
    let lastMonth: Int
    
    private var data: [(label: String, value: Int, color: Color)] {
        [
            ("지난 달", lastMonth, .gray),
            ("이번 달", thisMonth, .blue)
        ]
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Chart {
                ForEach(data, id: \.label) { item in
                    BarMark(
                        x: .value("월", item.label),
                        y: .value("상담 수", item.value)
                    )
                    .foregroundStyle(item.color.gradient)
                    .cornerRadius(8)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(item.value)회")
                            .font(.caption.bold())
                            .foregroundStyle(item.color)
                    }
                }
            }
            .frame(height: 180)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            
            // 성장 지표
            HStack {
                let diff = thisMonth - lastMonth
                let percentage = lastMonth > 0 ? abs(diff) * 100 / lastMonth : (diff > 0 ? 100 : 0)
                
                Image(systemName: diff >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(diff >= 0 ? .green : .red)
                
                Text(diff >= 0 ? "+\(diff)회 (\(percentage)% 증가)" : "\(diff)회 (\(percentage)% 감소)")
                    .font(.subheadline)
                    .foregroundStyle(diff >= 0 ? .green : .red)
                
                Spacer()
            }
        }
    }
}

struct MacInteractionTypeChart: View {
    let data: [InteractionTypeStat]
    
    var body: some View {
        Chart(data) { item in
            BarMark(
                x: .value("횟수", item.count),
                y: .value("유형", item.type.title)
            )
            .foregroundStyle(item.type.color.gradient)
            .cornerRadius(4)
            .annotation(position: .trailing, spacing: 8) {
                Text("\(item.count)회 (\(Int(item.percentage))%)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: CGFloat(data.count * 40 + 20))
        .chartXAxis(.hidden)
    }
}

// MARK: - macOS Ranking List

struct MacRankingList: View {
    let title: String
    let icon: String
    let iconColor: Color
    let data: [MenteeRank]
    let emptyMessage: String
    var valueFormatter: ((Int) -> String)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            if data.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar.doc.horizontal")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        MacRankingRow(
                            rank: index + 1,
                            item: item,
                            valueFormatter: valueFormatter
                        )
                        
                        if index < data.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct MacRankingRow: View {
    let rank: Int
    let item: MenteeRank
    var valueFormatter: ((Int) -> String)?
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 순위
            if rank <= 3 {
                Image(systemName: "medal.fill")
                    .foregroundStyle(rankColor)
                    .frame(width: 24)
            } else {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }
            
            // 프로필
            MacProfileImage(imageData: item.imageData, size: 32)
            
            // 이름
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 값
            Text(valueFormatter?(item.value) ?? "\(item.value)")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

struct MacProfileImage: View {
    let imageData: Data?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let data = imageData,
               let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Preview

#Preview {
    MacStatisticsView()
        .modelContainer(for: [Person.self, PersonTag.self])
}
