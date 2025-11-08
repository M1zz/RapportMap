//
//  ConversationRecordsView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// MARK: - ConversationRecordsView
struct ConversationRecordsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    
    @State private var showingHistory = false
    @State private var showingAddConcern = false
    @State private var showingAddQuestion = false
    @State private var showingAddPromise = false
    
    private var unsolvedConcernsCount: Int {
        person.getConversationRecords(ofType: .concern).filter { !$0.isResolved }.count
    }
    
    private var unsolvedQuestionsCount: Int {
        person.getConversationRecords(ofType: .question).filter { !$0.isResolved }.count
    }
    
    private var unsolvedPromisesCount: Int {
        person.getConversationRecords(ofType: .promise).filter { !$0.isResolved }.count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 대화 기록 헤더
            HStack {
                Text("대화 기록")
                    .font(.body)
                
                Spacer()
                
                Button {
                    showingHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                        Text("전체 기록 보기")
                            .font(.body)
                    }
                    .foregroundStyle(.blue)
                }
            }
            
            // 대화 유형 버튼들
            HStack(spacing: 12) {
                ConversationTypeButton(
                    title: ConversationType.concern.title,
                    icon: ConversationType.concern.systemImage,
                    color: ConversationType.concern.color,
                    count: unsolvedConcernsCount,
                    action: { showingAddConcern = true }
                )
                
                ConversationTypeButton(
                    title: ConversationType.question.title,
                    icon: ConversationType.question.systemImage,
                    color: ConversationType.question.color,
                    count: unsolvedQuestionsCount,
                    action: { showingAddQuestion = true }
                )
                
                ConversationTypeButton(
                    title: ConversationType.promise.title,
                    icon: ConversationType.promise.systemImage,
                    color: ConversationType.promise.color,
                    count: unsolvedPromisesCount,
                    action: { showingAddPromise = true }
                )
            }
            
            // 최근 기록들 미리보기 (미해결 항목들)
            if unsolvedConcernsCount > 0 || unsolvedQuestionsCount > 0 || unsolvedPromisesCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("미해결 항목")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // 최대 3개까지만 표시
                    let allUnsolved = getAllUnsolvedRecords()
                    ForEach(allUnsolved.prefix(3), id: \.id) { record in
                        ConversationRecordPreviewRow(record: record)
                    }
                    
                    if allUnsolved.count > 3 {
                        Text("외 \(allUnsolved.count - 3)개 더...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .sheet(isPresented: $showingHistory) {
            ConversationHistoryView(person: person)
        }
        .sheet(isPresented: $showingAddConcern) {
            AddConversationRecordSheet(person: person, type: .concern)
        }
        .sheet(isPresented: $showingAddQuestion) {
            AddConversationRecordSheet(person: person, type: .question)
        }
        .sheet(isPresented: $showingAddPromise) {
            AddConversationRecordSheet(person: person, type: .promise)
        }
    }
    
    private func getAllUnsolvedRecords() -> [ConversationRecord] {
        let concerns = person.getConversationRecords(ofType: .concern).filter { !$0.isResolved }
        let questions = person.getConversationRecords(ofType: .question).filter { !$0.isResolved }
        let promises = person.getConversationRecords(ofType: .promise).filter { !$0.isResolved }
        
        return (concerns + questions + promises)
            .sorted { $0.createdDate > $1.createdDate }
    }
}

// MARK: - ConversationTypeButton
struct ConversationTypeButton: View {
    let title: String
    let icon: String
    let color: Color
    let count: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    
                    if count > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Text("\(count)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .offset(x: 8, y: -8)
                            }
                            Spacer()
                        }
                        .frame(width: 30, height: 30)
                    }
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ConversationRecordPreviewRow
struct ConversationRecordPreviewRow: View {
    let record: ConversationRecord
    @Environment(\.modelContext) private var context
    
    private var typeColor: Color {
        return record.type.color
    }
    
