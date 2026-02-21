//
//  MacBadgeComponents.swift
//  mac
//
//  macOS용 배지 관련 컴포넌트들
//

import SwiftUI
import SwiftData

// MARK: - Badge Button Component

struct MacBadgeButton: View {
    let count: Int
    let title: String
    let color: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // 아이콘과 숫자
                HStack(spacing: 4) {
                    Image(systemName: icon)
                        .font(.title3)
                    Text("\(count)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .foregroundStyle(color)

                // 제목
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 80)
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .help("탭하여 \(title) 보기") // 툴팁
    }
}

// MARK: - Badge Details Popover

struct BadgeDetailsPopover: View {
    let person: Person
    @Binding var selectedTab: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 헤더
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.red)
                Text("알림 목록")
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 배지 목록
            ScrollView {
                VStack(spacing: 0) {
                    let badgeDetails = person.getBadgeDetails()

                    if badgeDetails.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.green)
                            Text("모든 항목이 처리되었습니다")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                    } else {
                        ForEach(Array(badgeDetails.enumerated()), id: \.offset) { index, detail in
                            BadgeDetailRow(
                                detail: detail,
                                onTap: {
                                    selectedTab = detail.tabIndex
                                    dismiss()
                                }
                            )

                            if index < badgeDetails.count - 1 {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 400)
        }
        .frame(width: 350)
    }
}

// MARK: - Badge Detail Row

struct BadgeDetailRow: View {
    let detail: Person.BadgeDetail
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // 아이콘과 숫자
                ZStack {
                    Circle()
                        .fill(Color(detail.color).opacity(0.2))
                        .frame(width: 40, height: 40)

                    Text("\(detail.count)")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundStyle(Color(detail.color))
                }

                // 정보
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.category)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(detail.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption2)
                        Text("탭하여 이동")
                            .font(.caption2)
                    }
                    .foregroundStyle(Color(detail.color))
                    .padding(.top, 2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
