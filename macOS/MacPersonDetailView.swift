//
//  MacPersonDetailView.swift
//  mac
//
//  macOS용 Person 상세 화면
//

import SwiftUI
import SwiftData
import EventKit
import UniformTypeIdentifiers

struct MacPersonDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var selectedTab = 0
    @State private var showingImagePicker = false
    @State private var showingBadgeDetails = false
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            personHeader
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 탭 뷰
            TabView(selection: $selectedTab) {
                // 대시보드 탭 (새로 추가)
                MacPersonDashboardTab(person: person)
                    .tabItem {
                        Label("대시보드", systemImage: "square.grid.2x2")
                    }
                    .tag(0)

                // 기록 탭
                MacPersonRecordsTab(person: person)
                    .tabItem {
                        Label("기록", systemImage: "pencil")
                    }
                    .tag(1)

                // 타임라인 탭
                MacPersonTimelineTab(person: person)
                    .tabItem {
                        if person.timelineBadgeCount > 0 {
                            Label("타임라인", systemImage: "clock.arrow.circlepath")
                            Text("\(person.timelineBadgeCount)")
                        } else {
                            Label("타임라인", systemImage: "clock.arrow.circlepath")
                        }
                    }
                    .badge(person.timelineBadgeCount)
                    .tag(2)

                // 관계도 탭 (새로 추가)
                MacRelationshipGraphView(person: person)
                    .tabItem {
                        Label("관계", systemImage: "person.3")
                    }
                    .tag(3)

                // 정보 탭
                MacPersonInfoTab(person: person)
                    .tabItem {
                        Label("정보", systemImage: "info.circle")
                    }
                    .tag(4)
            }
            .tabViewStyle(.automatic)
        }
        .popover(isPresented: $showingBadgeDetails) {
            BadgeDetailsPopover(person: person, selectedTab: $selectedTab)
                .frame(width: 350)
        }
        .alert("\(person.name)을(를) 삭제할까요?", isPresented: $showingDeleteAlert) {
            Button("삭제", role: .destructive) {
                context.delete(person)
                try? context.save()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 사람의 모든 발견, 메모, 기록이 함께 삭제됩니다.")
        }
    }

    private var personHeader: some View {
        HStack(spacing: 20) {
            // 프로필 이미지
            Button {
                showingImagePicker = true
            } label: {
                Group {
                    if let imageData = person.profileImageData,
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                Text(person.name)
                    .font(.title)
                    .fontWeight(.bold)

                if !person.contact.isEmpty {
                    Text(person.contact)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                // 소홀 상태
                if person.isNeglected {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("소홀함")
                    }
                    .font(.caption)
                    .foregroundStyle(.orange)
                }
            }

            Spacer()

            // 삭제 버튼
            Button(role: .destructive) {
                showingDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .help("삭제")

            // 배지 섹션 (탭 가능)
            HStack(spacing: 16) {
                // 알림 버튼
                if person.hasBadges {
                    Button {
                        showingBadgeDetails.toggle()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "bell.badge.fill")
                                .font(.title2)
                                .foregroundStyle(.red)
                            Text("알림")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.red.opacity(0.1))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .help("배지가 생긴 이유 보기")
                }

                // 미완료 액션 배지 (긴급 포함)
                if person.incompleteActionsCount > 0 {
                    MacBadgeButton(
                        count: person.incompleteActionsCount,
                        title: person.criticalActionsCount > 0 ? "미완료 (긴급 \(person.criticalActionsCount))" : "미완료 액션",
                        color: person.criticalActionsCount > 0 ? .red : .blue,
                        icon: person.criticalActionsCount > 0 ? "exclamationmark.circle.fill" : "checkmark.circle"
                    ) {
                        selectedTab = 3 // 활동 탭으로 이동
                    }
                }

                // 중요 항목 배지
                if person.importantItemsCount > 0 {
                    MacBadgeButton(
                        count: person.importantItemsCount,
                        title: "중요 항목",
                        color: .yellow,
                        icon: "star.fill"
                    ) {
                        selectedTab = 2 // 타임라인 탭으로 이동
                    }
                }
            }
        }
    }
}

#Preview {
    MacPersonDetailView(person: Person(name: "홍길동", contact: "010-1234-5678"))
        .modelContainer(for: [Person.self])
}
