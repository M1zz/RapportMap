//
//  EditConversationRecordSheet.swift
//  RapportMap
//
//  Created by Assistant on 11/8/25.
//

import SwiftUI
import SwiftData

struct EditConversationRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var record: ConversationRecord
    
    // 편집용 상태 변수들
    @State private var editedContent: String
    @State private var editedNotes: String
    @State private var editedPriority: ConversationPriority
    @State private var editedType: ConversationType
    @State private var editedTagsText: String
    @State private var isResolved: Bool
    
    // 삭제 확인 알림
    @State private var showingDeleteAlert = false
    
    init(record: ConversationRecord) {
        self.record = record
        
        // 현재 값들로 초기화
        _editedContent = State(initialValue: record.content)
        _editedNotes = State(initialValue: record.notes ?? "")
        _editedPriority = State(initialValue: record.priority)
        _editedType = State(initialValue: record.type)
        _editedTagsText = State(initialValue: record.tags.joined(separator: ", "))
        _isResolved = State(initialValue: record.isResolved)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 기본 정보 섹션
                Section("기본 정보") {
                    // 대화 타입 선택
                    Picker("타입", selection: $editedType) {
                        ForEach(ConversationType.allCases, id: \.self) { type in
                            Label(type.title, systemImage: type.systemImage)
                                .tag(type)
                        }
                    }
                    
                    // 우선순위 선택
                    Picker("우선순위", selection: $editedPriority) {
                        ForEach(ConversationPriority.allCases, id: \.self) { priority in
                            HStack {
                                Text(priority.emoji)
                                Text(priority.title)
                            }
                            .tag(priority)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // 내용 섹션
                Section("내용") {
                    TextField("대화 내용", text: $editedContent, axis: .vertical)
                        .lineLimit(3...8)
                    
                    TextField("메모 (선택사항)", text: $editedNotes, axis: .vertical)
                        .lineLimit(2...5)
                }
                
                // 태그 섹션
                Section("태그") {
                    TextField("태그 (쉼표로 구분)", text: $editedTagsText)
                        .onSubmit {
                            // 태그 정리
                            editedTagsText = parseAndCleanTags(editedTagsText)
                        }
                    
                    if !editedTagsText.isEmpty {
                        let tags = editedTagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(tags, id: \.self) { tag in
                                    Text(tag)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(editedType.color.opacity(0.2))
                                        .foregroundStyle(editedType.color)
                                        .cornerRadius(12)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                // 상태 섹션
                Section("상태") {
                    Toggle("해결됨", isOn: $isResolved)
                    
                    if isResolved {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("이 대화는 해결된 것으로 표시됩니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.orange)
                            Text("이 대화는 아직 해결되지 않은 것으로 표시됩니다")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 위험 구역
                Section("위험 구역") {
                    Button("대화 기록 삭제", role: .destructive) {
                        showingDeleteAlert = true
                    }
                }
            }
            .navigationTitle("대화 기록 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveChanges()
                        dismiss()
                    }
                    .disabled(editedContent.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("대화 기록 삭제", isPresented: $showingDeleteAlert) {
                Button("삭제", role: .destructive) {
                    deleteRecord()
                    dismiss()
                }
                Button("취소", role: .cancel) { }
            } message: {
                Text("이 대화 기록을 삭제하시겠습니까? 삭제된 기록은 복구할 수 없습니다.")
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func saveChanges() {
        // 태그 문자열을 배열로 변환
        let tags = editedTagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // 변경사항 적용
        record.content = editedContent.trimmingCharacters(in: .whitespaces)
        record.notes = editedNotes.trimmingCharacters(in: .whitespaces).isEmpty ? nil : editedNotes.trimmingCharacters(in: .whitespaces)
        record.priority = editedPriority
        record.type = editedType
        record.tags = tags
        
        // 해결 상태 업데이트
        if isResolved && !record.isResolved {
            record.isResolved = true
            record.resolvedDate = Date()
        } else if !isResolved && record.isResolved {
            record.isResolved = false
            record.resolvedDate = nil
        }
        
        // 저장
        try? context.save()
        
        print("✅ [EditConversationRecord] 대화 기록 수정 완료: \(record.content)")
    }
    
    private func deleteRecord() {
        guard let person = record.person else {
            print("❌ [EditConversationRecord] 연결된 사람을 찾을 수 없음")
            return
        }
        
        person.deleteConversationRecord(record, modelContext: context)
        try? context.save()
    }
    
    private func parseAndCleanTags(_ input: String) -> String {
        let tags = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .prefix(10) // 최대 10개 태그로 제한
        
        return tags.joined(separator: ", ")
    }
}

#Preview {
    do {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Person.self, configurations: config)
        
        // 샘플 데이터 생성
        let person = Person(name: "테스트")
        let record = ConversationRecord(
            type: .question,
            content: "최근에 읽은 책이 있나요?",
            notes: "독서 취향 파악",
            priority: .normal,
            tags: ["독서", "취미"]
        )
        record.person = person
        container.mainContext.insert(person)
        container.mainContext.insert(record)
        
        return EditConversationRecordSheet(record: record)
            .modelContainer(container)
    } catch {
        return Text("Preview Error: \(error)")
    }
}