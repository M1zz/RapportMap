//
//  MacPersonRecordsTab.swift
//  mac
//
//  macOS용 Person 기록 탭
//

import SwiftUI
import SwiftData

// MARK: - Records Tab

struct MacPersonRecordsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @State private var showingMemoArchive = false

    // 상호작용 입력 상태
    @State private var interactionNotes = ""
    @State private var selectedInteractionType: InteractionType = .call
    @State private var interactionDate = Date()
    @State private var interactionDuration: Int? = nil
    @State private var interactionLocation = ""

    // 최근 상호작용들 (최대 10개)
    private var recentInteractions: [InteractionRecord] {
        person.getAllInteractionRecordsSorted().prefix(10).map { $0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 빠른 메모 섹션
                quickMemoSection

                // 대화 기록 섹션 (고민/질문/약속)
                MacConversationRecordsView(person: person)

                // 상호작용 기록 (통합 입력)
                interactionRecordingSection

                // 최근 상호작용 기록
                recentInteractionsSection
            }
            .padding()
        }
        .popover(isPresented: $showingMemoArchive, arrowEdge: .trailing) {
            MacQuickMemoArchiveView(person: person, context: context)
                .frame(width: 600, height: 500)
        }
    }

    // MARK: - 빠른 메모 섹션

    @ViewBuilder
    private var quickMemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("빠른 메모")
                        .font(.headline)
                    Text("대화 내용을 자유롭게 메모하세요. 저장하면 아카이브에 보관됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 아카이브 보기 버튼
                if !person.archivedMemos.isEmpty {
                    Button {
                        showingMemoArchive = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .font(.caption)
                            Text("\(person.archivedMemos.count)개 저장됨")
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextEditor(text: $person.quickMemo)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if person.quickMemo.isEmpty {
                        Text("예: 오늘 만나서 프로젝트 이야기를 나눴어요...")
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            // 저장 버튼
            Button {
                saveQuickMemo()
            } label: {
                HStack {
                    Image(systemName: "archivebox.fill")
                    Text("저장하고 초기화")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .disabled(person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    // MARK: - 상호작용 기록 섹션 (통합 입력)

    @ViewBuilder
    private var interactionRecordingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("상호작용 기록")
                .font(.headline)

            VStack(spacing: 12) {
                // 타입 선택 (가로 스크롤)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(InteractionType.allCases, id: \.self) { type in
                            Button {
                                selectedInteractionType = type
                            } label: {
                                VStack(spacing: 4) {
                                    Text(type.emoji)
                                        .font(.title2)
                                    Text(type.title)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedInteractionType == type ? type.color.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedInteractionType == type ? type.color : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundStyle(selectedInteractionType == type ? type.color : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                // 내용 입력
                TextEditor(text: $interactionNotes)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if interactionNotes.isEmpty {
                            Text("\(selectedInteractionType.title) 내용을 기록하세요...")
                                .font(.body)
                                .foregroundStyle(.secondary.opacity(0.5))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }

                // 옵션들
                HStack(spacing: 16) {
                    // 날짜
                    DatePicker("", selection: $interactionDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .frame(width: 200)

                    // 시간 (분)
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        TextField("시간(분)", value: $interactionDuration, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 60)
                        Text("분")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    // 장소
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .foregroundStyle(.secondary)
                        TextField("장소", text: $interactionLocation)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 120)
                    }

                    Spacer()

                    // 저장 버튼
                    Button {
                        saveInteraction()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("기록")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedInteractionType.color)
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(selectedInteractionType.color.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedInteractionType.color.opacity(0.2), lineWidth: 1)
            )
        }
    }

    private func saveInteraction() {
        let _ = person.addInteractionRecord(
            type: selectedInteractionType,
            date: interactionDate,
            notes: interactionNotes.isEmpty ? nil : interactionNotes,
            duration: interactionDuration.map { TimeInterval($0) },
            location: interactionLocation.isEmpty ? nil : interactionLocation,
            relatedMeetingRecord: nil
        )

        do {
            try context.save()
            // 초기화
            interactionNotes = ""
            interactionDate = Date()
            interactionDuration = nil
            interactionLocation = ""
            print("✅ 상호작용 기록 저장 완료")
        } catch {
            print("❌ 상호작용 기록 저장 실패: \(error)")
        }
    }

    // MARK: - 최근 상호작용 섹션

    @ViewBuilder
    private var recentInteractionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 기록")
                .font(.headline)

            if recentInteractions.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    Text("아직 상호작용 기록이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(12)
            } else {
                ForEach(recentInteractions) { record in
                    MacInteractionRecordRow(record: record)
                }
            }
        }
    }

    // MARK: - Actions

    private func saveQuickMemo() {
        let trimmedMemo = person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMemo.isEmpty else { return }

        // 1. 아카이브에 저장
        let archive = QuickMemoArchive(content: trimmedMemo, createdDate: Date())
        archive.person = person
        context.insert(archive)
        person.archivedMemos.append(archive)

        // 2. InteractionRecord 생성 (메모도 접촉 기록으로 간주)
        let _ = person.addInteractionRecord(
            type: .quickNote,  // 빠른 메모로 기록
            date: Date(),
            notes: "빠른 메모: \(trimmedMemo.prefix(100))",  // 처음 100자만 저장
            duration: nil,
            location: nil,
            relatedMeetingRecord: nil
        )

        do {
            try context.save()
            person.quickMemo = ""
            print("✅ 빠른 메모 저장 완료 - InteractionRecord 생성됨")
        } catch {
            print("❌ 빠른 메모 저장 실패: \(error)")
        }
    }
}

// MARK: - Mac Interaction Record Row

struct MacInteractionRecordRow: View {
    let record: InteractionRecord

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 이모지
            Text(record.type.emoji)
                .font(.title)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.type.title)
                        .font(.headline)
                        .foregroundStyle(record.type.color)

                    Spacer()

                    Text(formatRelativeDate(record.date))
                        .font(.caption)
                        .foregroundStyle(record.isRecent ? .green : .secondary)
                }

                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                // 첨부파일 표시
                if record.hasAttachments {
                    HStack(spacing: 8) {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(record.attachmentCount)개 첨부됨")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        // 첨부파일 타입별 아이콘
                        if !record.imageAttachments.isEmpty {
                            Image(systemName: "photo")
                                .font(.caption2)
                                .foregroundStyle(.blue)
                        }
                        if !record.audioAttachments.isEmpty {
                            Image(systemName: "waveform")
                                .font(.caption2)
                                .foregroundStyle(.purple)
                        }
                        if !record.documentAttachments.isEmpty {
                            Image(systemName: "doc")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(record.isRecent ? record.type.color.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(record.isRecent ? record.type.color.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Mac Quick Memo Archive View

struct MacQuickMemoArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let context: ModelContext

    // 최신순으로 정렬된 아카이브 메모들
    private var sortedMemos: [QuickMemoArchive] {
        person.archivedMemos.sorted { $0.createdDate > $1.createdDate }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("메모 아카이브")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("닫기") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 메모 목록
            if sortedMemos.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "archivebox")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)

                    Text("저장된 메모가 없어요")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("빠른 메모를 작성하고 저장하면 여기에 보관됩니다.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(sortedMemos) { memo in
                            MacMemoArchiveRow(memo: memo, onCopy: {
                                copyToClipboard(memo.content)
                            }, onDelete: {
                                deleteMemo(memo)
                            })
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        print("📋 메모 복사됨: \(text.prefix(50))...")
    }

    private func deleteMemo(_ memo: QuickMemoArchive) {
        context.delete(memo)
        do {
            try context.save()
            print("✅ 메모 삭제 완료")
        } catch {
            print("❌ 메모 삭제 실패: \(error)")
        }
    }
}

// MARK: - Mac Memo Archive Row

struct MacMemoArchiveRow: View {
    let memo: QuickMemoArchive
    let onCopy: () -> Void
    let onDelete: () -> Void
    @State private var showingCopied = false

    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더: 날짜 및 버튼
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(memo.createdDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatRelativeDate(memo.createdDate))
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }

                Spacer()

                // 복사 버튼
                Button {
                    onCopy()
                    withAnimation {
                        showingCopied = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation {
                            showingCopied = false
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        if showingCopied {
                            Text("복사됨")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(showingCopied ? .green : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showingCopied ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                // 삭제 버튼
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // 메모 내용
            Text(memo.content)
                .font(.body)
                .foregroundStyle(.primary)
                .textSelection(.enabled)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}
