//
//  MacConversationRecordsView.swift
//  mac
//
//  Mac용 대화 기록 뷰 (고민/질문/약속) - 통합 입력 방식
//

import SwiftUI
import SwiftData

// MARK: - Mac Conversation Records View
struct MacConversationRecordsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var showingHistory = false
    @State private var newContent = ""
    @State private var selectedType: ConversationType = .concern
    @State private var selectedPriority: ConversationPriority = .normal
    @State private var isImportant = false

    private var unsolvedCount: Int {
        person.conversationRecords.filter { !$0.isResolved }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 헤더
            HStack {
                Text("대화 기록")
                    .font(.headline)

                Spacer()

                if unsolvedCount > 0 {
                    Text("미해결 \(unsolvedCount)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showingHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("전체 기록")
                    }
                }
            }

            // 통합 입력 필드
            VStack(spacing: 12) {
                // 타입 선택 (세그먼트 스타일)
                HStack(spacing: 8) {
                    ForEach(ConversationType.allCases, id: \.self) { type in
                        Button {
                            selectedType = type
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                Text(type.title)
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedType == type ? Color(type.color).opacity(0.2) : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedType == type ? Color(type.color) : Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .foregroundStyle(selectedType == type ? Color(type.color) : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // 내용 입력
                TextEditor(text: $newContent)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if newContent.isEmpty {
                            Text(placeholderText)
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                // 옵션 및 저장 버튼
                HStack {
                    // 우선순위
                    Picker("", selection: $selectedPriority) {
                        ForEach(ConversationPriority.allCases, id: \.self) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 100)

                    // 중요 표시
                    Toggle(isOn: $isImportant) {
                        Image(systemName: isImportant ? "star.fill" : "star")
                            .foregroundStyle(isImportant ? .yellow : .gray)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.plain)

                    Spacer()

                    // 저장 버튼
                    Button {
                        addConversation()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("추가")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(newContent.isEmpty ? Color.gray : Color(selectedType.color))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(newContent.isEmpty)
                }
            }
            .padding()
            .background(Color(selectedType.color).opacity(0.05))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(selectedType.color).opacity(0.2), lineWidth: 1)
            )

            // 미해결 항목들
            if unsolvedCount > 0 {
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
    }

    private var placeholderText: String {
        switch selectedType {
        case .concern: return "이 사람이 가진 고민을 기록하세요..."
        case .question: return "이 사람에게 물어볼 질문을 기록하세요..."
        case .promise: return "이 사람과의 약속을 기록하세요..."
        }
    }

    private func getAllUnsolvedRecords() -> [ConversationRecord] {
        return person.conversationRecords.filter { !$0.isResolved }.sorted { $0.date > $1.date }
    }

    private func addConversation() {
        let trimmed = newContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let record = person.addConversationRecord(
            type: selectedType,
            content: trimmed,
            priority: selectedPriority,
            isImportant: isImportant
        )
        context.insert(record)

        do {
            try context.save()
            // 초기화
            newContent = ""
            selectedPriority = .normal
            isImportant = false
        } catch {
            print("❌ 대화 기록 저장 실패: \(error)")
        }
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
