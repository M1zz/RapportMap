//
//  MacPersonRecordsTab.swift
//  mac
//
//  macOS용 Person 기록 탭 - 통합 Record 모델 사용
//

import SwiftUI
import SwiftData

struct MacPersonRecordsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    
    // 필터 상태
    @State private var selectedContactFilter: ContactType? = nil
    @State private var selectedTagFilter: RecordTag? = nil
    @State private var showUnresolvedOnly = false
    @State private var searchText = ""
    
    // 새 기록 추가 상태
    @State private var showingAddRecord = false
    
    // 필터링된 기록
    private var filteredRecords: [Record] {
        var records = person.records.sorted { $0.date > $1.date }
        
        // 접촉 타입 필터
        if let contactFilter = selectedContactFilter {
            records = records.filter { $0.contactType == contactFilter }
        }
        
        // 태그 필터
        if let tagFilter = selectedTagFilter {
            records = records.filter { $0.tags.contains(tagFilter) }
        }
        
        // 미해결만
        if showUnresolvedOnly {
            records = records.filter { !$0.isResolved && $0.needsResolution }
        }
        
        // 검색
        if !searchText.isEmpty {
            records = records.filter {
                $0.content.localizedCaseInsensitiveContains(searchText) ||
                ($0.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        return records
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단: 필터 + 검색 + 새 기록 버튼
            headerSection
            
            Divider()
            
            // 기록 리스트
            if filteredRecords.isEmpty {
                emptyStateView
            } else {
                recordsList
            }
        }
        .sheet(isPresented: $showingAddRecord) {
            AddRecordSheet(person: person)
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                // 검색
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("검색...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .frame(maxWidth: 250)
                
                Spacer()
                
                // 기록 수
                Text("\(filteredRecords.count)개 기록")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                // 새 기록 버튼
                Button {
                    showingAddRecord = true
                } label: {
                    Label("새 기록", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // 필터 칩들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 접촉 타입 필터
                    FilterChip(
                        title: "전체",
                        isSelected: selectedContactFilter == nil,
                        color: .gray
                    ) {
                        selectedContactFilter = nil
                    }
                    
                    ForEach(ContactType.allCases, id: \.self) { type in
                        FilterChip(
                            title: type.title,
                            icon: type.icon,
                            isSelected: selectedContactFilter == type,
                            color: type.color
                        ) {
                            selectedContactFilter = selectedContactFilter == type ? nil : type
                        }
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // 태그 필터
                    ForEach(RecordTag.allCases, id: \.self) { tag in
                        FilterChip(
                            title: tag.title,
                            icon: tag.icon,
                            isSelected: selectedTagFilter == tag,
                            color: tag.color
                        ) {
                            selectedTagFilter = selectedTagFilter == tag ? nil : tag
                        }
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // 미해결만 토글
                    FilterChip(
                        title: "미해결",
                        icon: "circle",
                        isSelected: showUnresolvedOnly,
                        color: .orange
                    ) {
                        showUnresolvedOnly.toggle()
                    }
                }
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Records List
    
    private var recordsList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filteredRecords) { record in
                    RecordRow(record: record, onToggleResolved: {
                        toggleResolved(record)
                    }, onDelete: {
                        deleteRecord(record)
                    })
                }
            }
            .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text(searchText.isEmpty && selectedContactFilter == nil && selectedTagFilter == nil
                 ? "아직 기록이 없어요"
                 : "검색 결과가 없어요")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            if searchText.isEmpty && selectedContactFilter == nil && selectedTagFilter == nil {
                Button {
                    showingAddRecord = true
                } label: {
                    Label("첫 기록 추가하기", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func toggleResolved(_ record: Record) {
        record.isResolved.toggle()
        if record.isResolved {
            record.resolvedDate = Date()
        } else {
            record.resolvedDate = nil
        }
        try? context.save()
    }
    
    private func deleteRecord(_ record: Record) {
        context.delete(record)
        try? context.save()
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    var icon: String? = nil
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundStyle(isSelected ? color : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Record Row

struct RecordRow: View {
    @Bindable var record: Record
    let onToggleResolved: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                // 접촉 타입 아이콘
                if let contactType = record.contactType {
                    Text(contactType.emoji)
                        .font(.title2)
                } else {
                    Image(systemName: "note.text")
                        .font(.title2)
                        .foregroundStyle(.gray)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    // 상단: 타입 + 날짜
                    HStack {
                        if let contactType = record.contactType {
                            Text(contactType.title)
                                .font(.headline)
                                .foregroundStyle(contactType.color)
                        } else {
                            Text("메모")
                                .font(.headline)
                                .foregroundStyle(.gray)
                        }
                        
                        Spacer()
                        
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(relativeDate)
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    // 내용
                    Text(record.content)
                        .font(.body)
                        .lineLimit(isExpanded ? nil : 2)
                    
                    // 태그들
                    if !record.tags.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(record.tags, id: \.self) { tag in
                                HStack(spacing: 2) {
                                    Image(systemName: tag.icon)
                                        .font(.caption2)
                                    Text(tag.title)
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(tag.color.opacity(0.15))
                                .foregroundStyle(tag.color)
                                .cornerRadius(4)
                            }
                            
                            // 해결 상태
                            if record.needsResolution {
                                Button(action: onToggleResolved) {
                                    HStack(spacing: 2) {
                                        Image(systemName: record.isResolved ? "checkmark.circle.fill" : "circle")
                                        Text(record.isResolved ? "해결됨" : "미해결")
                                    }
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(record.isResolved ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                                    .foregroundStyle(record.isResolved ? .green : .orange)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 부가 정보
                    if record.duration != nil || record.location != nil {
                        HStack(spacing: 12) {
                            if let duration = record.duration {
                                Label("\(Int(duration))분", systemImage: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let location = record.location, !location.isEmpty {
                                Label(location, systemImage: "location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                
                // 호버 시 삭제 버튼
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(borderColor, lineWidth: 1)
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.date, relativeTo: Date())
    }
    
    private var backgroundColor: Color {
        if record.isImportant {
            return Color.yellow.opacity(0.1)
        } else if let contactType = record.contactType {
            return contactType.color.opacity(0.05)
        }
        return Color(NSColor.controlBackgroundColor)
    }
    
    private var borderColor: Color {
        if record.isImportant {
            return Color.yellow.opacity(0.3)
        } else if !record.isResolved && record.needsResolution {
            return Color.orange.opacity(0.3)
        }
        return Color.gray.opacity(0.1)
    }
}

// MARK: - Add Record Sheet

struct AddRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    
    @State private var content = ""
    @State private var selectedContactType: ContactType? = nil
    @State private var selectedTags: Set<RecordTag> = []
    @State private var date = Date()
    @State private var duration: Int? = nil
    @State private var location = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // 헤더
            HStack {
                Text("새 기록")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("취소") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            
            // 접촉 타입 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("접촉 방식")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ContactTypeButton(type: nil, emoji: "📝", title: "메모만", isSelected: selectedContactType == nil) {
                        selectedContactType = nil
                    }
                    
                    ForEach(ContactType.allCases, id: \.self) { type in
                        ContactTypeButton(type: type, emoji: type.emoji, title: type.title, isSelected: selectedContactType == type) {
                            selectedContactType = type
                        }
                    }
                }
            }
            
            // 내용 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("내용")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextEditor(text: $content)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }
            
            // 태그 선택
            VStack(alignment: .leading, spacing: 8) {
                Text("태그 (복수 선택 가능)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 8) {
                    ForEach(RecordTag.allCases, id: \.self) { tag in
                        TagToggleButton(tag: tag, isSelected: selectedTags.contains(tag)) {
                            if selectedTags.contains(tag) {
                                selectedTags.remove(tag)
                            } else {
                                selectedTags.insert(tag)
                            }
                        }
                    }
                }
            }
            
            // 옵션들
            HStack(spacing: 16) {
                // 날짜
                DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                
                // 시간
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .foregroundStyle(.secondary)
                    TextField("분", value: $duration, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                    Text("분")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 장소
                HStack(spacing: 4) {
                    Image(systemName: "location")
                        .foregroundStyle(.secondary)
                    TextField("장소", text: $location)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                }
                
                Spacer()
            }
            
            Spacer()
            
            // 저장 버튼
            Button {
                saveRecord()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("저장")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(content.isEmpty ? Color.gray : Color.blue)
                .foregroundStyle(.white)
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(content.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .frame(width: 500, height: 450)
    }
    
    private func saveRecord() {
        let record = Record(
            date: date,
            contactType: selectedContactType,
            content: content,
            tags: Array(selectedTags)
        )
        
        if let duration = duration {
            record.duration = TimeInterval(duration * 60)
        }
        if !location.isEmpty {
            record.location = location
        }
        
        record.person = person
        context.insert(record)
        
        do {
            try context.save()
            dismiss()
        } catch {
            print("❌ 기록 저장 실패: \(error)")
        }
    }
}

// MARK: - Contact Type Button

struct ContactTypeButton: View {
    let type: ContactType?
    let emoji: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emoji)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(width: 60, height: 55)
            .background(isSelected ? (type?.color ?? Color.gray).opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? (type?.color ?? Color.gray) : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag Toggle Button

struct TagToggleButton: View {
    let tag: RecordTag
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : tag.icon)
                    .font(.caption)
                Text(tag.title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? tag.color.opacity(0.2) : Color(NSColor.controlBackgroundColor))
            .foregroundStyle(isSelected ? tag.color : .secondary)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? tag.color : Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MacPersonRecordsTab(person: Person(name: "홍길동"))
        .modelContainer(for: [Person.self, Record.self])
        .frame(width: 600, height: 500)
}
