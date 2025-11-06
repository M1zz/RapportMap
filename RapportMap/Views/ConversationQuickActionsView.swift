import SwiftUI
import SwiftData

/// 대화/상태를 빠르게 추가할 수 있는 퀵 액션 버튼들
/// PersonDetailView나 다른 뷰에서 사용할 수 있는 컴포넌트
struct ConversationQuickActionsView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    let person: Person
    
    // MARK: - State
    @State private var showingAddConversation = false
    @State private var preselectedType: ConversationType = .question
    
    // MARK: - Quick Action Types
    private let quickActionTypes: [ConversationType] = [
        .question, .concern, .promise, .update
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // MARK: - 헤더
            HStack {
                Label("대화/상태", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 전체 보기 버튼
                NavigationLink {
                    ConversationListView(person: person)
                } label: {
                    Text("전체 보기")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // MARK: - 퀵 액션 버튼들
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(quickActionTypes, id: \.self) { type in
                    QuickActionButton(
                        type: type,
                        count: person.getConversationRecords(ofType: type).count
                    ) {
                        preselectedType = type
                        showingAddConversation = true
                    }
                }
            }
            
            // MARK: - 요약 정보
            if person.hasConversationRecords {
                VStack(alignment: .leading, spacing: 8) {
                    Divider()
                    
                    ConversationSummaryView(person: person)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.3))
        .cornerRadius(12)
        .sheet(isPresented: $showingAddConversation) {
            AddConversationView(person: person)
                .onAppear {
                    // 미리 선택된 타입이 있다면 설정 (실제로는 AddConversationView를 수정해야 함)
                }
        }
    }
}

// MARK: - 퀵 액션 버튼 뷰
struct QuickActionButton: View {
    let type: ConversationType
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(type.color.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Text(type.emoji)
                        .font(.title3)
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(width: 16, height: 16)
                            .background(type.color)
                            .clipShape(Circle())
                            .offset(x: 12, y: -12)
                    }
                }
                
                Text(type.title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 대화 요약 뷰
struct ConversationSummaryView: View {
    let person: Person
    
    private var unresolvedConversations: [ConversationRecord] {
        person.getUnresolvedConversationRecords()
    }
    
    private var highPriorityCount: Int {
        unresolvedConversations.filter { $0.priority == .urgent || $0.priority == .high }.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 전체 요약
            Text(person.conversationSummary)
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 미해결 대화가 있는 경우 상세 정보
            if !unresolvedConversations.isEmpty {
                HStack(spacing: 12) {
                    // 높은 우선순위
                    if highPriorityCount > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text("중요 \(highPriorityCount)개")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    // 최근 미해결 대화
                    if let recentUnresolved = unresolvedConversations.first {
                        HStack(spacing: 4) {
                            Text(recentUnresolved.type.emoji)
                                .font(.caption)
                            Text(recentUnresolved.relativeDate)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
            }
            
            // 최근 미해결 대화 내용 (1개만)
            if let recentConversation = unresolvedConversations.first {
                Text(recentConversation.content)
                    .font(.caption)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .padding(.top, 2)
            }
        }
    }
}

// MARK: - 대화 상태 표시 뷰
/// PersonDetailView에서 사용할 수 있는 간단한 상태 표시 뷰
struct ConversationStatusView: View {
    let person: Person
    
    var body: some View {
        HStack(spacing: 8) {
            // 미해결 질문 수
            if person.currentUnansweredCount > 0 {
                StatusBadge(
                    icon: "questionmark.circle.fill",
                    count: person.currentUnansweredCount,
                    color: .blue,
                    label: "미답변"
                )
            }
            
            // 미해결 약속 수
            let promiseCount = person.currentUnresolvedPromises.count
            if promiseCount > 0 {
                StatusBadge(
                    icon: "handshake.fill",
                    count: promiseCount,
                    color: .green,
                    label: "미이행"
                )
            }
            
            // 현재 고민 수
            let concernCount = person.currentConcerns.count
            if concernCount > 0 {
                StatusBadge(
                    icon: "person.badge.minus",
                    count: concernCount,
                    color: .orange,
                    label: "고민"
                )
            }
            
            // 높은 우선순위 미해결 대화
            if person.hasHighPriorityUnresolvedConversations {
                StatusBadge(
                    icon: "exclamationmark.triangle.fill",
                    count: person.getHighPriorityUnresolvedConversations().count,
                    color: .red,
                    label: "긴급"
                )
            }
        }
    }
}

// MARK: - 상태 배지 뷰
struct StatusBadge: View {
    let icon: String
    let count: Int
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.medium)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview
#Preview {
    let person = Person(name: "김철수")
    
    return VStack(spacing: 20) {
        ConversationQuickActionsView(person: person)
        ConversationStatusView(person: person)
    }
    .padding()
    .modelContainer(for: [Person.self, ConversationRecord.self])
}