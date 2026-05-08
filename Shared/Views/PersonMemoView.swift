//
//  PersonMemoView.swift
//  RapportMap
//
//  이 사람에 대해 알게 된 것들 - 자유 형식 메모
//

import SwiftUI
import SwiftData

struct PersonMemoView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var newNoteText = ""
    @State private var isFocused = false

    private var sortedNotes: [PersonNote] {
        (person.notes ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 빠른 입력창
            quickInput

            Divider()

            // 메모 목록
            if (person.notes ?? []).isEmpty {
                emptyState
            } else {
                notesList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - 빠른 입력창

    private var quickInput: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("오늘 알게 된 것... (예: 포항 사람이래)", text: $newNoteText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color.secondaryBackground)
                .cornerRadius(10)

            Button {
                addNote()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? Color.secondary.opacity(0.4)
                                     : Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(newNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    // MARK: - 메모 목록

    private var notesList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                ForEach(groupedNotes, id: \.0) { dateKey, notes in
                    Section {
                        ForEach(notes) { note in
                            NoteRow(note: note) {
                                deleteNote(note)
                            }
                        }
                    } header: {
                        Text(dateKey)
                            .font(.body)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - 빈 상태

    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 메모가 없어요", systemImage: "note.text")
        } description: {
            Text("위 입력창에 알게 된 것들을 자유롭게 적어보세요")
        }
    }

    // MARK: - 날짜별 그룹

    private var groupedNotes: [(String, [PersonNote])] {
        let grouped = Dictionary(grouping: sortedNotes) { note in
            formatDateKey(note.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }

    private func formatDateKey(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "오늘" }
        if calendar.isDateInYesterday(date) { return "어제" }
        return date.formatted(.dateTime.year().month().day())
    }

    // MARK: - 액션

    private func addNote() {
        let text = newNoteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let note = PersonNote(content: text)
        note.person = person
        person.notes = (person.notes ?? []) + [note]
        try? context.save()
        newNoteText = ""
    }

    private func deleteNote(_ note: PersonNote) {
        person.notes = person.notes?.filter { $0.id != note.id }
        context.delete(note)
        try? context.save()
    }
}

// MARK: - 메모 행

private struct NoteRow: View {
    let note: PersonNote
    let onDelete: () -> Void

    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // 타임라인 도트
            Circle()
                .fill(Color.accentColor.opacity(0.5))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                if isEditing {
                    TextField("메모", text: $editText, axis: .vertical)
                        .textFieldStyle(.plain)
                        .lineLimit(1...6)
                        .onSubmit { commitEdit() }
                } else {
                    Text(note.content)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture {
                            editText = note.content
                            isEditing = true
                        }
                }

                Text(note.date.formatted(.dateTime.hour().minute()))
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isEditing {
                Button("완료") { commitEdit() }
                    .font(.body)
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
            } else {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.body)
                        .foregroundStyle(Color.secondary.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.secondaryBackground)
        .cornerRadius(10)
    }

    private func commitEdit() {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            note.content = trimmed
        }
        isEditing = false
    }
}
