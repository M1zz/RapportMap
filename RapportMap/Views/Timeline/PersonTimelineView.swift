//
//  PersonTimelineView.swift
//  RapportMap
//
//  Created by Claude on 12/13/25.
//

import SwiftUI
import SwiftData

/// 특정 사람의 모든 기록을 시간순으로 보여주는 타임라인 뷰
struct PersonTimelineView: View {
    @Bindable var person: Person
    @State private var selectedFilter: TimelineFilter = .all
    @State private var showImportantOnly = false
    @State private var selectedItem: TimelineItem?

    private var groupedItems: [GroupedTimelineItems] {
        person.getGroupedTimelineItems(filter: selectedFilter, importantOnly: showImportantOnly)
    }

    private var totalCount: Int {
        groupedItems.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 필터 툴바
            filterToolbar

            Divider()

            // 타임라인 내용
            if groupedItems.isEmpty {
                emptyState
            } else {
                timelineContent
            }
        }
        .sheet(item: $selectedItem) { item in
            // 상세 뷰로 이동 (추후 구현)
            NavigationStack {
                detailView(for: item)
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var filterToolbar: some View {
        VStack(spacing: 12) {
            // 필터 버튼들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(
                        title: "전체",
                        icon: "list.bullet",
                        isSelected: selectedFilter == .all,
                        color: .gray
                    ) {
                        selectedFilter = .all
                    }

                    FilterChip(
                        title: "상호작용",
                        icon: "bubble.left",
                        isSelected: selectedFilter == .interaction,
                        color: .blue
                    ) {
                        selectedFilter = .interaction
                    }

                    FilterChip(
                        title: "미팅",
                        icon: "waveform.circle",
                        isSelected: selectedFilter == .meeting,
                        color: .purple
                    ) {
                        selectedFilter = .meeting
                    }

                    FilterChip(
                        title: "대화",
                        icon: "message",
                        isSelected: selectedFilter == .conversation,
                        color: .green
                    ) {
                        selectedFilter = .conversation
                    }

                    FilterChip(
                        title: "메모",
                        icon: "note.text",
                        isSelected: selectedFilter == .memo,
                        color: .yellow
                    ) {
                        selectedFilter = .memo
                    }

                    FilterChip(
                        title: "액션",
                        icon: "checkmark.circle",
                        isSelected: selectedFilter == .action,
                        color: .red
                    ) {
                        selectedFilter = .action
                    }
                }
                .padding(.horizontal)
            }

            // 중요한 것만 토글 + 총 개수
            HStack {
                Toggle(isOn: $showImportantOnly) {
                    Label("중요한 것만", systemImage: "star.fill")
                        .font(.subheadline)
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(.yellow)

                Spacer()

                Text("\(totalCount)개 항목")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var timelineContent: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedItems) { group in
                    Section {
                        ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                            TimelineItemRow(
                                item: item,
                                isFirst: index == 0,
                                isLast: index == group.items.count - 1
                            )
                            .padding(.horizontal)
                            .onTapGesture {
                                selectedItem = item
                            }
                        }
                    } header: {
                        groupHeader(for: group)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func groupHeader(for group: GroupedTimelineItems) -> some View {
        HStack {
            Text(group.group.rawValue)
                .font(.headline)
                .foregroundStyle(.primary)

            Spacer()

            Text("\(group.items.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemGroupedBackground))
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("타임라인이 비어있어요")
                .font(.headline)

            if showImportantOnly {
                Text("중요한 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func detailView(for item: TimelineItem) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 12) {
                    Text(item.type.emoji)
                        .font(.system(size: 60))

                    Text(item.type.title)
                        .font(.title2)
                        .fontWeight(.bold)

                    Text(item.date.formatted(date: .long, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Divider()

                // 내용
                if !item.type.previewText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("내용")
                            .font(.headline)
                        Text(item.type.previewText)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemGray6))
                    )
                }

                // 첨부파일
                if item.type.hasAttachments {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("첨부파일 (\(item.type.attachmentCount)개)")
                            .font(.headline)

                        // 사진 표시
                        if let photoDataList = item.type.photoDataList, !photoDataList.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(Array(photoDataList.enumerated()), id: \.offset) { index, data in
                                        if let uiImage = UIImage(data: data) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 120)
                                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                        }
                                    }
                                }
                            }
                        }

                        // 상호작용 첨부파일 목록
                        if let attachments = item.type.interactionAttachments, !attachments.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(attachments) { attachment in
                                    HStack {
                                        Image(systemName: attachmentIcon(for: attachment.fileType))
                                            .foregroundStyle(item.type.color)
                                        Text(attachment.fileName)
                                            .font(.body)
                                        Spacer()
                                        Text(attachmentSize(data: attachment.fileData))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color(.systemGray6))
                                    )
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding()
        }
        .navigationTitle("상세 정보")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("닫기") {
                    selectedItem = nil
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func attachmentIcon(for type: AttachmentFileType) -> String {
        switch type {
        case .image: return "photo"
        case .audio: return "waveform"
        case .video: return "video"
        case .pdf: return "doc.text"
        case .document: return "doc"
        case .other: return "paperclip"
        }
    }

    private func attachmentSize(data: Data) -> String {
        let bytes = Double(data.count)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }
}

// MARK: - Filter Chip Component

/// 필터 선택 칩 컴포넌트
struct FilterChip: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? color.opacity(0.2) : Color(.systemGray6))
            )
            .foregroundStyle(isSelected ? color : .secondary)
            .overlay(
                Capsule()
                    .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle()) // 전체 영역을 탭 가능하게
            .padding(.vertical, 4) // 위아래 추가 탭 영역
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    NavigationStack {
        PersonTimelineView(person: Person(
            name: "김철수",
            contact: "010-1234-5678"
        ))
        .navigationTitle("타임라인")
        .navigationBarTitleDisplayMode(.inline)
    }
}
