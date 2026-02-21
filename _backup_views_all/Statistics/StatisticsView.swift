//
//  StatisticsView.swift
//  RapportMap
//
//  멘토링 활동 통계 메인 뷰 (iOS)
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var people: [Person]
    
    @StateObject private var statisticsService = StatisticsService()
    @State private var selectedTab: StatisticsTab = .overview
    
    var body: some View {
        NavigationStack {
            Group {
                if statisticsService.isLoading {
                    loadingView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            // 탭 선택
                            Picker("통계 유형", selection: $selectedTab) {
                                ForEach(StatisticsTab.allCases) { tab in
                                    Text(tab.title).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                            
                            switch selectedTab {
                            case .overview:
                                overviewSection
                            case .activity:
                                activitySection
                            case .mentees:
                                menteesSection
                            }
                        }
                        .padding(.vertical)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        Task {
                            await statisticsService.calculateStatistics(people: people)
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
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
    
    // MARK: - Overview Section (전체 현황)
    
    private var overviewSection: some View {
        VStack(spacing: 16) {
            // 주요 숫자 카드들
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatisticsCard(
                    title: "총 멘티 수",
                    value: "\(statisticsService.statistics.totalMentees)",
                    subtitle: "전체 관리 인원",
                    icon: "person.3.fill",
                    color: .blue
                )
                
                StatisticsCard(
                    title: "이번 달 상담",
                    value: "\(statisticsService.statistics.thisMonthInteractions)",
                    subtitle: "일평균 \(String(format: "%.1f", statisticsService.statistics.dailyAverage))회",
                    icon: "message.fill",
                    color: .green,
                    trend: statisticsService.statistics.monthlyGrowth
                )
                
                StatisticsCard(
                    title: "활성 멘티",
                    value: "\(statisticsService.statistics.activeMentees)",
                    subtitle: "\(Int(statisticsService.statistics.activeRatio * 100))%",
                    icon: "bolt.fill",
                    color: .orange
                )
                
                StatisticsCard(
                    title: "소홀한 멘티",
                    value: "\(statisticsService.statistics.neglectedMentees)",
                    subtitle: "관심 필요",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                )
            }
            .padding(.horizontal)
            
            // 활성화 비율
            RatioCard(
                title: "멘티 활성화 비율",
                ratio: statisticsService.statistics.activeRatio,
                activeLabel: "활성",
                inactiveLabel: "소홀",
                activeColor: .green,
                inactiveColor: .red
            )
            .padding(.horizontal)
            
            // 태그 분포
            if !statisticsService.statistics.tagDistribution.isEmpty {
                TagDistributionChart(data: statisticsService.statistics.tagDistribution)
                    .padding(.horizontal)
            }
        }
    }
    
    // MARK: - Activity Section (상담 활동)
    
    private var activitySection: some View {
        VStack(spacing: 16) {
            // 주간 추이
            if !statisticsService.statistics.weeklyInteractions.isEmpty {
                WeeklyBarChart(data: statisticsService.statistics.weeklyInteractions)
                    .padding(.horizontal)
            }
            
            // 월별 비교
            MonthComparisonChart(
                thisMonth: statisticsService.statistics.thisMonthInteractions,
                lastMonth: statisticsService.statistics.lastMonthInteractions
            )
            .padding(.horizontal)
            
            // 상호작용 유형별
            if !statisticsService.statistics.interactionTypeStats.isEmpty {
                InteractionTypeChart(data: statisticsService.statistics.interactionTypeStats)
                    .padding(.horizontal)
            }
            
            // 일평균 상담 수
            StatisticsCard(
                title: "일평균 상담 수",
                value: String(format: "%.1f", statisticsService.statistics.dailyAverage),
                subtitle: "이번 달 기준",
                icon: "chart.line.uptrend.xyaxis",
                color: .purple
            )
            .padding(.horizontal)
        }
    }
    
    // MARK: - Mentees Section (멘티별 통계)
    
    private var menteesSection: some View {
        VStack(spacing: 16) {
            // 가장 많이 상담한 멘티
            RankingList(
                title: "가장 많이 상담한 멘티",
                icon: "flame.fill",
                iconColor: .orange,
                data: statisticsService.statistics.topInteractedMentees,
                emptyMessage: "이번 달 상담 기록이 없습니다",
                valueFormatter: { "\($0)회" }
            )
            .padding(.horizontal)
            
            // 오래 연락 안 한 멘티
            RankingList(
                title: "오래 연락 안 한 멘티",
                icon: "clock.badge.exclamationmark.fill",
                iconColor: .red,
                data: statisticsService.statistics.leastContactedMentees,
                emptyMessage: "모든 멘티와 최근 연락했습니다",
                valueFormatter: { "\($0)일" }
            )
            .padding(.horizontal)
            
            // 미해결 항목이 많은 멘티
            RankingList(
                title: "미해결 항목이 많은 멘티",
                icon: "checklist.unchecked",
                iconColor: .purple,
                data: statisticsService.statistics.menteesWithUnresolved,
                emptyMessage: "모든 항목이 해결되었습니다",
                valueFormatter: { "\($0)개" }
            )
            .padding(.horizontal)
        }
    }
}

// MARK: - Statistics Tab Enum

enum StatisticsTab: String, CaseIterable, Identifiable {
    case overview = "overview"
    case activity = "activity"
    case mentees = "mentees"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .overview: return "전체 현황"
        case .activity: return "상담 활동"
        case .mentees: return "멘티별"
        }
    }
    
    var icon: String {
        switch self {
        case .overview: return "chart.pie.fill"
        case .activity: return "chart.bar.fill"
        case .mentees: return "person.2.fill"
        }
    }
}

// MARK: - Preview

#Preview {
    StatisticsView()
        .modelContainer(for: [Person.self, PersonTag.self])
}
