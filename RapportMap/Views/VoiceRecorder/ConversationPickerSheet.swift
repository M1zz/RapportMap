//
//  ConversationPickerSheet.swift
//  RapportMap
//
//  Created by hyunho lee on 11/9/25.
//

import SwiftUI
import SwiftData

struct ConversationPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let person: Person
    @Binding var selectedRecords: Set<ConversationRecord>
    let onTitleSuggestion: (String) -> Void
    
    @State private var searchText = ""
    @State private var selectedTypeFilter: ConversationType?
    @State private var showResolvedRecords = false
    
    // 대화 기록들을 필터링하고 정렬
    private var filteredRecords: [ConversationRecord] {
        var records = person.conversationRecords ?? []
        
        // 해결된 기록 필터링
        if !showResolvedRecords {
            records = records.filter { !$0.isResolved }
        }
        
        // 타입 필터링
        if let typeFilter = selectedTypeFilter {
            records = records.filter { $0.type == typeFilter }
        }
        
        // 검색 필터링
        if !searchText.isEmpty {
            records = records.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // 중요한 것들(고민, 질문, 약속)을 우선적으로 표시하고, 최신순으로 정렬
        return records.sorted { first, second in
            let firstIsCritical = [ConversationType.concern, .question, .promise].contains(first.type)
            let secondIsCritical = [ConversationType.concern, .question, .promise].contains(second.type)
            
            if firstIsCritical && !secondIsCritical {
                return true
            } else if !firstIsCritical && secondIsCritical {
                return false
            } else {
                // 같은 중요도면 최신순
                return first.createdDate > second.createdDate
            }
        }
    }
    
    // 중요한 타입들 (놓치면 안 되는 것들)
    private var criticalTypes: [ConversationType] {
        [.concern, .question, .promise]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 검색 및 필터 섹션
                VStack(spacing: 12) {
                    // 검색 바
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("대화 내용 검색...", text: $searchText)
                            .textFieldStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    // 타입 필터 버튼들
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 전체 버튼
                            FilterButton(
                                title: "전체",
                                isSelected: selectedTypeFilter == nil
                            ) {
                                selectedTypeFilter = nil
                            }
                            
                            // 중요한 타입들만 표시
                            ForEach(criticalTypes, id: \.self) { type in
                                FilterButton(
                                    title: "\(type.emoji) \(type.title)",
                                    isSelected: selectedTypeFilter == type
                                ) {
                                    selectedTypeFilter = selectedTypeFilter == type ? nil : type
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 해결된 기록 포함 토글
                    HStack {
                        Toggle("해결된 기록도 포함", isOn: $showResolvedRecords)
                            .font(.caption)
                        Spacer()
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // 대화 기록 리스트
                if filteredRecords.isEmpty {
                    ContentUnavailableView {
                        VStack(spacing: 16) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            
                            Text("대화 기록이 없어요")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("먼저 대화 기록을 추가하고 여기서 중요한 것들을 선택해보세요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                } else {
                    List(filteredRecords, id: \.id) { record in
                        ConversationRecordPickerRow(
                            record: record,
                            isSelected: selectedRecords.contains(record)
                        ) {
                            if selectedRecords.contains(record) {
                                selectedRecords.remove(record)
                            } else {
                                selectedRecords.insert(record)
                                // 첫 번째 선택 시 제목 제안
                                if selectedRecords.count == 1 {
                                    suggestTitle(for: record)
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("대화 기록 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                    .disabled(selectedRecords.isEmpty)
                }
            }
        }
    }
    
    private func suggestTitle(for record: ConversationRecord) {
        let suggestedTitle: String
        switch record.type {
        case .concern:
            suggestedTitle = "고민 상담해주기"
        case .question:
            suggestedTitle = "질문 답변하기"
        case .promise:
            suggestedTitle = "약속 지키기"
        case .feedback:
            suggestedTitle = "피드백 반영하기"
        case .update:
            suggestedTitle = "근황 확인하기"
        case .achievement:
            suggestedTitle = "성취 축하하기"
        }
        onTitleSuggestion(suggestedTitle)
    }
}

// MARK: - FilterButton
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.blue : Color(.systemGray6))
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ConversationRecordPickerRow
struct ConversationRecordPickerRow: View {
    let record: ConversationRecord
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 선택 체크박스
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
                
                // 타입 아이콘
                VStack {
                    Text(record.type.emoji)
                        .font(.title2)
                    Spacer()
                }
                
                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(record.type.title)
                            .font(.caption)
                            .foregroundStyle(record.type.color)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(record.type.color.opacity(0.15))
                            )
                        
                        Spacer()
                        
                        if !record.isResolved {
                            Text("미해결")
                                .font(.caption2)
                                .foregroundStyle(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.red.opacity(0.15))
                                )
                        }
                        
                        Text(record.relativeDate)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    Text(record.content)
                        .font(.body)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    if let notes = record.notes, !notes.isEmpty {
                        Text("메모: \(notes)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, ConversationRecord.self, configurations: config)
    
    let person = Person(name: "테스트 사용자")
    let record1 = ConversationRecord(type: .concern, content: "요즘 회사 일이 너무 힘들어서 스트레스가 많아요")
    let record2 = ConversationRecord(type: .question, content: "이번 주말에 뭐 하면 좋을까요?")
    let record3 = ConversationRecord(type: .promise, content: "다음에 맛있는 카페 소개해주기로 했어요")
    
    person.conversationRecords = [record1, record2, record3]
    container.mainContext.insert(person)
    
    return ConversationPickerSheet(
        person: person,
        selectedRecords: .constant(Set()),
        onTitleSuggestion: { _ in }
    )
    .modelContainer(container)
}