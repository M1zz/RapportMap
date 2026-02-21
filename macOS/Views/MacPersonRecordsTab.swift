//
//  MacPersonRecordsTab.swift
//  mac
//
//  macOS용 Person 기록 탭 - 통합 Record 모델 사용
//

import SwiftUI
import SwiftData

// MARK: - Records Tab

struct MacPersonRecordsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @State private var showingMemoArchive = false
    
    // 기록 입력 상태
    @State private var recordContent = ""
    @State private var selectedContactType: ContactType? = nil
    @State private var selectedTags: Set<RecordTag> = []
    @State private var recordDate = Date()
    @State private var recordDuration: Int? = nil
    @State private var recordLocation = ""
    @State private var isImportant = false
    
    // 필터링 상태
    @State private var filterContactType: ContactType? = nil
    @State private var filterTag: RecordTag? = nil
    @State private var showUnresolvedOnly = false
    
    // 최근 기록들 (최대 20개)
    private var filteredRecords: [Record] {
        var records = person.getAllRecordsSorted()
        
        if let contactType = filterContactType {
            records = records.filter { $0.contactType == contactType }
        }
        
        if let tag = filterTag {
            records = records.filter { $0.tags.contains(tag) }
        }
        
        if showUnresolvedOnly {
            records = records.filter { !$0.isResolved && ($0.tags.contains(.promise) || $0.tags.contains(.question)) }
        }
        
        return Array(records.prefix(20))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 빠른 메모 섹션 (기존 호환성 유지)
                quickMemoSection
                
                // 통합 기록 입력 섹션
                recordInputSection
                
                // 필터 섹션
                filterSection
                
                // 기록 목록
                recordsListSection
            }
            .padding()
        }
        .popover(isPresented: $showingMemoArchive, arrowEdge: .trailing) {
            MacQuickMemoArchiveView(person: person, context: context)
                .frame(width: 600, height: 500)
        }
    }
    
    // MARK: - 빠른 메모 섹션 (기존 호환성 유지)
    
    @ViewBuilder
    private var quickMemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("빠른 메모")
                        .font(.headline)
                    Text("대화 내용을 자유롭게 메모하세요. 저장하면 기록에 추가됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 아카이브 보기 버튼 (기존 메모)
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
                    Image(systemName: "plus.circle.fill")
                    Text("기록에 추가")
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
    
    // MARK: - 통합 기록 입력 섹션
    
    @ViewBuilder
    private var recordInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("기록 추가")
                .font(.headline)
            
            VStack(spacing: 12) {
                // 접촉 타입 선택 (선택사항)
                VStack(alignment: .leading, spacing: 8) {
                    Text("접촉 타입 (선택)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            // 없음 버튼
                            Button {
                                selectedContactType = nil
                            } label: {
                                VStack(spacing: 4) {
                                    Text("📝")
                                        .font(.title2)
                                    Text("메모만")
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedContactType == nil ? Color.gray.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedContactType == nil ? Color.gray : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundStyle(selectedContactType == nil ? .primary : .secondary)
                            }
                            .buttonStyle(.plain)
                            
                            ForEach(ContactType.allCases, id: \.self) { type in
                                Button {
                                    selectedContactType = type
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(type.emoji)
                                            .font(.title2)
                                        Text(type.rawValue)
                                            .font(.caption2)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(selectedContactType == type ? type.color.opacity(0.2) : Color.clear)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedContactType == type ? type.color : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .foregroundStyle(selectedContactType == type ? type.color : .secondary)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                
                // 태그 선택 (복수 선택 가능)
                VStack(alignment: .leading, spacing: 8) {
                    Text("태그 (복수 선택 가능)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    FlowLayout(spacing: 8) {
                        ForEach(RecordTag.allCases, id: \.self) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(tag.emoji)
                                    Text(tag.rawValue)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(selectedTags.contains(tag) ? tag.color.opacity(0.2) : Color.clear)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedTags.contains(tag) ? tag.color : Color.gray.opacity(0.3), lineWidth: 1)
                                )
                                .foregroundStyle(selectedTags.contains(tag) ? tag.color : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                // 내용 입력
                TextEditor(text: $recordContent)
                    .frame(minHeight: 80)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .overlay(alignment: .topLeading) {
                        if recordContent.isEmpty {
                            Text("기록 내용을 입력하세요...")
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
                    DatePicker("", selection: $recordDate, displayedComponents: [.date, .hourAndMinute])
                        .labelsHidden()
                        .frame(width: 200)
                    
                    // 시간 (분)
                    if selectedContactType != nil {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundStyle(.secondary)
                            TextField("시간(분)", value: $recordDuration, format: .number)
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
                            TextField("장소", text: $recordLocation)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 120)
                        }
                    }
                    
                    // 중요 표시
                    Toggle(isOn: $isImportant) {
                        HStack(spacing: 4) {
                            Image(systemName: isImportant ? "star.fill" : "star")
                                .foregroundStyle(isImportant ? .yellow : .secondary)
                            Text("중요")
                                .font(.caption)
                        }
                    }
                    .toggleStyle(.button)
                    
                    Spacer()
                    
                    // 저장 버튼
                    Button {
                        saveRecord()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text("기록")
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(recordContent.isEmpty ? Color.gray : (selectedContactType?.color ?? Color.blue))
                        .foregroundStyle(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(recordContent.isEmpty)
                }
            }
            .padding()
            .background((selectedContactType?.color ?? Color.blue).opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke((selectedContactType?.color ?? Color.blue).opacity(0.2), lineWidth: 1)
            )
        }
    }
    
    // MARK: - 필터 섹션
    
    @ViewBuilder
    private var filterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("기록 목록")
                    .font(.headline)
                
                Spacer()
                
                // 통계
                Text("\(person.records.count)개 기록")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 12) {
                // 접촉 타입 필터
                Menu {
                    Button("전체") {
                        filterContactType = nil
                    }
                    Divider()
                    ForEach(ContactType.allCases, id: \.self) { type in
                        Button("\(type.emoji) \(type.rawValue)") {
                            filterContactType = type
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let type = filterContactType {
                            Text(type.emoji)
                            Text(type.rawValue)
                        } else {
                            Text("접촉 타입")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 태그 필터
                Menu {
                    Button("전체") {
                        filterTag = nil
                    }
                    Divider()
                    ForEach(RecordTag.allCases, id: \.self) { tag in
                        Button("\(tag.emoji) \(tag.rawValue)") {
                            filterTag = tag
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if let tag = filterTag {
                            Text(tag.emoji)
                            Text(tag.rawValue)
                        } else {
                            Text("태그")
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // 미해결만 보기
                Toggle(isOn: $showUnresolvedOnly) {
                    Text("미해결만")
                        .font(.caption)
                }
                .toggleStyle(.button)
                .tint(.orange)
                
                Spacer()
            }
        }
    }
    
    // MARK: - 기록 목록 섹션
    
    @ViewBuilder
    private var recordsListSection: some View {
        if filteredRecords.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("기록이 없어요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(filteredRecords) { record in
                    MacRecordRow(record: record, context: context)
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveQuickMemo() {
        let trimmedMemo = person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMemo.isEmpty else { return }
        
        // 1. 아카이브에 저장 (기존 호환성)
        let archive = QuickMemoArchive(content: trimmedMemo, createdDate: Date())
        archive.person = person
        context.insert(archive)
        person.archivedMemos.append(archive)
        
        // 2. 통합 Record도 생성
        let record = person.addRecord(
            contactType: nil,
            content: trimmedMemo,
            notes: nil,
            tags: [],
            date: Date(),
            isImportant: false
        )
        context.insert(record)
        
        do {
            try context.save()
            person.quickMemo = ""
            print("✅ 빠른 메모 저장 완료 - Record 생성됨")
        } catch {
            print("❌ 빠른 메모 저장 실패: \(error)")
        }
    }
    
    private func saveRecord() {
        let trimmedContent = recordContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        var tags = Array(selectedTags)
        if isImportant && !tags.contains(.important) {
            tags.append(.important)
        }
        
        let record = person.addRecord(
            contactType: selectedContactType,
            content: trimmedContent,
            notes: nil,
            tags: tags,
            date: recordDate,
            duration: recordDuration.map { TimeInterval($0 * 60) },
            location: recordLocation.isEmpty ? nil : recordLocation,
            isImportant: isImportant
        )
        context.insert(record)
        
        do {
            try context.save()
            // 초기화
            recordContent = ""
            selectedContactType = nil
            selectedTags = []
            recordDate = Date()
            recordDuration = nil
            recordLocation = ""
            isImportant = false
            print("✅ 기록 저장 완료")
        } catch {
            print("❌ 기록 저장 실패: \(error)")
        }
    }
}

// MARK: - Mac Record Row

struct MacRecordRow: View {
    let record: Record
    let context: ModelContext
    
    @State private var isExpanded = false
    
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 헤더
            HStack(spacing: 12) {
                // 이모지
                Text(record.displayEmoji)
                    .font(.title)
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        // 접촉 타입
                        if let contactType = record.contactType {
                            Text(contactType.rawValue)
                                .font(.headline)
                                .foregroundStyle(contactType.color)
                        } else {
                            Text("메모")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 태그들
                        ForEach(record.tags, id: \.self) { tag in
                            Text(tag.emoji)
                                .font(.caption)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(tag.color.opacity(0.2))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                        
                        // 날짜
                        Text(formatRelativeDate(record.date))
                            .font(.caption)
                            .foregroundStyle(record.isRecent ? .green : .secondary)
                    }
                    
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 내용
            Text(record.content)
                .font(.body)
                .lineLimit(isExpanded ? nil : 3)
            
            // 부가 정보
            HStack(spacing: 12) {
                if let duration = record.formattedDuration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(duration)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                if let location = record.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                
                if record.hasAudio {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                        Text("음성")
                            .font(.caption)
                    }
                    .foregroundStyle(.purple)
                }
                
                if record.hasImages {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                            .font(.caption2)
                        Text("\(record.imageDataArray?.count ?? 0)")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
                
                Spacer()
                
                // 해결/미해결 상태 (약속이나 질문인 경우)
                if record.tags.contains(.promise) || record.tags.contains(.question) {
                    Button {
                        record.toggleResolved()
                        try? context.save()
                    } label: {
                        Text(record.isResolved ? "✅ 해결됨" : "⏳ 진행중")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(record.isResolved ? Color.green.opacity(0.2) : Color.orange.opacity(0.2))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                
                // 확장/축소 버튼
                if record.content.count > 100 {
                    Button {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(record.isRecent ? record.displayColor.opacity(0.1) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(record.isRecent ? record.displayColor.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Mac Quick Memo Archive View (기존 호환성 유지)

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

// MARK: - Mac Memo Archive Row (기존 호환성 유지)

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
