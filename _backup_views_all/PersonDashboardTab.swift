//
//  PersonDashboardTab.swift
//  RapportMap
//
//  개인 대시보드 - PersonDetailView의 첫 번째 탭
//  마지막 만남, 관계 상태, 미해결 사항, 태그, 다음 액션 추천 등을 한눈에 보여줌
//

import SwiftUI
import SwiftData

struct PersonDashboardTab: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var context
    
    // MARK: - Computed Properties
    
    /// 마지막 만남으로부터 경과 일수
    private var daysSinceLastMeeting: Int? {
        guard let lastDate = person.mostRecentInteractionDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }
    
    /// 관계 상태 (활발/정체/위험)
    private var relationshipStatus: RelationshipStatus {
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
    private var nextActionRecommendations: [ActionRecommendation] {
        var recommendations: [ActionRecommendation] = []
        
        // 1. 오래 연락 안했을 때
        if let days = daysSinceLastMeeting {
            if days > 14 {
                recommendations.append(ActionRecommendation(
                    icon: "phone.fill",
                    title: "안부 연락하기",
                    subtitle: "\(days)일째 연락이 없어요",
                    priority: .high,
                    color: .red
                ))
            } else if days > 7 {
                recommendations.append(ActionRecommendation(
                    icon: "message.fill",
                    title: "가벼운 인사 보내기",
                    subtitle: "일주일이 지났어요",
                    priority: .medium,
                    color: .orange
                ))
            }
        }
        
        // 2. 미해결 약속이 있을 때
        if unresolvedPromisesCount > 0 {
            recommendations.append(ActionRecommendation(
                icon: "checkmark.circle.fill",
                title: "약속 이행하기",
                subtitle: "\(unresolvedPromisesCount)개의 약속이 대기 중",
                priority: .high,
                color: .blue
            ))
        }
        
        // 3. 미해결 질문이 있을 때
        if unresolvedQuestionsCount > 0 {
            recommendations.append(ActionRecommendation(
                icon: "questionmark.circle.fill",
                title: "질문에 답변하기",
                subtitle: "\(unresolvedQuestionsCount)개의 질문이 대기 중",
                priority: .medium,
                color: .purple
            ))
        }
        
        // 4. 고민이 방치되어 있을 때
        if unresolvedConcernsCount > 0 {
            recommendations.append(ActionRecommendation(
                icon: "heart.fill",
                title: "고민 들어주기",
                subtitle: "\(unresolvedConcernsCount)개의 고민이 있어요",
                priority: .high,
                color: .pink
            ))
        }
        
        // 5. 식사한 지 오래됐을 때
        if let lastMeal = person.lastMeal {
            let daysSinceMeal = Calendar.current.dateComponents([.day], from: lastMeal, to: Date()).day ?? 0
            if daysSinceMeal > 30 {
                recommendations.append(ActionRecommendation(
                    icon: "fork.knife",
                    title: "함께 식사하기",
                    subtitle: "한 달 넘게 함께 식사를 안 했어요",
                    priority: .low,
                    color: .green
                ))
            }
        }
        
        // 우선순위 순으로 정렬
        return recommendations.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - Body
    
    var body: some View {
        List {
            // 관계 상태 카드
            Section {
                RelationshipStatusCard(
                    status: relationshipStatus,
                    daysSinceLastMeeting: daysSinceLastMeeting,
                    meetingsThisMonth: meetingsThisMonth
                )
            }
            
            // 미해결 사항
            if unresolvedPromisesCount > 0 || unresolvedQuestionsCount > 0 || unresolvedConcernsCount > 0 {
                Section("📋 미해결 사항") {
                    UnresolvedItemsView(
                        promises: unresolvedPromisesCount,
                        questions: unresolvedQuestionsCount,
                        concerns: unresolvedConcernsCount
                    )
                }
            }
            
            // 태그
            if !person.tags.isEmpty {
                Section("🏷️ 태그") {
                    TagsFlowView(tags: person.tags, isCompact: false)
                }
            }
            
            // 다음 액션 추천
            if !nextActionRecommendations.isEmpty {
                Section("💡 다음 액션 추천") {
                    ForEach(nextActionRecommendations) { recommendation in
                        ActionRecommendationRow(recommendation: recommendation)
                    }
                }
            }
            
            // 빠른 기록
            Section("⚡️ 빠른 기록") {
                QuickRecordButtons(person: person)
            }
        }
    }
}

// MARK: - Supporting Types

enum RelationshipStatus {
    case active     // 활발
    case stagnant   // 정체
    case danger     // 위험
    case unknown    // 알 수 없음
    
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

struct ActionRecommendation: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let subtitle: String
    let priority: Priority
    let color: Color
    
    enum Priority: Int {
        case low = 0
        case medium = 1
        case high = 2
    }
}

// MARK: - Subviews

struct RelationshipStatusCard: View {
    let status: RelationshipStatus
    let daysSinceLastMeeting: Int?
    let meetingsThisMonth: Int
    
    var body: some View {
        VStack(spacing: 16) {
            // 상태 표시
            HStack {
                Image(systemName: status.icon)
                    .font(.title)
                    .foregroundStyle(status.color)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("관계 상태")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(status.title)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(status.color)
                }
                
                Spacer()
            }
            
            Divider()
            
            // 통계
            HStack(spacing: 24) {
                StatItem(
                    title: "마지막 만남",
                    value: daysSinceLastMeeting.map { "\($0)일 전" } ?? "없음",
                    icon: "calendar"
                )
                
                StatItem(
                    title: "이번 달 만남",
                    value: "\(meetingsThisMonth)회",
                    icon: "person.2.fill"
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status.color.opacity(0.1))
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }
}

struct UnresolvedItemsView: View {
    let promises: Int
    let questions: Int
    let concerns: Int
    
    var body: some View {
        HStack(spacing: 16) {
            if promises > 0 {
                UnresolvedBadge(count: promises, title: "약속", color: .blue, icon: "checkmark.circle")
            }
            if questions > 0 {
                UnresolvedBadge(count: questions, title: "질문", color: .purple, icon: "questionmark.circle")
            }
            if concerns > 0 {
                UnresolvedBadge(count: concerns, title: "고민", color: .pink, icon: "heart")
            }
        }
    }
}

struct UnresolvedBadge: View {
    let count: Int
    let title: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            
            Text("\(count)")
                .font(.headline)
                .foregroundStyle(.primary)
            
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct ActionRecommendationRow: View {
    let recommendation: ActionRecommendation
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(recommendation.color.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Image(systemName: recommendation.icon)
                    .foregroundStyle(recommendation.color)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(recommendation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(recommendation.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 우선순위 표시
            if recommendation.priority == .high {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 4)
    }
}

struct QuickRecordButtons: View {
    @Bindable var person: Person
    @Environment(\.modelContext) private var context
    @State private var showingQuickRecord = false
    @State private var showingVoiceRecorder = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "대화 기록",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: .blue
                ) {
                    showingQuickRecord = true
                }
                
                QuickActionButton(
                    title: "음성 녹음",
                    icon: "waveform.circle.fill",
                    color: .red
                ) {
                    showingVoiceRecorder = true
                }
            }
            
            HStack(spacing: 12) {
                QuickActionButton(
                    title: "전화함",
                    icon: "phone.fill",
                    color: .green
                ) {
                    recordInteraction(.call)
                }
                
                QuickActionButton(
                    title: "메시지함",
                    icon: "message.fill",
                    color: .orange
                ) {
                    recordInteraction(.message)
                }
            }
        }
        .sheet(isPresented: $showingQuickRecord) {
            QuickRecordSheet(person: person)
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView(person: person)
        }
    }
    
    private func recordInteraction(_ type: InteractionType) {
        _ = person.addInteractionRecord(type: type, date: Date())
        try? context.save()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PersonDashboardTab(person: Person(name: "홍길동"))
        .modelContainer(for: [Person.self])
}