    private var typeIcon: String {
        return record.type.systemImage
    }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: typeIcon)
                .font(.caption)
                .foregroundStyle(typeColor)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(record.content)
                    .font(.subheadline)
                    .lineLimit(2)
                
                Text(record.relativeDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button {
                record.isResolved = true
                try? context.save()
                
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } label: {
                Image(systemName: "checkmark.circle")
                    .foregroundStyle(typeColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(typeColor.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - ConversationHistoryView
struct ConversationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    
    enum ConversationFilter: String, CaseIterable {
        case all = "전체"
        case concern = "고민"
        case question = "질문"
        case promise = "약속"
        
        var conversationType: ConversationType? {
            switch self {
            case .all: return nil
            case .concern: return .concern
            case .question: return .question
            case .promise: return .promise
            }
        }
        
        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .concern: return "person.badge.minus"
            case .question: return "questionmark.circle"
            case .promise: return "handshake"
            }
        }
        
        var color: Color {
            switch self {
            case .all: return .gray
            case .concern: return .orange
            case .question: return .blue
            case .promise: return .green
            }
        }
        }
    
    
    @State private var selectedFilter: ConversationFilter = .all
    
    private var filteredRecords: [ConversationRecord] {
        let allRecords = getAllConversationRecords()
        
        guard let filterType = selectedFilter.conversationType else {
            return allRecords
        }
        
        return allRecords.filter { $0.type == filterType }
    }
    
    private func getAllConversationRecords() -> [ConversationRecord] {
        let concerns = person.getConversationRecords(ofType: .concern)
        let questions = person.getConversationRecords(ofType: .question)
        let promises = person.getConversationRecords(ofType: .promise)
        
        return (concerns + questions + promises)
            .sorted { $0.createdDate > $1.createdDate }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 필터 선택
                VStack(spacing: 12) {
                    Picker("필터", selection: $selectedFilter) {
                        ForEach(ConversationFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue)
                                .tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 통계 정보
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(filteredRecords.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(selectedFilter.color)
                            Text("총 기록")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        VStack(spacing: 4) {
                            let unsolvedCount = filteredRecords.filter { !$0.isResolved }.count
                            Text("\(unsolvedCount)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.red)
                            Text("미해결")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
                
                // 기록 목록
                if filteredRecords.isEmpty {
                    // 빈 상태
                    VStack(spacing: 20) {
                        Image(systemName: selectedFilter.systemImage)
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("\(selectedFilter.rawValue) 기록이 없어요")
                            .font(.headline)
                        
                        Text("새로운 \(selectedFilter.rawValue.lowercased()) 기록을 추가해보세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Button("기록 추가하러 가기") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedFilter.color)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        ForEach(filteredRecords, id: \.id) { record in
                            ConversationRecordDetailRow(record: record)
                        }
                    }
                }
            }
            .navigationTitle("대화 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") { dismiss() }
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
    }
}

// MARK: - ConversationRecordDetailRow
struct ConversationRecordDetailRow: View {
    let record: ConversationRecord
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    
    private var typeColor: Color {
        return record.type.color
    }
    
    private var typeIcon: String {
        return record.type.systemImage
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 상태 표시줄
            VStack {
                Circle()
                    .fill(record.isResolved ? Color.green : typeColor)
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill((record.isResolved ? Color.green : typeColor).opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: typeIcon)
                        .font(.caption)
                        .foregroundStyle(typeColor)
                    
                    Text(record.type.title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(typeColor)
                    
                    if record.isResolved {
                        Text("해결됨")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                            .foregroundStyle(.white)
                    }
                    
                    if record.priority == .high || record.priority == .urgent {
                        Text(record.priority.emoji)
                            .font(.caption2)
                    }
                    
                    Spacer()
                }
                
                Text(record.content)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(record.relativeDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let resolvedDate = record.resolvedDate {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("해결일: \(resolvedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showingEditSheet = true
            }
            
            VStack {
                if !record.isResolved {
                    Button {
                        record.isResolved = true
                        record.resolvedDate = Date()
                        try? context.save()
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        record.isResolved = false
                        record.resolvedDate = nil
                        try? context.save()
                        
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                            .font(.title3)
                            .foregroundStyle(typeColor)
                    }
                    .buttonStyle(.plain)
                }
                
                Button(role: .destructive) {
                    withAnimation {
                        context.delete(record)
                        try? context.save()
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingEditSheet) {
            EditConversationRecordSheet(record: record)
        }
    }
}

// MARK: - AddConversationRecordSheet
struct AddConversationRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var person: Person
    let type: ConversationType
    
    @State private var content = ""
    @State private var priority: ConversationPriority = .normal
    
    private var typeColor: Color {
        return type.color
    }
    
    private var placeholder: String {
        switch type {
        case .concern: return "이 사람이 최근에 고민하고 있는 것은?"
        case .question: return "이 사람에게 받은 질문이나 요청사항은?"
        case .promise: return "아직 지키지 못한 약속이나 해야 할 일은?"
        case .update: return "이 사람의 최근 근황은?"
        case .feedback: return "이 사람에게 받은 피드백은?"
        case .request: return "이 사람의 요청사항은?"
        case .achievement: return "이 사람의 성취나 좋은 소식은?"
        case .problem: return "이 사람이 겪고 있는 문제는?"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("새 \(type.title) 추가") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: typeIcon)
                                .font(.title2)
                                .foregroundStyle(typeColor)
                            
                            VStack(alignment: .leading) {
                                Text("\(type.title) 기록")
                                    .font(.headline)
                                Text("\(person.name)님과 관련된 \(type.title)을 기록해주세요")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.bottom, 8)
                        
                        TextField(placeholder, text: $content, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                            .lineLimit(3...8)
                    }
                }
                
                Section("우선순위") {
                    Picker("우선순위", selection: $priority) {
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
                
                if !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section("미리보기") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: typeIcon)
                                    .foregroundStyle(typeColor)
                                Text(type.title)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(typeColor)
                                
                                if priority != .normal {
                                    Text(priority.emoji)
                                }
                            }
                            
                            Text(content)
                                .font(.body)
                                .padding()
                                .background(typeColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                }
            }
            .navigationTitle("\(type.title) 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        addRecord()
                        dismiss()
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private var typeIcon: String {
        return type.systemImage
    }
    
    private func addRecord() {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        let record = person.addConversationRecord(
            type: type,
            content: trimmedContent,
            priority: priority,
            date: Date()
        )
        context.insert(record)
        
        do {
            try context.save()
            print("✅ \(type.title) 기록 추가 완료")
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ \(type.title) 기록 추가 실패: \(error)")
        }
    }
}



