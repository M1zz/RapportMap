//
//  MacPersonDashboardTab.swift
//  mac
//
//  macOS용 개인 대시보드 탭 - Person 상세 첫 화면
//

import SwiftUI
import SwiftData

struct MacPersonDashboardTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    
    @State private var showingVoiceRecorder = false
    @State private var showingAddConversation = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 관계 상태 카드
                relationshipStatusCard
                
                // 핵심 지표
                HStack(spacing: 16) {
                    statCard(
                        title: "마지막 만남",
                        value: lastInteractionText,
                        icon: "calendar",
                        color: lastInteractionColor
                    )
                    
                    statCard(
                        title: "이번 달 만남",
                        value: "\(thisMonthInteractionCount)회",
                        icon: "person.2",
                        color: .blue
                    )
                    
                    statCard(
                        title: "총 기록",
                        value: "\(totalRecordsCount)개",
                        icon: "doc.text",
                        color: .purple
                    )
                }
                
                // 미해결 사항
                if hasUnresolvedItems {
                    unresolvedItemsCard
                }
                
                // 태그
                if !person.tags.isEmpty {
                    tagsCard
                }
                
                // 다음 액션 추천
                nextActionCard
                
                // 빠른 기록 버튼
                quickActionsCard
                
                Spacer()
            }
            .padding()
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 관계 상태 카드
    
    private var relationshipStatusCard: some View {
        HStack(spacing: 16) {
            // 상태 아이콘
            Circle()
                .fill(relationshipStatusColor.opacity(0.2))
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: relationshipStatusIcon)
                        .font(.title)
                        .foregroundStyle(relationshipStatusColor)
                }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("관계 상태")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text(relationshipStatusText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(relationshipStatusColor)
                
                if person.isNeglected {
                    Text(person.neglectedReason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // 관계 기간
            VStack(alignment: .trailing, spacing: 4) {
                Text("관계 기간")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(relationshipDuration)
                    .font(.headline)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - 통계 카드
    
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - 미해결 사항 카드
    
    private var unresolvedItemsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.orange)
                Text("미해결 사항")
                    .font(.headline)
                Spacer()
            }
            
            HStack(spacing: 20) {
                if unresolvedPromisesCount > 0 {
                    Label("\(unresolvedPromisesCount)개 약속", systemImage: "handshake")
                        .foregroundStyle(.red)
                }
                
                if unresolvedQuestionsCount > 0 {
                    Label("\(unresolvedQuestionsCount)개 질문", systemImage: "questionmark.circle")
                        .foregroundStyle(.blue)
                }
                
                if unresolvedConcernsCount > 0 {
                    Label("\(unresolvedConcernsCount)개 고민", systemImage: "heart")
                        .foregroundStyle(.purple)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.orange.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    // MARK: - 태그 카드
    
    private var tagsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "tag.fill")
                    .foregroundStyle(.blue)
                Text("태그")
                    .font(.headline)
                Spacer()
            }
            
            FlowLayout(spacing: 8) {
                ForEach(person.tags) { tag in
                    TagBadge(tag: tag)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
    }
    
    // MARK: - 다음 액션 추천 카드
    
    private var nextActionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("추천 액션")
                    .font(.headline)
                Spacer()
            }
            
            Text(nextActionRecommendation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.yellow.opacity(0.1))
        )
    }
    
    // MARK: - 빠른 기록 버튼
    
    private var quickActionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("빠른 기록")
                .font(.headline)
            
            HStack(spacing: 12) {
                quickActionButton(title: "대화 기록", icon: "bubble.left.and.bubble.right", color: .blue) {
                    showingAddConversation = true
                }
                
                quickActionButton(title: "전화함", icon: "phone.fill", color: .green) {
                    addQuickInteraction(.call)
                }
                
                quickActionButton(title: "메시지함", icon: "message.fill", color: .orange) {
                    addQuickInteraction(.message)
                }
                
                quickActionButton(title: "만남", icon: "person.2.fill", color: .purple) {
                    addQuickInteraction(.meeting)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
        )
        .sheet(isPresented: $showingAddConversation) {
            AddConversationSheet(person: person)
        }
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Computed Properties
    
    private var relationshipStatusColor: Color {
        if person.isNeglected {
            return .red
        } else if daysSinceLastInteraction > 14 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var relationshipStatusIcon: String {
        if person.isNeglected {
            return "exclamationmark.triangle.fill"
        } else if daysSinceLastInteraction > 14 {
            return "clock.badge.exclamationmark"
        } else {
            return "checkmark.circle.fill"
        }
    }
    
    private var relationshipStatusText: String {
        if person.isNeglected {
            return "주의 필요"
        } else if daysSinceLastInteraction > 14 {
            return "정체"
        } else {
            return "활발"
        }
    }
    
    private var daysSinceLastInteraction: Int {
        guard let lastDate = person.mostRecentInteractionDate else {
            return 999
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 999
    }
    
    private var lastInteractionText: String {
        guard let lastDate = person.mostRecentInteractionDate else {
            return "기록 없음"
        }
        let days = daysSinceLastInteraction
        if days == 0 {
            return "오늘"
        } else if days == 1 {
            return "어제"
        } else if days < 7 {
            return "\(days)일 전"
        } else if days < 30 {
            return "\(days / 7)주 전"
        } else {
            return "\(days / 30)개월 전"
        }
    }
    
    private var lastInteractionColor: Color {
        let days = daysSinceLastInteraction
        if days <= 7 {
            return .green
        } else if days <= 21 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var thisMonthInteractionCount: Int {
        let calendar = Calendar.current
        let now = Date()
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        
        return person.interactionRecords.filter { $0.date >= startOfMonth }.count +
               person.meetingRecords.filter { $0.date >= startOfMonth }.count
    }
    
    private var totalRecordsCount: Int {
        person.interactionRecords.count +
        person.meetingRecords.count +
        person.conversationRecords.count
    }
    
    private var hasUnresolvedItems: Bool {
        unresolvedPromisesCount > 0 || unresolvedQuestionsCount > 0 || unresolvedConcernsCount > 0
    }
    
    private var unresolvedPromisesCount: Int {
        person.conversationRecords.filter { $0.type == .promise && !$0.isResolved }.count
    }
    
    private var unresolvedQuestionsCount: Int {
        person.conversationRecords.filter { $0.type == .question && !$0.isResolved }.count
    }
    
    private var unresolvedConcernsCount: Int {
        person.conversationRecords.filter { $0.type == .concern && !$0.isResolved }.count
    }
    
    private var relationshipDuration: String {
        let days = Calendar.current.dateComponents([.day], from: person.relationshipStartDate, to: Date()).day ?? 0
        if days < 30 {
            return "\(days)일"
        } else if days < 365 {
            return "\(days / 30)개월"
        } else {
            let years = days / 365
            let months = (days % 365) / 30
            if months > 0 {
                return "\(years)년 \(months)개월"
            }
            return "\(years)년"
        }
    }
    
    private var nextActionRecommendation: String {
        if person.isNeglected {
            return "🚨 연락이 오래됐어요. 안부 인사를 보내보세요!"
        } else if unresolvedPromisesCount > 0 {
            return "📝 미해결 약속이 있어요. 확인해보세요."
        } else if unresolvedQuestionsCount > 0 {
            return "❓ 답변을 기다리는 질문이 있어요."
        } else if daysSinceLastInteraction > 14 {
            return "📞 2주가 지났어요. 가벼운 연락을 해보세요."
        } else {
            return "✨ 관계가 잘 유지되고 있어요. 계속 이렇게!"
        }
    }
    
    // MARK: - Actions
    
    private func addQuickInteraction(_ type: InteractionType) {
        let record = person.addInteractionRecord(type: type, date: Date(), notes: nil)
        context.insert(record)
        try? context.save()
    }
}

// MARK: - Add Conversation Sheet

struct AddConversationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    
    @State private var content = ""
    @State private var selectedType: ConversationType = .update
    
    var body: some View {
        VStack(spacing: 20) {
            Text("대화 기록 추가")
                .font(.headline)
            
            Picker("유형", selection: $selectedType) {
                ForEach(ConversationType.allCases, id: \.self) { type in
                    Text(type.title).tag(type)
                }
            }
            .pickerStyle(.segmented)
            
            TextEditor(text: $content)
                .frame(height: 150)
                .border(Color.gray.opacity(0.3))
            
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("저장") {
                    saveConversation()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(content.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private func saveConversation() {
        let record = person.addConversationRecord(
            type: selectedType,
            content: content
        )
        context.insert(record)
        try? context.save()
        dismiss()
    }
}

#Preview {
    MacPersonDashboardTab(person: Person(name: "홍길동"))
        .modelContainer(for: [Person.self, PersonTag.self])
}
