//
//  MacPersonTimelineTab.swift
//  mac
//
//  Created by Claude on 12/13/25.
//

import SwiftUI
import SwiftData

/// Mac용 타임라인 탭 - 특정 사람의 모든 기록을 시간순으로 보여줌
struct MacPersonTimelineTab: View {
    @Bindable var person: Person
    @State private var selectedFilter: TimelineFilter = .all
    @State private var showImportantOnly = false
    @State private var selectedItem: TimelineItem?

    private var groupedItems: [GroupedTimelineItems] {
        person.getGroupedTimelineItems(filter: selectedFilter, importantOnly: showImportantOnly)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더 with 필터
            headerView

            Divider()

            // 타임라인 내용
            if groupedItems.isEmpty {
                emptyStateView
            } else {
                timelineContent
            }
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("타임라인")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                // 중요한 것만 토글
                Button {
                    showImportantOnly.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showImportantOnly ? "star.fill" : "star")
                        Text("중요한 것만")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(showImportantOnly ? Color.yellow.opacity(0.2) : Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
            }

            // 필터 버튼들
            HStack(spacing: 8) {
                MacFilterButton(
                    title: "전체",
                    icon: "list.bullet",
                    isSelected: selectedFilter == .all
                ) {
                    selectedFilter = .all
                }

                MacFilterButton(
                    title: "상호작용",
                    icon: "bubble.left",
                    isSelected: selectedFilter == .interaction
                ) {
                    selectedFilter = .interaction
                }

                MacFilterButton(
                    title: "미팅",
                    icon: "waveform.circle",
                    isSelected: selectedFilter == .meeting
                ) {
                    selectedFilter = .meeting
                }

                MacFilterButton(
                    title: "대화",
                    icon: "message",
                    isSelected: selectedFilter == .conversation
                ) {
                    selectedFilter = .conversation
                }

                MacFilterButton(
                    title: "메모",
                    icon: "note.text",
                    isSelected: selectedFilter == .memo
                ) {
                    selectedFilter = .memo
                }

                MacFilterButton(
                    title: "액션",
                    icon: "checkmark.circle",
                    isSelected: selectedFilter == .action
                ) {
                    selectedFilter = .action
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var timelineContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(groupedItems) { group in
                    groupSection(for: group)
                }
            }
            .padding()
        }
    }

    @ViewBuilder
    private func groupSection(for group: GroupedTimelineItems) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // 그룹 헤더
            HStack {
                Text(group.group.rawValue)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Text("\(group.items.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.1))
                    )
            }
            .padding(.top, 16)

            // 아이템들
            ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                MacTimelineItemRow(
                    item: item,
                    isLast: index == group.items.count - 1
                )
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("타임라인이 비어있어요")
                .font(.headline)

            Text(showImportantOnly ? "중요한 기록이 없습니다" : "아직 기록이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Mac Timeline Item Row

/// Mac용 타임라인 아이템 행
struct MacTimelineItemRow: View {
    let item: TimelineItem
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 타임라인 시각화
            VStack(spacing: 0) {
                Circle()
                    .fill(item.type.color)
                    .frame(width: 10, height: 10)

                if !isLast {
                    Rectangle()
                        .fill(item.type.color.opacity(0.2))
                        .frame(width: 2)
                        .frame(height: 60)
                }
            }
            .frame(width: 20)

            // 내용
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: item.type.icon)
                        .font(.caption)
                        .foregroundStyle(item.type.color)

                    Text(item.type.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(item.type.color)

                    if item.type.isImportant {
                        Image(systemName: "star.fill")
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                    }

                    Spacer()

                    Text(item.date, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !item.type.previewText.isEmpty {
                    Text(item.type.previewText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // 첨부파일 인디케이터
                if item.type.hasAttachments {
                    HStack(spacing: 4) {
                        ForEach(item.type.attachmentIcons, id: \.self) { iconName in
                            Image(systemName: iconName)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Text("\(item.type.attachmentCount)개")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }

                HStack {
                    Text(item.type.categoryName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text(item.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(item.type.color.opacity(0.05))
            )
        }
        .padding(.vertical, 4) // 위아래 추가 클릭 영역
        .contentShape(Rectangle()) // 전체 영역을 클릭 가능하게
    }
}

// MARK: - Mac Filter Button

/// Mac용 필터 버튼
struct MacFilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            )
            .foregroundStyle(isSelected ? .blue : .secondary)
            .contentShape(Rectangle()) // 전체 영역을 클릭 가능하게
            .padding(.vertical, 4) // 위아래 추가 클릭 영역
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    MacPersonTimelineTab(person: Person(
        name: "김철수",
        contact: "010-1234-5678"
    ))
    .frame(width: 600, height: 800)
}
