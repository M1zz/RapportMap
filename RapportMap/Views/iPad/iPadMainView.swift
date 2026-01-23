//
//  iPadMainView.swift
//  RapportMap
//
//  iPad 전용 메인 화면
//  - NavigationSplitView로 사이드바 + 메인 콘텐츠
//  - 관계 맵 시각화
//  - 드래그 앤 드롭
//  - Apple Pencil 지원
//

import SwiftUI
import SwiftData

enum iPadSidebarSelection: Hashable {
    case people
    case relationshipMap
    case mentoring
    case settings
}

struct iPadMainView: View {
    @State private var selection: iPadSidebarSelection? = .people
    @State private var selectedPerson: Person?

    var body: some View {
        NavigationSplitView {
            iPadSidebarView(selection: $selection, selectedPerson: $selectedPerson)
        } detail: {
            iPadDetailView(selection: selection, selectedPerson: selectedPerson)
        }
    }
}

// MARK: - Sidebar

struct iPadSidebarView: View {
    @Binding var selection: iPadSidebarSelection?
    @Binding var selectedPerson: Person?
    @Query(sort: \Person.name) private var people: [Person]

    var body: some View {
        List(selection: $selection) {
            // 주요 섹션
            Section("메인") {
                NavigationLink(value: iPadSidebarSelection.people) {
                    Label("사람 목록", systemImage: "person.3.fill")
                }

                NavigationLink(value: iPadSidebarSelection.relationshipMap) {
                    Label("관계 맵", systemImage: "map.fill")
                }
                .badge("NEW")

                NavigationLink(value: iPadSidebarSelection.mentoring) {
                    Label("멘토링", systemImage: "bubble.left.and.bubble.right.fill")
                }
            }

            // 사람 목록
            Section("사람") {
                ForEach(people) { person in
                    Button {
                        selectedPerson = person
                        selection = .people
                    } label: {
                        HStack {
                            // 프로필 이미지
                            if let imageData = person.profileImageData,
                               let uiImage = UIImage(data: imageData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.gray)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(person.name)
                                    .font(.subheadline)
                                    .foregroundStyle(selectedPerson?.id == person.id ? .blue : .primary)

                                if !person.contact.isEmpty {
                                    Text(person.contact)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if selectedPerson?.id == person.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .font(.caption)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            // 설정
            Section {
                NavigationLink(value: iPadSidebarSelection.settings) {
                    Label("설정", systemImage: "gearshape.fill")
                }
            }
        }
        .navigationTitle("RapportMap")
    }
}

// MARK: - Detail View

struct iPadDetailView: View {
    let selection: iPadSidebarSelection?
    let selectedPerson: Person?

    var body: some View {
        Group {
            if let selection = selection {
                switch selection {
                case .people:
                    if let person = selectedPerson {
                        iPadPersonDetailView(person: person)
                    } else {
                        iPadPeopleListEmptyState()
                    }

                case .relationshipMap:
                    iPadRelationshipMapView()

                case .mentoring:
                    MentoringListView()

                case .settings:
                    SettingsView()
                }
            } else {
                iPadWelcomeView()
            }
        }
    }
}

// MARK: - Empty States

struct iPadWelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "map.fill")
                .font(.system(size: 80))
                .foregroundStyle(.blue)

            Text("RapportMap for iPad")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("왼쪽 사이드바에서 메뉴를 선택하세요")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                FeatureRow(
                    icon: "map.fill",
                    title: "관계 맵 시각화",
                    description: "사람들 간의 관계를 시각적으로 확인"
                )

                FeatureRow(
                    icon: "hand.draw.fill",
                    title: "Apple Pencil 지원",
                    description: "자유롭게 메모하고 스케치"
                )

                FeatureRow(
                    icon: "move.3d",
                    title: "드래그 앤 드롭",
                    description: "직관적인 활동 관리"
                )
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.blue.opacity(0.05))
            )
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct iPadPeopleListEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("사람을 선택하세요")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text("왼쪽 사이드바에서 사람을 선택하면\n상세 정보가 여기에 표시됩니다")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Person Detail View (iPad 최적화)

struct iPadPersonDetailView: View {
    @Bindable var person: Person
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 정보 탭
            ScrollView {
                iPadPersonInfoView(person: person)
                    .padding()
            }
            .tabItem {
                Label("정보", systemImage: "info.circle")
            }
            .tag(0)

            // 활동 탭
            iPadPersonActionsView(person: person)
                .tabItem {
                    Label("활동", systemImage: "checklist")
                }
                .tag(1)

            // 기록 탭
            iPadPersonRecordsView(person: person)
                .tabItem {
                    Label("기록", systemImage: "calendar")
                }
                .tag(2)

            // 분석 탭
            iPadPersonAnalyticsView(person: person)
                .tabItem {
                    Label("분석", systemImage: "chart.bar.fill")
                }
                .tag(3)

            // 메모 탭 (Apple Pencil)
            iPadPersonNotesView(person: person)
                .tabItem {
                    Label("메모", systemImage: "pencil.tip")
                }
                .tag(4)
                .badge("NEW")
        }
        .navigationTitle(person.name)
    }
}

// MARK: - Placeholder Views (구현 예정)

struct iPadPersonInfoView: View {
    @Bindable var person: Person

    var body: some View {
        Text("정보 탭 - iPhone의 PersonInfoView 재사용 예정")
            .foregroundStyle(.secondary)
    }
}

struct iPadPersonActionsView: View {
    @Bindable var person: Person

    var body: some View {
        Text("활동 탭 - 드래그 앤 드롭 추가 예정")
            .foregroundStyle(.secondary)
    }
}

struct iPadPersonRecordsView: View {
    @Bindable var person: Person

    var body: some View {
        Text("기록 탭 - iPhone 뷰 재사용 예정")
            .foregroundStyle(.secondary)
    }
}

struct iPadPersonAnalyticsView: View {
    @Bindable var person: Person

    var body: some View {
        Text("분석 탭 - Mac의 분석 뷰 재사용 예정")
            .foregroundStyle(.secondary)
    }
}

struct iPadPersonNotesView: View {
    @Bindable var person: Person

    var body: some View {
        Text("메모 탭 - Apple Pencil 지원 예정")
            .foregroundStyle(.secondary)
    }
}

// MARK: - Relationship Map View (킬러 피처!)

typealias iPadRelationshipMapView = RelationshipMapView

#Preview {
    iPadMainView()
        .modelContainer(for: [Person.self])
}
