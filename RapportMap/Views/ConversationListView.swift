import SwiftUI
import SwiftData

/// 대화/상태 기록 목록을 표시하는 뷰
/// 질문, 고민, 약속 등의 대화 내용을 카테고리별로 정리하여 보여줌
struct ConversationListView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    
    // MARK: - Properties
    let person: Person
    
    // MARK: - State
    @State private var showingAddConversation = false
    @State private var selectedFilter: ConversationFilter = .all
    @State private var searchText = ""
    @State private var showingStatistics = false
    
    // MARK: - Computed Properties
    private var filteredConversations: [ConversationRecord] {
        var conversations = person.conversationRecords
        
        // 필터 적용
        switch selectedFilter {
        case .all:
            break
        case .unresolved:
            conversations = conversations.filter { !$0.isResolved }
        case .resolved:
            conversations = conversations.filter { $0.isResolved }
        case .recent:
            conversations = conversations.filter { $0.isRecent }
        case .highPriority:
            conversations = conversations.filter { $0.priority == .urgent || $0.priority == .high }
        case .type(let type):
            conversations = conversations.filter { $0.type == type }
        }
        
        // 검색 적용
        if !searchText.isEmpty {
            conversations = conversations.filter { conversation in
                conversation.content.localizedCaseInsensitiveContains(searchText) ||
                conversation.notes?.localizedCaseInsensitiveContains(searchText) == true ||
                conversation.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        // 정렬: 미해결 > 우선순위 > 날짜
        return conversations.sorted { conversation1, conversation2 in
            if conversation1.isResolved != conversation2.isResolved {
                return !conversation1.isResolved && conversation2.isResolved
            }
            if conversation1.priority.sortOrder != conversation2.priority.sortOrder {
                return conversation1.priority.sortOrder > conversation2.priority.sortOrder
            }
            return conversation1.date > conversation2.date
        }
    }
    
    private var conversationsByType: [ConversationType: [ConversationRecord]] {
        Dictionary(grouping: filteredConversations) { $0.type }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // MARK: - 필터 및 검색
                VStack(spacing: 12) {
                    // 필터 버튼들
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(ConversationFilter.allFilters, id: \.self) { filter in
                                FilterButton(
                                    filter: filter,
                                    isSelected: selectedFilter == filter,
                                    count: getFilterCount(filter)
                                ) {
                                    selectedFilter = filter
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 검색바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("대화 내용, 메모, 태그 검색...", text: $searchText)
                            .textFieldStyle(.plain)
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
                
                Divider()
                
                // MARK: - 대화 목록
                if filteredConversations.isEmpty {
                    EmptyConversationView(filter: selectedFilter, searchText: searchText)
                } else {
                    List {
                        if selectedFilter == .all && searchText.isEmpty {
                            // 타입별로 그룹화하여 표시
                            ForEach(ConversationType.allCases, id: \.self) { type in
                                if let conversations = conversationsByType[type], !conversations.isEmpty {
                                    Section {
                                        ForEach(conversations, id: \.id) { conversation in
                                            ConversationRowView(conversation: conversation)
                                                .swipeActions(edge: .trailing) {
                                                    if !conversation.isResolved {
                                                        Button {
                                                            resolveConversation(conversation)
                                                        } label: {
                                                            Label("해결", systemImage: "checkmark")
                                                        }
                                                        .tint(.green)
                                                    }
                                                    
                                                    Button(role: .destructive) {
                                                        deleteConversation(conversation)
                                                    } label: {
                                                        Label("삭제", systemImage: "trash")
                                                    }
                                                }
                                        }
                                    } header: {
                                        HStack {
                                            Text(type.emoji)
                                            Text(type.title)
                                            Spacer()
                                            Text("\(conversations.count)개")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        } else {
                            // 필터링된 결과를 단순 목록으로 표시
                            ForEach(filteredConversations, id: \.id) { conversation in
                                ConversationRowView(conversation: conversation)
                                    .swipeActions(edge: .trailing) {
                                        if !conversation.isResolved {
                                            Button {
                                                resolveConversation(conversation)
                                            } label: {
                                                Label("해결", systemImage: "checkmark")
                                            }
                                            .tint(.green)
                                        }
                                        
                                        Button(role: .destructive) {
                                            deleteConversation(conversation)
                                        } label: {
                                            Label("삭제", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("\(person.name)님의 대화")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingStatistics = true
                    } label: {
                        Image(systemName: "chart.bar")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddConversation = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddConversation) {
                AddConversationView(person: person)
            }
            .sheet(isPresented: $showingStatistics) {
                ConversationStatisticsView(person: person)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFilterCount(_ filter: ConversationFilter) -> Int {
        switch filter {
        case .all:
            return person.conversationRecords.count
        case .unresolved:
            return person.getUnresolvedConversationRecords().count
        case .resolved:
            return person.conversationRecords.filter { $0.isResolved }.count
        case .recent:
            return person.getRecentConversationRecords().count
        case .highPriority:
            return person.getHighPriorityUnresolvedConversations().count
        case .type(let type):
            return person.getConversationRecords(ofType: type).count
        }
    }
    
    private func resolveConversation(_ conversation: ConversationRecord) {
        person.resolveConversationRecord(conversation)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ 대화 해결 상태 저장 실패: \(error)")
        }
    }
    
    private func deleteConversation(_ conversation: ConversationRecord) {
        modelContext.delete(conversation)
        
        do {
            try modelContext.save()
        } catch {
            print("❌ 대화 기록 삭제 실패: \(error)")
        }
    }
}

// MARK: - 대화 필터
enum ConversationFilter: Hashable {
    case all
    case unresolved
    case resolved
    case recent
    case highPriority
    case type(ConversationType)
    
    var title: String {
        switch self {
        case .all: return "전체"
        case .unresolved: return "미해결"
        case .resolved: return "해결됨"
        case .recent: return "최근"
        case .highPriority: return "높은 우선순위"
        case .type(let type): return type.title
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "list.bullet"
        case .unresolved: return "clock"
        case .resolved: return "checkmark.circle"
        case .recent: return "clock.arrow.circlepath"
        case .highPriority: return "exclamationmark.triangle"
        case .type(let type): return type.systemImage
        }
    }
    
    static var allFilters: [ConversationFilter] {
        var filters: [ConversationFilter] = [
            .all, .unresolved, .resolved, .recent, .highPriority
        ]
        filters.append(contentsOf: ConversationType.allCases.map { .type($0) })
        return filters
    }
}

// MARK: - 필터 버튼 뷰
struct FilterButton: View {
    let filter: ConversationFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: filter.icon)
                    .font(.caption)
                Text(filter.title)
                    .font(.caption)
                if count > 0 {
                    Text("(\(count))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? .blue : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 대화 행 뷰
struct ConversationRowView: View {
    let conversation: ConversationRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack {
                HStack(spacing: 6) {
                    Text(conversation.type.emoji)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(conversation.type.title)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(conversation.type.color)
                        
                        Text(conversation.relativeDate)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    // 우선순위
                    if conversation.priority != .normal {
                        Text(conversation.priority.emoji)
                            .font(.caption)
                    }
                    
                    // 상태
                    Image(systemName: conversation.isResolved ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(conversation.isResolved ? .green : .orange)
                        .font(.caption)
                }
            }
            
            // 내용
            Text(conversation.content)
                .font(.subheadline)
                .lineLimit(3)
            
            // 메모
            if let notes = conversation.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            // 태그
            if !conversation.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(conversation.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(4)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 빈 상태 뷰
struct EmptyConversationView: View {
    let filter: ConversationFilter
    let searchText: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "bubble.left.and.bubble.right" : "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(searchText.isEmpty ? getEmptyTitle() : "검색 결과 없음")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                Text(searchText.isEmpty ? getEmptyMessage() : "다른 검색어를 시도해보세요")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private func getEmptyTitle() -> String {
        switch filter {
        case .all: return "아직 대화 기록이 없어요"
        case .unresolved: return "미해결 대화가 없어요"
        case .resolved: return "해결된 대화가 없어요"
        case .recent: return "최근 대화가 없어요"
        case .highPriority: return "높은 우선순위 대화가 없어요"
        case .type(let type): return "\(type.title) 기록이 없어요"
        }
    }
    
    private func getEmptyMessage() -> String {
        switch filter {
        case .all: return "+ 버튼을 눌러 첫 번째 대화를 기록해보세요"
        case .unresolved: return "모든 대화가 해결되었네요! 👍"
        case .resolved: return "해결된 대화 기록이 여기에 표시됩니다"
        case .recent: return "최근 7일 내의 대화 기록이 여기에 표시됩니다"
        case .highPriority: return "긴급하거나 중요한 대화가 여기에 표시됩니다"
        case .type(let type): return "\(type.title) 관련 대화가 여기에 표시됩니다"
        }
    }
}

// MARK: - 통계 뷰
struct ConversationStatisticsView: View {
    let person: Person
    @Environment(\.dismiss) private var dismiss
    
    private var statistics: [String: Int] {
        person.getConversationStatistics()
    }
    
    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("대화 통계")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("\(person.name)님과의 대화 기록 요약")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(Array(statistics.keys).sorted(), id: \.self) { key in
                        VStack(spacing: 8) {
                            Text("\(statistics[key] ?? 0)")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text(key)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("통계")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preview
#Preview {
    let person = Person(name: "김철수")
    return ConversationListView(person: person)
        .modelContainer(for: [Person.self, ConversationRecord.self])
}