//
//  MacPersonDashboardTab.swift
//  mac
//
//  macOS용 개인 대시보드 탭
//  마지막 만남, 관계 상태, 미해결 사항, 태그, 다음 액션 추천 등을 한눈에 보여줌
//

import SwiftUI
import SwiftData

struct MacPersonDashboardTab: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var context
    
    // MARK: - Computed Properties
    
    /// 마지막 만남으로부터 경과 일수
    private var daysSinceLastMeeting: Int? {
        guard let lastDate = person.mostRecentInteractionDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }
    
    /// 관계 상태
    private var relationshipStatus: MacRelationshipStatus {
        if person.isNeglected {
            return .danger
        }
        
        guard let days = daysSinceLastMeeting else {
            return .unknown
        }
        
        if days <= 7 {
            return .active
        } else if days <= 21 {
            return .stagnant
        } else {
            return .danger
        }
    }
    
    /// 미해결 약속 수
    private var unresolvedPromisesCount: Int {
        person.conversationRecords.filter { $0.type == .promise && !$0.isResolved }.count
    }
    
    /// 미해결 질문 수
    private var unresolvedQuestionsCount: Int {
        person.conversationRecords.filter { $0.type == .question && !$0.isResolved }.count
    }
    
    /// 미해결 고민 수
    private var unresolvedConcernsCount: Int {
        person.conversationRecords.filter { $0.type == .concern && !$0.isResolved }.count
    }
    
    /// 이번 달 만남 횟수
    private var meetingsThisMonth: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        return person.interactionRecords.filter { record in
            record.date >= startOfMonth && record.date <= now
        }.count + person.meetingRecords.filter { meeting in
            meeting.date >= startOfMonth && meeting.date <= now
        }.count
    }
    
    /// 다음 액션 추천
    private var nextActionRecommendations: [MacActionRecommendation] {
        var recommendations: [MacActionRecommendation] = []
        
        if let days = daysSinceLastMeeting {
            if days > 14 {
                recommendations.append(MacActionRecommendation(
                    icon: "phone.fill",
                    title: "안부 연락하기",
                    subtitle: "\(days)일째 연락이 없어요",
                    priority: .high,
                    color: .red
                ))
            } else if days > 7 {
                recommendations.append(MacActionRecommendation(
                    icon: "message.fill",
                    title: "가벼운 인사 보내기",
                    subtitle: "일주일이 지났어요",
                    priority: .medium,
                    color: .orange
                ))
            }
        }
        
        if unresolvedPromisesCount > 0 {
            recommendations.append(MacActionRecommendation(
                icon: "checkmark.circle.fill",
                title: "약속 이행하기",
                subtitle: "\(unresolvedPromisesCount)개의 약속이 대기 중",
                priority: .high,
                color: .blue
            ))
        }
        
        if unresolvedQuestionsCount > 0 {
            recommendations.append(MacActionRecommendation(
                icon: "questionmark.circle.fill",
                title: "질문에 답변하기",
                subtitle: "\(unresolvedQuestionsCount)개의 질문이 대기 중",
                priority: .medium,
                color: .purple
            ))
        }
        
        if unresolvedConcernsCount > 0 {
            recommendations.append(MacActionRecommendation(
                icon: "heart.fill",
                title: "고민 들어주기",
                subtitle: "\(unresolvedConcernsCount)개의 고민이 있어요",
                priority: .high,
                color: .pink
            ))
        }
        
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Body
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 관계 상태 카드
                MacRelationshipStatusCard(
                    status: relationshipStatus,
                    daysSinceLastMeeting: daysSinceLastMeeting,
                    meetingsThisMonth: meetingsThisMonth
                )
                
                HStack(alignment: .top, spacing: 20) {
                    // 왼쪽: 미해결 사항 + 태그
                    VStack(spacing: 20) {
                        // 미해결 사항
                        if unresolvedPromisesCount > 0 || unresolvedQuestionsCount > 0 || unresolvedConcernsCount > 0 {
                            MacUnresolvedItemsCard(
                                promises: unresolvedPromisesCount,
                                questions: unresolvedQuestionsCount,
                                concerns: unresolvedConcernsCount
                            )
                        }
                        
                        // 태그
                        if !person.tags.isEmpty {
                            MacTagsCard(tags: person.tags)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    // 오른쪽: 다음 액션 추천
                    if !nextActionRecommendations.isEmpty {
                        MacRecommendationsCard(recommendations: nextActionRecommendations)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Supporting Types

enum MacRelationshipStatus {
    case active, stagnant, danger, unknown
    
    var title: String {
        switch self {
        case .active: return "활발"
        case .stagnant: return "정체"
        case .danger: return "위험"
        case .unknown: return "알 수 없음"
        }
    }
    
    var color: Color {
        switch self {
        case .active: return .green
        case .stagnant: return .orange
        case .danger: return .red
        case .unknown: return .gray
        }
    }
    
    var icon: String {
        switch self {
        case .active: return "heart.fill"
        case .stagnant: return "pause.circle.fill"
        case .danger: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }
}

struct MacActionRecommendation: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let priority: Priority
    let color: Color
    
    enum Priority: Int {
        case low = 0, medium = 1, high = 2
    }
}

// MARK: - Subviews

struct MacRelationshipStatusCard: View {
    let status: MacRelationshipStatus
    let daysSinceLastMeeting: Int?
    let meetingsThisMonth: Int
    
    var body: some View {
        HStack(spacing: 40) {
            // 상태
            HStack(spacing: 12) {
                Image(systemName: status.icon)
                    .font(.largeTitle)
                    .foregroundStyle(status.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("관계 상태")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(status.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(status.color)
                }
            }
            
            Divider()
                .frame(height: 50)
            
            // 마지막 만남
            VStack(alignment: .leading, spacing: 4) {
                Text("마지막 만남")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(daysSinceLastMeeting.map { "\($0)일 전" } ?? "없음")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Divider()
                .frame(height: 50)
            
            // 이번 달 만남
            VStack(alignment: .leading, spacing: 4) {
                Text("이번 달 만남")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(meetingsThisMonth)회")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.color.opacity(0.1))
        )
    }
}

struct MacUnresolvedItemsCard: View {
    let promises: Int
    let questions: Int
    let concerns: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("📋 미해결 사항")
                .font(.headline)
            
            HStack(spacing: 20) {
                if promises > 0 {
                    MacUnresolvedBadge(count: promises, title: "약속", color: .blue, icon: "checkmark.circle")
                }
                if questions > 0 {
                    MacUnresolvedBadge(count: questions, title: "질문", color: .purple, icon: "questionmark.circle")
                }
                if concerns > 0 {
                    MacUnresolvedBadge(count: concerns, title: "고민", color: .pink, icon: "heart")
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct MacUnresolvedBadge: View {
    let count: Int
    let title: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct MacTagsCard: View {
    let tags: [PersonTag]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("🏷️ 태그")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(tags, id: \.id) { tag in
                    Text(tag.name)
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: tag.colorHex).opacity(0.2))
                        .foregroundStyle(Color(hex: tag.colorHex))
                        .cornerRadius(16)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}

struct MacRecommendationsCard: View {
    let recommendations: [MacActionRecommendation]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("💡 다음 액션 추천")
                .font(.headline)
            
            ForEach(recommendations) { rec in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(rec.color.opacity(0.2))
                            .frame(width: 40, height: 40)
                        
                        Image(systemName: rec.icon)
                            .foregroundStyle(rec.color)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rec.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text(rec.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    if rec.priority == .high {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
}


#Preview {
    MacPersonDashboardTab(person: Person(name: "홍길동"))
        .modelContainer(for: [Person.self])
}
