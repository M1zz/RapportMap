//
//  DashboardView.swift
//  RapportMap
//
//  앱 메인 대시보드 - 현황 한눈에 보기
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \PersonTag.order) private var tags: [PersonTag]
    
    @StateObject private var dataProvider = DashboardDataProvider()
    @Binding var selectedTab: Int
    @State private var selectedPerson: Person?
    @State private var showingPersonDetail = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // 상태 요약 헤더
                    statusHeader
                    
                    // 🔴 오늘 연락해야 할 사람
                    if !dataProvider.todayContacts.isEmpty {
                        DashboardSection(
                            title: "오늘 연락 필요",
                            icon: "exclamationmark.circle.fill",
                            iconColor: .red,
                            count: dataProvider.todayContacts.count
                        ) {
                            ForEach(dataProvider.todayContacts.prefix(5)) { person in
                                DashboardPersonRow(person: person) {
                                    selectedPerson = person
                                    showingPersonDetail = true
                                }
                            }
                            
                            if dataProvider.todayContacts.count > 5 {
                                moreButton(count: dataProvider.todayContacts.count - 5) {
                                    // 필터 적용 후 목록 탭으로 이동
                                    selectedTab = 1
                                }
                            }
                        }
                    }
                    
                    // 🟡 이번 주 주의 필요
                    if !dataProvider.weeklyAttention.isEmpty {
                        DashboardSection(
                            title: "이번 주 주의 필요",
                            icon: "exclamationmark.triangle.fill",
                            iconColor: .orange,
                            count: dataProvider.weeklyAttention.count
                        ) {
                            ForEach(dataProvider.weeklyAttention.prefix(3)) { person in
                                DashboardPersonRow(person: person) {
                                    selectedPerson = person
                                    showingPersonDetail = true
                                }
                            }
                            
                            if dataProvider.weeklyAttention.count > 3 {
                                moreButton(count: dataProvider.weeklyAttention.count - 3) {
                                    selectedTab = 1
                                }
                            }
                        }
                    }
                    
                    // 📊 이번 달 현황
                    DashboardSection(
                        title: "이번 달 현황",
                        icon: "chart.bar.fill",
                        iconColor: .blue
                    ) {
                        monthlyStatsGrid
                    }
                    
                    // 🏷️ 태그별 현황
                    if !dataProvider.tagStats.isEmpty {
                        DashboardSection(
                            title: "태그별 현황",
                            icon: "tag.fill",
                            iconColor: .purple
                        ) {
                            tagStatsGrid
                        }
                    }
                    
                    // 최근 활동
                    if !dataProvider.recentActivities.isEmpty {
                        DashboardSection(
                            title: "최근 활동",
                            icon: "clock.fill",
                            iconColor: .green
                        ) {
                            ForEach(dataProvider.recentActivities) { activity in
                                recentActivityRow(activity)
                            }
                        }
                    }
                    
                    // 모든 관계가 잘 관리되고 있을 때
                    if dataProvider.todayContacts.isEmpty && dataProvider.weeklyAttention.isEmpty {
                        allGoodView
                    }
                }
                .padding()
            }
            .navigationTitle("대시보드")
            .refreshable {
                dataProvider.refresh(people: people, tags: tags)
            }
            .onAppear {
                dataProvider.refresh(people: people, tags: tags)
            }
            .onChange(of: people) { _, _ in
                dataProvider.refresh(people: people, tags: tags)
            }
            .navigationDestination(isPresented: $showingPersonDetail) {
                if let person = selectedPerson {
                    PersonDetailView(person: person, selectedTab: .constant(0))
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var statusHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: dataProvider.overallStatus.icon)
                .font(.title)
                .foregroundStyle(dataProvider.overallStatus.color)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(dataProvider.summaryText)
                    .font(.headline)
                
                Text("전체 \(people.count)명 관리 중")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dataProvider.overallStatus.color.opacity(0.1))
        )
    }
    
    private var monthlyStatsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "멘토링",
                value: "\(dataProvider.monthlyStats.totalMentoringSessions)회",
                icon: "person.2.fill",
                color: .blue
            )
            
            StatCard(
                title: "새 멘티",
                value: "\(dataProvider.monthlyStats.newMentees)명",
                icon: "person.badge.plus",
                color: .green
            )
            
            StatCard(
                title: "총 상호작용",
                value: "\(dataProvider.monthlyStats.totalInteractions)회",
                icon: "message.fill",
                color: .purple
            )
            
            StatCard(
                title: "해결한 대화",
                value: "\(dataProvider.monthlyStats.resolvedConversations)건",
                icon: "checkmark.circle.fill",
                color: .orange
            )
        }
    }
    
    private var tagStatsGrid: some View {
        FlowLayout(spacing: 8) {
            ForEach(dataProvider.tagStats.prefix(8)) { stat in
                HStack(spacing: 4) {
                    if let icon = stat.tag.icon {
                        Image(systemName: icon)
                            .font(.caption)
                    }
                    Text(stat.tag.name)
                        .font(.caption)
                    Text("\(stat.count)")
                        .font(.caption)
                        .fontWeight(.bold)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(stat.isWarning ? Color.red.opacity(0.2) : stat.tag.swiftUIColor.opacity(0.2))
                )
                .foregroundStyle(stat.isWarning ? .red : stat.tag.swiftUIColor)
            }
        }
    }
    
    private func recentActivityRow(_ activity: DashboardDataProvider.RecentActivity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: activity.activityType.icon)
                .font(.caption)
                .foregroundStyle(activity.activityType.color)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(activity.activityType.color.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.personName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(activity.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(activity.date.relative())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
    
    private var allGoodView: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            
            Text("모든 관계가 잘 관리되고 있어요!")
                .font(.headline)
            
            Text("오늘도 좋은 하루 되세요 ☀️")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.1))
        )
    }
    
    private func moreButton(count: Int, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text("\(count)명 더 보기")
                    .font(.caption)
                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .foregroundStyle(.blue)
        }
        .padding(.top, 4)
    }
}

// MARK: - Dashboard Section

struct DashboardSection<Content: View>: View {
    let title: String
    let icon: String
    let iconColor: Color
    var count: Int? = nil
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                
                Text(title)
                    .font(.headline)
                
                if let count = count {
                    Text("\(count)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(iconColor))
                }
                
                Spacer()
            }
            
            content
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Dashboard Person Row

struct DashboardPersonRow: View {
    let person: Person
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 프로필 이미지
                if let imageData = person.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.gray.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    if let reason = person.neglectedReason.split(separator: "\n").first {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 마지막 연락
                if let lastDate = person.mostRecentInteractionDate {
                    Text(lastDate.relative())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    DashboardView(selectedTab: .constant(0))
        .modelContainer(for: [Person.self, PersonTag.self])
}
