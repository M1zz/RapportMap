//
//  TimelineItemRow.swift
//  RapportMap
//
//  Created by Claude on 12/13/25.
//

import SwiftUI

/// 타임라인 아이템을 표시하는 행 컴포넌트
/// ConversationRecordDetailRow 패턴 참고: Circle + 세로 라인으로 타임라인 시각화
struct TimelineItemRow: View {
    let item: TimelineItem
    let isFirst: Bool
    let isLast: Bool
    let showDate: Bool = true

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 타임라인 시각화 (원 + 세로 라인)
            timelineIndicator

            // 내용
            VStack(alignment: .leading, spacing: 8) {
                // 헤더 (아이콘, 제목, 시간)
                header

                // 미리보기 텍스트
                if !item.type.previewText.isEmpty {
                    Text(item.type.previewText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                }

                // 첨부파일 인디케이터
                if item.type.hasAttachments {
                    attachmentsIndicator
                }

                // 카테고리 뱃지
                categoryBadge
            }
            .padding(.bottom, 16)
        }
        .padding(.vertical, 4) // 위아래 추가 탭 영역
        .contentShape(Rectangle()) // 전체 영역을 탭 가능하게
    }

    // MARK: - Subviews

    @ViewBuilder
    private var timelineIndicator: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(item.type.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(item.type.color.opacity(0.3), lineWidth: 2)
                        .frame(width: 18, height: 18)
                )

            if !isLast {
                Rectangle()
                    .fill(item.type.color.opacity(0.2))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var header: some View {
        HStack {
            Image(systemName: item.type.icon)
                .font(.subheadline)
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

            if showDate {
                Text(item.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var categoryBadge: some View {
        Text(item.type.categoryName)
            .font(.caption2)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(item.type.color.opacity(0.15))
            )
            .foregroundStyle(item.type.color)
    }

    @ViewBuilder
    private var attachmentsIndicator: some View {
        HStack(spacing: 6) {
            ForEach(item.type.attachmentIcons, id: \.self) { iconName in
                Image(systemName: iconName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text("\(item.type.attachmentCount)개 첨부됨")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 0) {
        let sampleInteraction = InteractionRecord(
            date: Date(),
            type: .mentoring,
            notes: "오늘 멘토링에서 커리어 방향에 대해 깊이 있는 대화를 나눴습니다.",
            duration: 3600,
            isImportant: true
        )

        TimelineItemRow(
            item: TimelineItem(type: .interaction(sampleInteraction)),
            isFirst: true,
            isLast: false
        )

        TimelineItemRow(
            item: TimelineItem(type: .interaction(sampleInteraction)),
            isFirst: false,
            isLast: true
        )
    }
    .padding()
}
