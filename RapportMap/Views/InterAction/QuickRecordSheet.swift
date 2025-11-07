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
    
    @State private var recentConcerns: String = ""
    @State private var receivedQuestions: String = ""
    @State private var unresolvedPromises: String = ""
    @State private var unansweredCount: Int = 0
    @State private var isNeglected: Bool = false
    @State private var lastContact: Date?
    @State private var hasContactDate: Bool = false
    
    init(person: Person) {
        self.person = person
        
        self._recentConcerns = State(initialValue: person.currentConcerns.first ?? "")
        self._receivedQuestions = State(initialValue: person.allReceivedQuestions.first ?? "")
        self._unresolvedPromises = State(initialValue: person.currentUnresolvedPromises.first ?? "")
        self._unansweredCount = State(initialValue: person.currentUnansweredCount)
        self._isNeglected = State(initialValue: person.isNeglected)
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
                
                Section("📞 연락 기록") {
                    Toggle("방금 연락했음", isOn: $hasContactDate)
                    
                    if hasContactDate {
                        DatePicker("연락 시간", selection: Binding(
                            get: { lastContact ?? Date() },
                            set: { lastContact = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        
                        // 빠른 시간 선택
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            Button("지금") {
                                lastContact = Date()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("1시간 전") {
                                lastContact = Date().addingTimeInterval(-3600)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("오늘 오전") {
                                lastContact = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                Section("💬 대화 상태") {
                    Stepper(value: $unansweredCount, in: 0...20) {
                        Text("미해결 대화: \(unansweredCount)개")
                    }
                    
                    Toggle("관계가 소홀해짐", isOn: $isNeglected)
                }
                
                Section(header: Text("🧠 최근의 고민"), footer: Text("예: 이직 고민, 건강 문제, 인간관계 등")
                    .font(.caption)
                    .foregroundStyle(.secondary)) {
                    TextField("이 사람이 최근에 고민하고 있는 것은?", text: $recentConcerns, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                }
                
                Section(header: Text("❓ 받았던 질문"), footer: Text("예: 추천 요청, 조언 구함, 도움 요청 등")
                    .font(.caption)
                    .foregroundStyle(.secondary)) {
                    TextField("이 사람에게 받은 질문이나 요청사항은?", text: $receivedQuestions, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                }
                
                Section(header: Text("🤝 미해결된 약속"), footer: Text("예: 약속한 만남, 전해줄 정보, 도와주기로 한 일 등")
                    .font(.caption)
                    .foregroundStyle(.secondary)) {
                    TextField("아직 지키지 못한 약속이나 해야 할 일은?", text: $unresolvedPromises, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                }
                
                // 미리보기 섹션
                if !recentConcerns.isEmpty || !receivedQuestions.isEmpty || !unresolvedPromises.isEmpty || unansweredCount > 0 || isNeglected {
                    Section("📋 기록 미리보기") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !recentConcerns.isEmpty {
                                PreviewCard(icon: "🧠", title: "고민", content: recentConcerns, color: Color.purple)
                            }
                            
                            if !receivedQuestions.isEmpty {
                                PreviewCard(icon: "❓", title: "질문", content: receivedQuestions, color: Color.blue)
                            }
                            
                            if !unresolvedPromises.isEmpty {
                                PreviewCard(icon: "🤝", title: "약속", content: unresolvedPromises, color: Color.red)
                            }
                            
                            if unansweredCount > 0 {
                                HStack(spacing: 8) {
                                    Text("💬")
                                        .font(.caption)
                                    Text("미해결 대화 \(unansweredCount)개")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.orange)
                                }
                            }
                            
                            if isNeglected {
                                HStack(spacing: 8) {
                                    Text("⚠️")
                                        .font(.caption)
                                    Text("관계가 소홀해짐")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(Color.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("대화 기록")
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
                }
            }
        }
    }
    
    private func saveRecord() {
        // 새로운 대화 기록 시스템을 사용하여 저장
        
        // 고민사항 저장
        let trimmedConcerns = recentConcerns.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedConcerns.isEmpty {
            let _ = person.addConversationRecord(
                type: .concern,
                content: trimmedConcerns,
                priority: .normal,
                date: Date()
            )
            context.insert(person.conversationRecords.last!)
        }
        
        // 받은 질문 저장
        let trimmedQuestions = receivedQuestions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuestions.isEmpty {
            let _ = person.addConversationRecord(
                type: .question,
                content: trimmedQuestions,
                priority: .normal,
                date: Date()
            )
            context.insert(person.conversationRecords.last!)
        }
        
        // 미해결 약속 저장
        let trimmedPromises = unresolvedPromises.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPromises.isEmpty {
            let _ = person.addConversationRecord(
                type: .promise,
                content: trimmedPromises,
                priority: .high,
                date: Date()
            )
            context.insert(person.conversationRecords.last!)
        }
        
        // 소홀함 플래그 저장
        person.isNeglected = isNeglected
        
        // 연락 날짜 저장
        if hasContactDate {
            person.lastContact = lastContact
        }
        
        // 관계 상태 업데이트
        person.updateRelationshipState()
        
        // 데이터베이스 저장
        do {
            try context.save()
            print("✅ \(person.name)님의 대화 기록 저장 완료")
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ 대화 기록 저장 실패: \(error)")
        }
    }
}

// MARK: - PreviewCard (Helper)
struct PreviewCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}
