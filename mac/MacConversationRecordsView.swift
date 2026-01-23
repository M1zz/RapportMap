//
//  MacConversationRecordsView.swift
//  mac
//
//  Mac용 대화 기록 뷰 (고민/질문/약속)
//

import SwiftUI
import SwiftData

// MARK: - Mac Conversation Records View
struct MacConversationRecordsView: View {
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
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                Text("대화 기록")
                    .font(.headline)

                Spacer()

                Button {
                    showingHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("전체 기록 보기")
                    }
                }
            }

            // 대화 유형 버튼들
            HStack(spacing: 12) {
                MacConversationTypeButton(
                    title: ConversationType.concern.title,
                    icon: ConversationType.concern.systemImage,
                    color: NSColor(ConversationType.concern.color),
                    count: unsolvedConcernsCount,
                    action: { showingAddConcern = true }
                )

                MacConversationTypeButton(
                    title: ConversationType.question.title,
                    icon: ConversationType.question.systemImage,
                    color: NSColor(ConversationType.question.color),
                    count: unsolvedQuestionsCount,
                    action: { showingAddQuestion = true }
                )

                MacConversationTypeButton(
                    title: ConversationType.promise.title,
                    icon: ConversationType.promise.systemImage,
                    color: NSColor(ConversationType.promise.color),
                    count: unsolvedPromisesCount,
                    action: { showingAddPromise = true }
                )
            }

            // 미해결 항목들
            if unsolvedConcernsCount > 0 || unsolvedQuestionsCount > 0 || unsolvedPromisesCount > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    Text("미해결 항목")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    let allUnsolved = getAllUnsolvedRecords()
                    ForEach(allUnsolved.prefix(5), id: \.id) { record in
                        MacConversationRecordRow(record: record, context: context)
                    }

                    if allUnsolved.count > 5 {
                        Text("외 \(allUnsolved.count - 5)개 더...")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 8)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .sheet(isPresented: $showingHistory) {
            MacConversationHistoryView(person: person)
                .frame(minWidth: 700, minHeight: 500)
        }
        .sheet(isPresented: $showingAddConcern) {
            MacAddConversationSheet(person: person, type: .concern, context: context)
                .frame(width: 500, height: 400)
        }
        .sheet(isPresented: $showingAddQuestion) {
            MacAddConversationSheet(person: person, type: .question, context: context)
                .frame(width: 500, height: 400)
        }
        .sheet(isPresented: $showingAddPromise) {
            MacAddConversationSheet(person: person, type: .promise, context: context)
                .frame(width: 500, height: 400)
        }
    }

    private func getAllUnsolvedRecords() -> [ConversationRecord] {
        return person.conversationRecords.filter { !$0.isResolved }.sorted { $0.date > $1.date }
    }
}

// MARK: - Conversation Type Button
struct MacConversationTypeButton: View {
    let title: String
    let icon: String
    let color: NSColor
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(Color(color))

                    if count > 0 {
                        ZStack {
                            Circle()
                                .fill(.red)
                                .frame(width: 20, height: 20)
                            Text("\(count)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        }
                        .offset(x: 10, y: -10)
                    }
                }

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(color).opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(Color(color).opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conversation Record Row
struct MacConversationRecordRow: View {
    let record: ConversationRecord
    let context: ModelContext
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(spacing: 12) {
                // 타입 아이콘
                Image(systemName: record.type.systemImage)
                    .font(.body)
                    .foregroundStyle(Color(record.type.color))
                    .frame(width: 24)

                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.content)
                        .font(.body)
                        .lineLimit(2)
                        .foregroundStyle(.primary)

                    HStack(spacing: 8) {
                        Text(record.type.title)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text("·")
                            .foregroundStyle(.secondary)

                        Text(record.date, style: .date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                // 우선순위 표시
                if record.priority != .normal {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(record.priority == .urgent ? .red : .orange)
                }
            }
            .padding(8)
            .background(Color.white.opacity(0.5))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            MacConversationDetailView(record: record, context: context)
                .frame(width: 500, height: 400)
        }
    }
}

// MARK: - Add Conversation Sheet
struct MacAddConversationSheet: View {
    let person: Person
    let type: ConversationType
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""
    @State private var priority: ConversationPriority = .normal
    @State private var isImportant = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("\(type.title) 기록하기")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 내용
            Form {
                Section("내용") {
                    TextEditor(text: $content)
                        .frame(minHeight: 150)
                }

                Section("옵션") {
                    Picker("우선순위", selection: $priority) {
                        ForEach(ConversationPriority.allCases, id: \.self) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }

                    Toggle("중요 표시", isOn: $isImportant)
                }
            }
            .formStyle(.grouped)

            // 푸터
            HStack {
                Spacer()
                Button("저장") {
                    addConversation()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(content.isEmpty)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func addConversation() {
        let record = person.addConversationRecord(
            type: type,
            content: content,
            priority: priority,
            isImportant: isImportant
        )
        context.insert(record)
        try? context.save()
    }
}

// MARK: - Conversation History View
struct MacConversationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person
    @State private var filterType: ConversationType?
    @State private var showResolvedOnly = false

    private var filteredRecords: [ConversationRecord] {
        var records = person.conversationRecords

        if let type = filterType {
            records = records.filter { $0.type == type }
        }

        if showResolvedOnly {
            records = records.filter { $0.isResolved }
        }

        return records.sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("전체 대화 기록")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("완료") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 필터
            HStack {
                Picker("유형", selection: $filterType) {
                    Text("전체").tag(nil as ConversationType?)
                    ForEach(ConversationType.allCases, id: \.self) { type in
                        Text(type.title).tag(type as ConversationType?)
                    }
                }
                .frame(width: 150)

                Toggle("해결됨만 보기", isOn: $showResolvedOnly)

                Spacer()

                Text("\(filteredRecords.count)개")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()

            Divider()

            // 기록 목록
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filteredRecords, id: \.id) { record in
                        MacConversationRecordRow(record: record, context: person.modelContext!)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Conversation Detail View
struct MacConversationDetailView: View {
    @Bindable var record: ConversationRecord
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: record.type.systemImage)
                        .foregroundStyle(Color(record.type.color))
                    Text(record.type.title)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                Spacer()
                Button("완료") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 내용
            Form {
                Section("내용") {
                    Text(record.content)
                        .textSelection(.enabled)
                }

                Section("상세") {
                    LabeledContent("날짜", value: record.date, format: .dateTime)
                    LabeledContent("우선순위", value: record.priority.title)
                    LabeledContent("중요", value: record.isImportant ? "예" : "아니오")
                    LabeledContent("해결", value: record.isResolved ? "예" : "아니오")
                }

                if let notes = record.notes, !notes.isEmpty {
                    Section("메모") {
                        Text(notes)
                            .textSelection(.enabled)
                    }
                }
            }
            .formStyle(.grouped)

            // 푸터
            HStack {
                if !record.isResolved {
                    Button("해결됨으로 표시") {
                        record.isResolved = true
                        record.resolvedDate = Date()
                        try? context.save()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("미해결로 표시") {
                        record.isResolved = false
                        record.resolvedDate = nil
                        try? context.save()
                        dismiss()
                    }
                }

                Spacer()

                Button("삭제", role: .destructive) {
                    context.delete(record)
                    try? context.save()
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }
}
