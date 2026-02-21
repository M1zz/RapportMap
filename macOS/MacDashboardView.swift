//
//  MacDashboardView.swift
//  mac
//
//  macOS용 대시보드 뷰
//

import SwiftUI
import SwiftData

struct MacDashboardView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Query(sort: \PersonTag.order) private var tags: [PersonTag]
    
    @StateObject private var dataProvider = DashboardDataProvider()
    @Binding var selectedPerson: Person?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 상태 요약 헤더
                statusHeader
                
                // 메인 그리드
                HStack(alignment: .top, spacing: 20) {
                    // 왼쪽: 긴급/주의 필요
                    VStack(spacing: 16) {
                        // 🔴 오늘 연락해야 할 사람
                        if !dataProvider.todayContacts.isEmpty {
                            urgentContactsSection
                        }
                        
                        // 🟡 이번 주 주의 필요
                        if !dataProvider.weeklyAttention.isEmpty {
                            weeklyAttentionSection
                        }
                        
                        // 모든 관계가 잘 관리되고 있을 때
                        if dataProvider.todayContacts.isEmpty && dataProvider.weeklyAttention.isEmpty {
                            allGoodView
                        }
                    }
                    .frame(minWidth: 300)
                    
                    // 오른쪽: 통계 및 최근 활동
                    VStack(spacing: 16) {
                        // 📊 이번 달 현황
                        monthlyStatsSection
                        
                        // 🏷️ 태그별 현황
                        if !dataProvider.tagStats.isEmpty {
                            tagStatsSection
                        }
                        
                        // 최근 활동
                        if !dataProvider.recentActivities.isEmpty {
                            recentActivitiesSection
                        }
                    }
                    .frame(minWidth: 280)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            dataProvider.refresh(people: people, tags: tags)
        }
        .onChange(of: people) { _, _ in
            dataProvider.refresh(people: people, tags: tags)
        }
    }
    
    // MARK: - View Components
    
    private var statusHeader: some View {
        HStack(spacing: 16) {
            Image(systemName: dataProvider.overallStatus.icon)
                .font(.largeTitle)
                .foregroundStyle(dataProvider.overallStatus.color)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(dataProvider.summaryText)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("전체 \(people.count)명 관리 중 • \(formattedDate)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                dataProvider.refresh(people: people, tags: tags)
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(dataProvider.overallStatus.color.opacity(0.1))
        )
    }
    
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M월 d일 EEEE"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: Date())
    }
    
    private var urgentContactsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text("오늘 연락 필요")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(dataProvider.todayContacts.count)명")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.red))
                        .foregroundStyle(.white)
                }
                
                Divider()
                
                ForEach(dataProvider.todayContacts.prefix(6)) { person in
                    MacDashboardPersonRow(person: person) {
                        selectedPerson = person
                    }
                }
                
                if dataProvider.todayContacts.count > 6 {
                    Text("외 \(dataProvider.todayContacts.count - 6)명...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    private var weeklyAttentionSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("이번 주 주의 필요")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text("\(dataProvider.weeklyAttention.count)명")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.orange))
                        .foregroundStyle(.white)
                }
                
                Divider()
                
                ForEach(dataProvider.weeklyAttention.prefix(4)) { person in
                    MacDashboardPersonRow(person: person) {
                        selectedPerson = person
                    }
                }
                
                if dataProvider.weeklyAttention.count > 4 {
                    Text("외 \(dataProvider.weeklyAttention.count - 4)명...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
    }
    
    private var monthlyStatsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.bar.fill")
                        .foregroundStyle(.blue)
                    Text("이번 달 현황")
                        .font(.headline)
                    Spacer()
                }
                
                Divider()
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    MacStatCard(title: "멘토링", value: "\(dataProvider.monthlyStats.totalMentoringSessions)", icon: "person.2.fill", color: .blue)
                    MacStatCard(title: "새 멘티", value: "\(dataProvider.monthlyStats.newMentees)", icon: "person.badge.plus", color: .green)
                    MacStatCard(title: "총 상호작용", value: "\(dataProvider.monthlyStats.totalInteractions)", icon: "message.fill", color: .purple)
                    MacStatCard(title: "해결된 대화", value: "\(dataProvider.monthlyStats.resolvedConversations)", icon: "checkmark.circle.fill", color: .orange)
                }
            }
            .padding()
        }
    }
    
    private var tagStatsSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(.purple)
                    Text("태그별 현황")
                        .font(.headline)
                    Spacer()
                }
                
                Divider()
                
                FlowLayout(spacing: 8) {
                    ForEach(dataProvider.tagStats.prefix(10)) { stat in
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
            .padding()
        }
    }
    
    private var recentActivitiesSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(.green)
                    Text("최근 활동")
                        .font(.headline)
                    Spacer()
                }
                
                Divider()
                
                ForEach(dataProvider.recentActivities) { activity in
                    HStack(spacing: 10) {
                        Image(systemName: activity.activityType.icon)
                            .font(.caption)
                            .foregroundStyle(activity.activityType.color)
                            .frame(width: 20, height: 20)
                            .background(
                                Circle()
                                    .fill(activity.activityType.color.opacity(0.15))
                            )
                        
                        VStack(alignment: .leading, spacing: 1) {
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
                    .padding(.vertical, 2)
                }
            }
            .padding()
        }
    }
    
    private var allGoodView: some View {
        GroupBox {
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.green)
                
                Text("모든 관계가 잘 관리되고 있어요!")
                    .font(.headline)
                
                Text("오늘도 좋은 하루 되세요 ☀️")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 30)
        }
    }
}

// MARK: - Mac Dashboard Person Row

struct MacDashboardPersonRow: View {
    let person: Person
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                // 프로필 이미지
                if let imageData = person.profileImageData,
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .frame(width: 32, height: 32)
                        .foregroundStyle(.gray.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(person.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let reason = person.neglectedReason.split(separator: "\n").first {
                        Text(reason)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                if let lastDate = person.mostRecentInteractionDate {
                    Text(lastDate.relative())
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mac Stat Card

struct MacStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
}

#Preview {
    MacDashboardView(selectedPerson: .constant(nil))
        .modelContainer(for: [Person.self, PersonTag.self])
}
