//
//  QuickRecordSheet.swift
//  RapportMap
//
//  Created by Leeo on 11/7/25.
//

import SwiftUI
import SwiftData

// MARK: - QuickRecordSheet
struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var person: Person
    
    // 선택된 타입과 내용
    @State private var selectedType: ConversationType = .concern
    @State private var content: String = ""
    @State private var lastContact: Date?
    @State private var hasContactDate: Bool = false
    
    // 타입별 플레이스홀더
    private var placeholder: String {
        switch selectedType {
        case .concern: return "어떤 고민을 상담했나요?"
        case .question: return "어떤 질문을 받았나요?"
        case .promise: return "어떤 약속을 했나요?"
        default: return "내용을 입력하세요"
        }
    }
    
    init(person: Person) {
        self.person = person
        self._lastContact = State(initialValue: person.lastContact)
        self._hasContactDate = State(initialValue: person.lastContact != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(person.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(person.state.emoji)
                            .font(.title)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("대화 타입 선택") {
                    Picker("타입", selection: $selectedType) {
                        ForEach([ConversationType.concern, .question, .promise], id: \.self) { type in
                            Text("\(type.emoji) \(type.title)")
                                .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Section("대화 내용") {
                    TextField(placeholder, text: $content, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("연락 날짜") {
                    Toggle("연락 날짜 기록", isOn: $hasContactDate)
                    
                    if hasContactDate {
                        DatePicker("언제 연락했나요?", 
                                 selection: Binding(
                                    get: { lastContact ?? Date() },
                                    set: { lastContact = $0 }
                                 ),
                                 displayedComponents: [.date, .hourAndMinute])
                    }
                }
            }
            .navigationTitle("빠른 대화 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveRecord()
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveRecord() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedContent.isEmpty else { return }
        
        // 선택된 타입에 따라 우선순위 설정
        let priority: ConversationPriority = selectedType == .promise ? .high : .normal
        
        // 대화 기록 저장 (모두 중요한 기록으로 설정)
        let record = person.addConversationRecord(
            type: selectedType,
            content: trimmedContent,
            priority: priority,
            isImportant: true,
            date: Date()
        )
        context.insert(record)
        
        // 연락 날짜 저장
        if hasContactDate {
            person.lastContact = lastContact
        }
        
        // 관계 상태 업데이트
        person.updateRelationshipState()
        
        // 저장
        try? context.save()
        
        print("✅ \(selectedType.title) 기록 저장됨: isImportant = \(record.isImportant)")
    }
}
