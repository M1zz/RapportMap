//
//  AddCriticalActionSheet.swift
//  RapportMap
//
//  Created by hyunho lee on 11/9/25.
//

import SwiftUI
import SwiftData

// 중요한 항목 추가 완료 알림을 위한 Notification 이름 정의
extension Notification.Name {
    static let criticalActionAdded = Notification.Name("criticalActionAdded")
}

struct AddCriticalActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let person: Person
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var reminderDate: Date = Date()
    @State private var isReminderEnabled: Bool = true
    @State private var showingConversationPicker: Bool = false
    @State private var selectedConversationRecords: Set<ConversationRecord> = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section("중요한 항목 정보") {
                    TextField("제목", text: $title)
                        .textInputAutocapitalization(.sentences)
                    
                    TextField("설명 (선택사항)", text: $description, axis: .vertical)
                        .textInputAutocapitalization(.sentences)
                        .lineLimit(3...6)
                }
                
                Section("대화/상태 기록에서 가져오기") {
                    Button {
                        showingConversationPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                            Text("대화 기록 선택")
                            Spacer()
                            if !selectedConversationRecords.isEmpty {
                                Text("\(selectedConversationRecords.count)개 선택됨")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if !selectedConversationRecords.isEmpty {
                        ForEach(Array(selectedConversationRecords), id: \.id) { record in
                            HStack {
                                Text(record.type.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(record.type.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(record.content)
                                        .font(.body)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Button {
                                    selectedConversationRecords.remove(record)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                
                Section("알림 설정") {
                    Toggle("알림 받기", isOn: $isReminderEnabled)
                    
                    if isReminderEnabled {
                        DatePicker(
                            "알림 날짜",
                            selection: $reminderDate,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }
                
                Section {
                    Button("추가하기") {
                        addCriticalAction()
                    }
                    .disabled(title.isEmpty && selectedConversationRecords.isEmpty)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("중요한 것 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingConversationPicker) {
                ConversationPickerSheet(
                    person: person,
                    selectedRecords: $selectedConversationRecords,
                    onTitleSuggestion: { suggestedTitle in
                        if title.isEmpty {
                            title = suggestedTitle
                        }
                    }
                )
            }
        }
    }
    
    private func addCriticalAction() {
        var successCount = 0
        
        // 선택된 대화 기록이 있으면 해당 내용을 기반으로 액션 생성
        if !selectedConversationRecords.isEmpty {
            for record in selectedConversationRecords {
                if addCriticalActionFromRecord(record) {
                    successCount += 1
                }
            }
        }
        
        // 직접 입력한 내용이 있으면 별도 액션 생성
        if !title.isEmpty {
            if addCustomCriticalAction() {
                successCount += 1
            }
        }
        
        // 성공적으로 추가된 액션이 있을 때만 알림 전송
        if successCount > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                // UI 업데이트를 위한 알림 전송
                NotificationCenter.default.post(
                    name: .criticalActionAdded,
                    object: person,
                    userInfo: [
                        "totalActions": successCount,
                        "personId": person.id.uuidString,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                )
                
                print("📡 Critical action notification sent for \(person.name)")
            }
        }
        
        // 시트 닫기
        dismiss()
    }
    
    @discardableResult
    private func addCriticalActionFromRecord(_ record: ConversationRecord) -> Bool {
        let actionTitle: String
        let actionDescription: String
        
        // 대화 타입에 따라 액션 제목과 설명 생성
        switch record.type {
        case .question:
            actionTitle = "질문 답변하기: \(record.content.prefix(20))..."
            actionDescription = "질문: \(record.content)\n\(record.notes ?? "")"
        case .concern:
            actionTitle = "고민 상담해주기: \(record.content.prefix(20))..."
            actionDescription = "고민: \(record.content)\n\(record.notes ?? "")"
        default:
            // 다른 타입들은 일반적인 처리
            actionTitle = "\(record.type.title) 확인: \(record.content.prefix(20))..."
            actionDescription = "\(record.type.title): \(record.content)\n\(record.notes ?? "")"
        }
        
        // 커스텀 RapportAction 생성
        let customAction = RapportAction(
            id: UUID(),
            title: actionTitle,
            actionDescription: actionDescription,
            phase: person.currentPhase,
            type: .critical,
            order: 999 // 커스텀 항목은 마지막에 배치
        )
        
        // PersonAction 생성
        let personAction = PersonAction(
            person: person,
            action: customAction,
            isCompleted: false,
            note: "",
            context: actionDescription,
            reminderDate: isReminderEnabled ? reminderDate : nil,
            isReminderActive: isReminderEnabled,
            isVisibleInDetail: true // 중요한 항목이므로 항상 상세 뷰에 표시
        )
        
        // 관계 설정 (SwiftData에서 중요)
        personAction.person = person
        personAction.action = customAction
        
        // 데이터베이스에 저장
        context.insert(customAction)
        context.insert(personAction)
        person.actions.append(personAction)
        
        do {
            try context.save()
            print("✅ Critical action added from conversation record: \(actionTitle)")
            print("🔍 PersonAction details: id=\(personAction.id), isVisibleInDetail=\(personAction.isVisibleInDetail), actionType=\(customAction.type)")
            return true
        } catch {
            print("❌ Error saving critical action from record: \(error)")
            return false
        }
    }
    
    @discardableResult
    private func addCustomCriticalAction() -> Bool {
        // 커스텀 RapportAction 생성
        let customAction = RapportAction(
            id: UUID(),
            title: title,
            actionDescription: description.isEmpty ? title : description,
            phase: person.currentPhase,
            type: .critical,
            order: 999 // 커스텀 항목은 마지막에 배치
        )
        
        // PersonAction 생성
        let personAction = PersonAction(
            person: person,
            action: customAction,
            isCompleted: false,
            note: "",
            context: description,
            reminderDate: isReminderEnabled ? reminderDate : nil,
            isReminderActive: isReminderEnabled,
            isVisibleInDetail: true // 중요한 항목이므로 항상 상세 뷰에 표시
        )
        
        // 관계 설정 (SwiftData에서 중요)
        personAction.person = person
        personAction.action = customAction
        
        // 데이터베이스에 저장
        context.insert(customAction)
        context.insert(personAction)
        person.actions.append(personAction)
        
        do {
            try context.save()
            print("✅ Custom critical action added successfully: \(title)")
            print("🔍 PersonAction details: id=\(personAction.id), isVisibleInDetail=\(personAction.isVisibleInDetail), actionType=\(customAction.type)")
            return true
        } catch {
            print("❌ Error saving custom critical action: \(error)")
            return false
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, configurations: config)
    
    let person = Person(name: "테스트 사용자", contact: "010-1234-5678")
    
    return AddCriticalActionSheet(person: person)
        .modelContainer(container)
}