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

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            personHeader
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 탭 뷰
            TabView(selection: $selectedTab) {
                // 기록 탭
                MacPersonRecordsTab(person: person)
                    .tabItem {
                        Label("기록", systemImage: "pencil")
                    }
                    .tag(0)

                // 캘린더 탭
                MacPersonCalendarTab(person: person)
                    .tabItem {
                        Label("캘린더", systemImage: "calendar")
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

                // 활동 탭
                MacPersonActionsTab(person: person)
                    .tabItem {
                        if person.actionsBadgeCount > 0 {
                            Label("활동", systemImage: "checklist")
                            Text("\(person.actionsBadgeCount)")
                        } else {
                            Label("활동", systemImage: "checklist")
                        }
                    }
                    .badge(person.actionsBadgeCount)
                    .tag(3)

                // 분석 탭
                MacPersonAnalyticsTab(person: person)
                    .tabItem {
                        Label("분석", systemImage: "chart.bar.fill")
                    }
                    .tag(4)

                // 정보 탭
                MacPersonInfoTab(person: person)
                    .tabItem {
                        Label("정보", systemImage: "info.circle")
                    }
                    .tag(5)
            }
            .tabViewStyle(.automatic)
        }
        .popover(isPresented: $showingBadgeDetails) {
            BadgeDetailsPopover(person: person, selectedTab: $selectedTab)
                .frame(width: 350)
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

                // 관계 상태 (읽기 전용 - 자동 계산됨)
                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(person.state.color)
                            .frame(width: 10, height: 10)
                        Text(person.state.localizedName)
                            .font(.callout)
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.gray.opacity(0.1))
                    )
                    .help("관계 상태는 상호작용 빈도와 액션 완료율을 기반으로 자동 계산됩니다")

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
            }

            Spacer()

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

// MARK: - Info Tab

struct MacPersonInfoTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()
    @State private var showingMentoringSession = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // 멘토링 버튼
            HStack {
                Spacer()
                Button {
                    showingMentoringSession = true
                } label: {
                    Label("멘토링 기록", systemImage: "person.2.fill")
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        Section("기본 정보") {
                            TextField("이름", text: $person.name)
                            TextField("연락처", text: $person.contact)
                            TextField("선호 호칭", text: $person.preferredName)
                        }

                        Section("관계 정보") {
                            TextField("관심사", text: $person.interests, axis: .vertical)
                                .lineLimit(3...6)
                            TextField("취향/선호", text: $person.preferences, axis: .vertical)
                                .lineLimit(3...6)
                            TextField("중요한 날짜", text: $person.importantDates, axis: .vertical)
                                .lineLimit(3...6)
                        }

                        Section("빠른 메모") {
                            TextEditor(text: $person.quickMemo)
                                .frame(minHeight: 100)
                                .font(.body)
                        }
                    }
                    .formStyle(.grouped)
                    .padding()

                    // 위험 작업 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("⚠️ 위험 작업")
                            .font(.headline)
                            .foregroundStyle(.red)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("사람 완전 삭제", systemImage: "person.fill.xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)

                        Text("이 사람과 모든 관련 데이터가 영구적으로 삭제됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingMentoringSession) {
            MacPersonMentoringSessionsView(person: person, manager: mentoringManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .alert("사람 삭제", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deletePerson()
            }
        } message: {
            Text("\(person.name)님을 완전히 삭제하시겠습니까?\n\n모든 상호작용, 미팅, 대화, 메모, 액션이 함께 삭제되며 복구할 수 없습니다.")
        }
    }

    private func deletePerson() {
        let personName = person.name
        context.delete(person)

        do {
            try context.save()
            print("✅ \(personName) 완전 삭제됨")

            // 윈도우 닫기
            if let window = NSApplication.shared.keyWindow {
                window.close()
            }
        } catch {
            print("❌ 사람 삭제 실패: \(error)")
        }
    }
}

// MARK: - Actions Tab (활동)

struct MacPersonActionsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()
    @State private var showingMentoringSession = false
    @State private var selectedPhase: ActionPhase? = nil  // nil = 전체 보기
    @State private var showCompletedActions = false
    @Query(sort: \RapportAction.order) private var allRapportActions: [RapportAction]

    private var actionsByPhase: [ActionPhase: [PersonAction]] {
        let filtered = person.actions.filter { action in
            let phaseMatch = action.isVisibleInDetail
            let completionMatch = showCompletedActions ? true : (action.completedDate == nil)
            return phaseMatch && completionMatch
        }
        return Dictionary(grouping: filtered) { action in
            action.action?.phase ?? .surface
        }
    }

    // 각 Phase별 미완료 개수
    private func incompleteCount(for phase: ActionPhase) -> Int {
        person.actions.filter { action in
            action.isVisibleInDetail &&
            action.completedDate == nil &&
            action.action?.phase == phase
        }.count
    }

    private var actionsForSelectedPhase: [PersonAction] {
        if let selectedPhase = selectedPhase {
            // 특정 Phase 선택
            return actionsByPhase[selectedPhase]?.sorted { ($0.action?.order ?? 999) < ($1.action?.order ?? 999) } ?? []
        } else {
            // 전체 보기 - Phase별로 그룹화하여 정렬
            return actionsByPhase.values.flatMap { $0 }.sorted { action1, action2 in
                let phase1 = action1.action?.phase ?? .surface
                let phase2 = action2.action?.phase ?? .surface
                if phase1 != phase2 {
                    return phase1.rawValue < phase2.rawValue
                }
                return (action1.action?.order ?? 999) < (action2.action?.order ?? 999)
            }
        }
    }

    private var incompleteCount: Int {
        person.actions.filter { $0.completedDate == nil }.count
    }

    private var completedCount: Int {
        person.actions.filter { $0.completedDate != nil }.count
    }

    private var availableRapportActions: [RapportAction] {
        guard let selectedPhase = selectedPhase else { return [] }

        // 이미 추가된 액션 ID들
        let addedActionIds = Set(person.actions.filter { $0.isVisibleInDetail }.compactMap { $0.action?.id })

        // 아직 추가하지 않은 액션만 표시
        return allRapportActions.filter { rapportAction in
            rapportAction.phase == selectedPhase &&
            rapportAction.isActive &&
            !addedActionIds.contains(rapportAction.id)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            VStack(spacing: 12) {
                HStack {
                    // Phase 선택기
                    Picker("Phase", selection: $selectedPhase) {
                        Text("전체")
                            .tag(nil as ActionPhase?)
                        ForEach(ActionPhase.allCases) { phase in
                            let count = incompleteCount(for: phase)
                            if count > 0 {
                                Text("\(phase.emoji) \(phase.rawValue) (\(count))")
                                    .tag(phase as ActionPhase?)
                            } else {
                                Text("\(phase.emoji) \(phase.rawValue)")
                                    .tag(phase as ActionPhase?)
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)

                    Spacer()

                    Button {
                        showingMentoringSession = true
                    } label: {
                        Label("멘토링 기록", systemImage: "person.2.fill")
                    }
                }

                // 통계 및 필터
                HStack {
                    HStack(spacing: 16) {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                            Text("미완료: \(incompleteCount)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }

                        HStack(spacing: 6) {
                            Circle()
                                .fill(.green)
                                .frame(width: 8, height: 8)
                            Text("완료: \(completedCount)")
                                .font(.caption)
                        }
                    }

                    Spacer()

                    Toggle(isOn: $showCompletedActions) {
                        Text("완료된 항목 표시")
                            .font(.caption)
                    }
                    .toggleStyle(.switch)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Phase 설명
            HStack {
                if let selectedPhase = selectedPhase {
                    Text(selectedPhase.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("모든 단계의 미완료 액션을 표시합니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 활동 목록
                    if actionsForSelectedPhase.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("이 단계의 활동이 없습니다")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            Text("아래에서 활동을 추가하세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(actionsForSelectedPhase) { action in
                                MacPersonActionRow(action: action)
                            }
                        }
                    }

                    // 활동 추가 섹션
                    if !availableRapportActions.isEmpty {
                        Divider()

                        VStack(alignment: .leading, spacing: 12) {
                            Text("추가 가능한 활동")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: 12) {
                                ForEach(availableRapportActions) { rapportAction in
                                    MacAvailableActionCard(
                                        rapportAction: rapportAction,
                                        person: person,
                                        context: context
                                    )
                                }
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingMentoringSession) {
            MacPersonMentoringSessionsView(person: person, manager: mentoringManager)
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

struct MacPersonActionRow: View {
    @Bindable var action: PersonAction

    var body: some View {
        HStack(spacing: 12) {
            // 완료 체크박스
            Button {
                action.isCompleted.toggle()
                if action.isCompleted {
                    action.completedDate = Date()
                } else {
                    action.completedDate = nil
                }
            } label: {
                Image(systemName: action.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(action.isCompleted ? .green : .gray)
                    .font(.title3)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 6) {
                if let rapportAction = action.action {
                    HStack {
                        Text(rapportAction.title)
                            .font(.headline)
                            .strikethrough(action.isCompleted)

                        Spacer()

                        // 타입 뱃지
                        Text(rapportAction.type.emoji)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(rapportAction.type == .critical ? Color.orange.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                    }

                    if !rapportAction.actionDescription.isEmpty {
                        Text(rapportAction.actionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                if !action.note.isEmpty {
                    Text("메모: \(action.note)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.top, 2)
                }

                if let completedDate = action.completedDate {
                    Text("완료: \(completedDate, style: .date)")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(action.isCompleted ? Color.green.opacity(0.05) : Color.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(action.isCompleted ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                )
        )
        .opacity(action.isCompleted ? 0.7 : 1.0)
    }
}

// MARK: - Available Action Card

struct MacAvailableActionCard: View {
    let rapportAction: RapportAction
    let person: Person
    let context: ModelContext
    @State private var showingAddSheet = false

    var body: some View {
        Button {
            showingAddSheet = true
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(rapportAction.type.emoji)
                        .font(.title3)

                    Spacer()

                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                }

                Text(rapportAction.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                if !rapportAction.actionDescription.isEmpty {
                    Text(rapportAction.actionDescription)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAddSheet) {
            MacAddActionSheet(rapportAction: rapportAction, person: person, context: context)
                .frame(minWidth: 500, minHeight: 300)
        }
    }
}

// MARK: - Add Action Sheet

struct MacAddActionSheet: View {
    let rapportAction: RapportAction
    let person: Person
    let context: ModelContext
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var actionContext = ""

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("활동 추가")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 내용
            Form {
                Section {
                    HStack {
                        Text(rapportAction.type.emoji)
                            .font(.title)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rapportAction.title)
                                .font(.headline)
                            Text(rapportAction.actionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("메모") {
                    TextEditor(text: $note)
                        .frame(minHeight: 60)
                }

                Section("상황/컨텍스트") {
                    TextEditor(text: $actionContext)
                        .frame(minHeight: 60)
                }
            }
            .formStyle(.grouped)

            // 푸터
            HStack {
                Spacer()
                Button("추가") {
                    addAction()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func addAction() {
        let personAction = PersonAction(
            note: note,
            context: actionContext
        )
        personAction.person = person
        personAction.action = rapportAction
        personAction.isVisibleInDetail = true

        context.insert(personAction)
        try? context.save()
    }
}

// MARK: - Records Tab

struct MacPersonRecordsTab: View {
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Bindable var person: Person
    @State private var showingMemoArchive = false

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

                // 기록하기 버튼들
                recordingButtonsSection

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

    // MARK: - 기록하기 버튼 섹션

    @ViewBuilder
    private var recordingButtonsSection: some View {
        VStack(spacing: 12) {
            Text("상호작용 기록하기")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(InteractionType.allCases, id: \.self) { type in
                    Button {
                        InteractionCreationState.shared.person = person
                        InteractionCreationState.shared.interactionType = type
                        openWindow(id: "interaction-creation")
                    } label: {
                        VStack(spacing: 8) {
                            Text(type.emoji)
                                .font(.system(size: 40))

                            Text(type.title)
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(type.color.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(type.color.opacity(0.3), lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
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
        let interactionRecord = person.addInteractionRecord(
            type: .quickNote,  // 빠른 메모로 기록
            date: Date(),
            notes: "빠른 메모: \(trimmedMemo.prefix(100))",  // 처음 100자만 저장
            duration: nil,
            location: nil,
            relatedMeetingRecord: nil
        )

        // 3. 관계 상태 업데이트
        person.updateRelationshipState()

        do {
            try context.save()
            person.quickMemo = ""
            print("✅ 빠른 메모 저장 완료 - InteractionRecord 생성 및 관계 상태 업데이트됨")
        } catch {
            print("❌ 빠른 메모 저장 실패: \(error)")
        }
    }
}

// MARK: - Calendar Tab

struct MacPersonCalendarTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingAddEvent = false

    private var calendar: Calendar {
        Calendar.current
    }

    // 선택된 날짜의 이벤트들
    private var eventsForSelectedDate: [CalendarEvent] {
        let events = getCalendarEvents()
        return events.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        HStack(spacing: 0) {
            // 왼쪽: 캘린더
            VStack(spacing: 0) {
                // 월 네비게이션
                monthNavigationBar

                Divider()

                // 캘린더 그리드
                calendarGrid
                    .padding()
            }
            .frame(width: 400)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 오른쪽: 선택된 날짜의 일정
            VStack(spacing: 0) {
                // 선택된 날짜 헤더
                selectedDateHeader

                Divider()

                // 일정 목록
                if eventsForSelectedDate.isEmpty {
                    emptyEventsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(eventsForSelectedDate) { event in
                                CalendarEventRow(event: event)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var monthNavigationBar: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(currentMonth, format: .dateTime.year().month(.wide))
                .font(.headline)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }

            Button {
                currentMonth = Date()
                selectedDate = Date()
            } label: {
                Text("오늘")
            }
        }
        .padding()
    }

    @ViewBuilder
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // 요일 헤더
            weekdayHeader

            // 날짜 그리드
            let days = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        calendarDayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 60)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func calendarDayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let eventCount = getEventCount(for: date)

        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isCurrentMonth ? .primary : .secondary)

            if eventCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(eventCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                    if eventCount > 3 {
                        Text("+")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.2) : (isToday ? Color.green.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : (isToday ? Color.green : Color.clear), lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }

    @ViewBuilder
    private var selectedDateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate, format: .dateTime.year().month().day())
                    .font(.headline)
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(eventsForSelectedDate.count)개 일정")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingAddEvent = true
            } label: {
                Label("일정 추가", systemImage: "plus.circle.fill")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingAddEvent) {
            MacAddEventSheet(person: person, selectedDate: selectedDate) { _ in
                // 일정 추가 후 새로고침
            }
        }
    }

    @ViewBuilder
    private var emptyEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("이 날짜에 일정이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                showingAddEvent = true
            } label: {
                Label("일정 추가하기", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func changeMonth(by months: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: months, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        let monthEnd = monthInterval.end
        var currentDate = monthFirstWeek.start

        while currentDate < monthEnd {
            if calendar.isDate(currentDate, equalTo: monthInterval.start, toGranularity: .month) {
                days.append(currentDate)
            } else if currentDate < monthInterval.start {
                days.append(nil)
            } else {
                break
            }

            if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }

        // 마지막 주 채우기
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func getEventCount(for date: Date) -> Int {
        let events = getCalendarEvents()
        return events.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    private func getCalendarEvents() -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        // 1. 상호작용 기록
        for record in person.getAllInteractionRecordsSorted() {
            events.append(CalendarEvent(
                id: "interaction-\(record.id)",
                date: record.date,
                title: record.type.title,
                type: .interaction(record.type),
                details: record.notes
            ))
        }

        // 2. 액션 마감일 (reminderDate가 있는 경우)
        for personAction in person.actions where !personAction.isCompleted {
            if let reminderDate = personAction.reminderDate, let action = personAction.action {
                events.append(CalendarEvent(
                    id: "action-\(personAction.id)",
                    date: reminderDate,
                    title: action.title,
                    type: .actionDue(isCritical: action.type == .critical),
                    details: personAction.note
                ))
            }
        }

        // 3. 시스템 캘린더 일정
        let systemEvents = calendarManager.fetchUpcomingEvents(for: person, days: 365)
        for event in systemEvents {
            events.append(CalendarEvent(
                id: "system-\(event.eventIdentifier ?? UUID().uuidString)",
                date: event.startDate,
                title: event.title ?? "제목 없음",
                type: .systemCalendar,
                details: event.notes
            ))
        }

        return events
    }
}

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let type: CalendarEventType
    let details: String?
}

enum CalendarEventType {
    case interaction(InteractionType)
    case actionDue(isCritical: Bool)
    case systemCalendar
    case relationshipChange

    var color: Color {
        switch self {
        case .interaction(let type):
            return type.color
        case .actionDue(let isCritical):
            return isCritical ? .red : .orange
        case .systemCalendar:
            return .blue
        case .relationshipChange:
            return .purple
        }
    }

    var icon: String {
        switch self {
        case .interaction(let type):
            return type.systemImage
        case .actionDue:
            return "checklist"
        case .systemCalendar:
            return "calendar"
        case .relationshipChange:
            return "heart.fill"
        }
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // 시간
            VStack(alignment: .leading, spacing: 2) {
                Text(event.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, alignment: .leading)

            // 아이콘과 타입
            Image(systemName: event.type.icon)
                .foregroundStyle(event.type.color)
                .frame(width: 24)

            // 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let details = event.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(event.type.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(event.type.color.opacity(0.3), lineWidth: 1)
                )
        )
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

// MARK: - Mac Create Interaction Sheet

struct MacCreateInteractionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let interactionType: InteractionType
    let context: ModelContext

    @State private var date = Date()
    @State private var notes = ""
    @State private var location = ""
    @State private var selectedFiles: [URL] = []
    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("새 \(interactionType.title) 기록")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 폼 (스크롤 가능)
            ScrollView {
                Form {
                Section {
                    HStack {
                        Text(interactionType.emoji)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(interactionType.title)
                                .font(.headline)
                            Text("새로운 \(interactionType.title) 기록을 추가하세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("날짜 및 시간") {
                    DatePicker("날짜와 시간", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                }

                Section("장소") {
                    TextField("어디서 만났나요?", text: $location)
                }

                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section("첨부파일") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 드롭 영역
                        VStack(spacing: 8) {
                            if selectedFiles.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("파일을 여기로 드래그하거나 클릭하여 선택")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .foregroundStyle(.secondary.opacity(0.3))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectFiles()
                                }
                            } else {
                                ForEach(selectedFiles, id: \.self) { url in
                                    HStack {
                                        Image(systemName: iconForFile(url))
                                            .foregroundStyle(colorForFile(url))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(url.lastPathComponent)
                                                .font(.subheadline)
                                            if let fileSize = fileSize(for: url) {
                                                Text(fileSize)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Button {
                                            selectedFiles.removeAll { $0 == url }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }

                                Button {
                                    selectFiles()
                                } label: {
                                    Label("파일 추가", systemImage: "plus.circle.fill")
                                }
                            }
                        }
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            handleDrop(providers: providers)
                            return true
                        }
                    }
                }
                }
                .formStyle(.grouped)
            }

            Divider()

            // 저장 버튼
            HStack {
                Spacer()
                Button("저장") {
                    saveRecord()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func saveRecord() {
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        let finalLocation = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location

        let record = person.addInteractionRecord(
            type: interactionType,
            date: date,
            notes: finalNotes,
            duration: nil,
            location: finalLocation,
            relatedMeetingRecord: nil
        )

        // 첨부파일 추가
        for fileURL in selectedFiles {
            if let fileData = try? Data(contentsOf: fileURL) {
                let fileType = AttachmentFileType.from(fileName: fileURL.lastPathComponent)
                let attachment = AttachmentFile(
                    fileName: fileURL.lastPathComponent,
                    fileType: fileType,
                    fileData: fileData
                )
                context.insert(attachment)
                record.addAttachment(attachment)
            }
        }

        person.updateRelationshipState()

        do {
            try context.save()
            print("✅ 새 상호작용 기록 생성 (첨부파일 \(selectedFiles.count)개)")
            dismiss()
        } catch {
            print("❌ 상호작용 기록 생성 실패: \(error)")
        }
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "첨부할 파일을 선택하세요"

        panel.begin { response in
            if response == .OK {
                selectedFiles.append(contentsOf: panel.urls)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        // 이미 추가된 파일인지 확인
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            }
        }
        return true
    }

    private func iconForFile(_ url: URL) -> String {
        let fileType = AttachmentFileType.from(fileName: url.lastPathComponent)
        return fileType.icon
    }

    private func colorForFile(_ url: URL) -> Color {
        let fileType = AttachmentFileType.from(fileName: url.lastPathComponent)
        return fileType.color
    }

    private func fileSize(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

struct MacUpcomingEventRow: View {
    let event: EKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 날짜 및 시간
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.startDate, style: .date)
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 소요 시간
                if let endDate = event.endDate {
                    let duration = Int(endDate.timeIntervalSince(event.startDate) / 60)
                    Text("\(duration)분")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 제목
            if let title = event.title {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            // 메모
            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

struct MacMeetingRecordRow: View {
    let meeting: MeetingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.date, style: .date)
                    .font(.headline)
                Spacer()
                Text("\(meeting.duration)분")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(meeting.summary)
                .font(.body)

            if !meeting.transcribedText.isEmpty {
                Text(meeting.transcribedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}

// MARK: - Mentoring Session Compact Card

struct MacMentoringSessionCompactCard: View {
    let session: MentoringSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionDate, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !session.postMentoring.meaningfulSummary.isEmpty {
                    Text(session.postMentoring.meaningfulSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("\(session.preMentoring.overallLifeSatisfaction)")
                    .font(.callout)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.05))
        )
    }
}

// MARK: - Person Mentoring Sessions View

struct MacPersonMentoringSessionsView: View {
    let person: Person
    @ObservedObject var manager: MentoringManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSession = false
    @State private var selectedSession: MentoringSession?

    private var personSessions: [MentoringSession] {
        manager.sessions.filter { $0.personId == person.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(person.name)님의 멘토링 기록")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("총 \(personSessions.count)회의 세션")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingAddSession = true
                } label: {
                    Label("세션 추가", systemImage: "plus.circle.fill")
                }

                Button("닫기") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 세션 목록
            if personSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    Text("아직 멘토링 기록이 없습니다")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("\(person.name)님과의 멘토링 세션을 기록해보세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showingAddSession = true
                    } label: {
                        Label("첫 세션 기록하기", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(personSessions) { session in
                            MacMentoringSessionDetailCard(session: session)
                                .onTapGesture {
                                    selectedSession = session
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSession) {
            MacMentoringSessionEditView(
                session: MentoringSession(personId: person.id),
                manager: manager
            )
        }
        .sheet(item: $selectedSession) { session in
            MacMentoringSessionDetailView(session: session, manager: manager)
        }
    }
}

struct MacMentoringSessionDetailCard: View {
    let session: MentoringSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.sessionDate, style: .date)
                        .font(.headline)
                    Text(session.sessionDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(session.preMentoring.overallLifeSatisfaction)/10")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            if !session.postMentoring.meaningfulSummary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("한줄 요약")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.postMentoring.meaningfulSummary)
                        .font(.body)
                        .lineLimit(2)
                }
            }

            if !session.postMentoring.actionPlan.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("액션플랜")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.postMentoring.actionPlan)
                        .font(.callout)
                        .foregroundStyle(.purple)
                        .lineLimit(2)
                }
            }

            HStack {
                Label("업데이트: \(session.updatedAt, style: .date)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Analytics Tab

struct MacPersonAnalyticsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()

    // Debug mode
    @State private var isDebugMode = false

    private var meetingsByMonth: [(String, Int)] {
        let calendar = Calendar.current
        let meetings = person.meetingRecords

        var monthCounts: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"

        for meeting in meetings {
            let monthKey = dateFormatter.string(from: meeting.date)
            monthCounts[monthKey, default: 0] += 1
        }

        return monthCounts.sorted { $0.key > $1.key }.prefix(6).map { ($0.key, $0.value) }
    }

    private var conversationsByType: [(String, Int)] {
        let records = person.conversationRecords
        var typeCounts: [String: Int] = [:]

        for record in records {
            let typeName = record.type.title
            typeCounts[typeName, default: 0] += 1
        }

        return typeCounts.sorted { $0.value > $1.value }
    }

    private var actionCompletionRate: Double {
        let actions = person.actions
        guard !actions.isEmpty else { return 0 }
        let completed = actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(actions.count) * 100
    }

    private var personMentoringSessions: [MentoringSession] {
        mentoringManager.sessions.filter { $0.personId == person.id }
    }

    private var mentoringTrend: [(String, Int)] {
        let sessions = personMentoringSessions
        guard !sessions.isEmpty else { return [] }

        return sessions.enumerated().map { index, session in
            ("세션 \(index + 1)", session.preMentoring.overallLifeSatisfaction)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Debug Button (더블클릭으로 활성화)
            HStack {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "ladybug.fill")
                            .font(.title3)
                        Text(isDebugMode ? "Debug Mode ON" : "Debug Mode")
                            .font(.headline)
                    }
                    .foregroundStyle(isDebugMode ? .green : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDebugMode ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture(count: 2) {
                    isDebugMode.toggle()
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    if isDebugMode {
                        debugSection
                    }

                    // 만남 빈도
                    meetingFrequencySection

                    // 대화 유형 분포
                    conversationTypeSection

                    // 액션 완료율
                    actionCompletionSection

                    // 멘토링 추이
                    if !personMentoringSessions.isEmpty {
                        mentoringTrendSection
                    }

                    // 전체 통계
                    overallStatsSection
                }
                .padding()
            }
        }
    }

    // MARK: - Debug Section

    private var debugSection: some View {
        VStack(spacing: 12) {
            Text("🔧 Debug Tools")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    generateDummyMeetings()
                } label: {
                    Label("더미 미팅 생성", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    generateDummyConversations()
                } label: {
                    Label("더미 대화 생성", systemImage: "message.badge.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    generateDummyMentoringSessions()
                } label: {
                    Label("더미 멘토링 생성", systemImage: "person.2.badge.gearshape")
                }
                .buttonStyle(.borderedProminent)
            }

            Button(role: .destructive) {
                clearAllData()
            } label: {
                Label("모든 데이터 삭제", systemImage: "trash.fill")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                deletePerson()
            } label: {
                Label("사람 완전 삭제", systemImage: "person.fill.xmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Chart Sections

    private var meetingFrequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("만남 빈도 (최근 6개월)")
                .font(.headline)

            if meetingsByMonth.isEmpty {
                emptyChartView(message: "아직 미팅 기록이 없습니다")
            } else {
                VStack(spacing: 8) {
                    ForEach(meetingsByMonth, id: \.0) { month, count in
                        HStack {
                            Text(month)
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(meetingsByMonth.map(\.1).max() ?? 1))
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 20)

                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var conversationTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("대화 유형 분포")
                .font(.headline)

            if conversationsByType.isEmpty {
                emptyChartView(message: "아직 대화 기록이 없습니다")
            } else {
                VStack(spacing: 8) {
                    ForEach(conversationsByType, id: \.0) { type, count in
                        HStack {
                            Text(type)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)

                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(conversationsByType.map(\.1).max() ?? 1))
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 20)

                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var actionCompletionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("액션 완료율")
                .font(.headline)

            HStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 30)

                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * actionCompletionRate / 100, height: 30)
                    }
                }
                .frame(height: 30)
                .cornerRadius(8)

                Text("\(Int(actionCompletionRate))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var mentoringTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("멘토링 만족도 추이")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(mentoringTrend, id: \.0) { session, score in
                    HStack {
                        Text(session)
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)

                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.orange)
                                    .frame(width: geometry.size.width * CGFloat(score) / 10)
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: 20)

                        Text("\(score)/10")
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var overallStatsSection: some View {
        VStack(spacing: 16) {
            Text("전체 통계")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "총 미팅", value: "\(person.meetingRecords.count)회", icon: "calendar", color: .blue)
                StatCard(title: "총 대화", value: "\(person.conversationRecords.count)회", icon: "message", color: .green)
                StatCard(title: "액션 아이템", value: "\(person.actions.count)개", icon: "checklist", color: .purple)
                StatCard(title: "멘토링 세션", value: "\(personMentoringSessions.count)회", icon: "person.2", color: .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func emptyChartView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Dummy Data Generation

    private func generateDummyMeetings() {
        let meetingTypes: [MeetingType] = [.mentoring, .meal, .coffee, .general, .presentation, .oneOnOne]

        for i in 0..<10 {
            let meeting = MeetingRecord(
                date: Date().addingTimeInterval(-Double(i) * 7 * 24 * 3600), // 주마다 하나씩
                meetingType: meetingTypes.randomElement() ?? .general,
                summary: "더미 미팅 \(i + 1)",
                duration: Double.random(in: 1800...7200)
            )
            meeting.person = person
            context.insert(meeting)
        }

        try? context.save()
        print("✅ 10개의 더미 미팅 생성됨")
    }

    private func generateDummyConversations() {
        let conversationTypes: [ConversationType] = [.question, .concern, .promise, .update, .feedback, .achievement]
        let priorities: [ConversationPriority] = [.low, .normal, .high, .urgent]

        for i in 0..<15 {
            let record = person.addConversationRecord(
                type: conversationTypes.randomElement() ?? .question,
                content: "더미 대화 내용 \(i + 1): 테스트 데이터입니다.",
                priority: priorities.randomElement() ?? .normal,
                isImportant: Bool.random(),
                date: Date().addingTimeInterval(-Double(i) * 3 * 24 * 3600)
            )
            context.insert(record)
        }

        try? context.save()
        print("✅ 15개의 더미 대화 생성됨")
    }

    private func generateDummyMentoringSessions() {
        for i in 0..<5 {
            var session = MentoringSession(personId: person.id)
            session.sessionDate = Date().addingTimeInterval(-Double(i) * 14 * 24 * 3600)
            session.preMentoring.overallLifeSatisfaction = Int.random(in: 5...10)
            session.preMentoring.personalLifeSatisfaction = Int.random(in: 5...10)
            session.preMentoring.relationshipSatisfaction = Int.random(in: 5...10)
            session.preMentoring.academySatisfaction = Int.random(in: 5...10)
            session.postMentoring.meaningfulSummary = "더미 세션 \(i + 1): 테스트 요약"
            session.postMentoring.actionPlan = "다음 단계 계획"

            mentoringManager.addSession(session)
        }

        print("✅ 5개의 더미 멘토링 세션 생성됨")
    }

    private func clearAllData() {
        // 미팅 삭제
        for meeting in person.meetingRecords {
            context.delete(meeting)
        }

        // 대화 삭제
        for conversation in person.conversationRecords {
            context.delete(conversation)
        }

        // 멘토링 세션 삭제
        let sessionsToDelete = mentoringManager.sessions.filter { $0.personId == person.id }
        for session in sessionsToDelete {
            mentoringManager.deleteSession(session)
        }

        try? context.save()
        print("✅ 모든 데이터가 삭제되었습니다")
    }

    private func deletePerson() {
        let personName = person.name
        context.delete(person)

        do {
            try context.save()
            print("✅ \(personName) 완전 삭제됨")

            // 윈도우 닫기
            if let window = NSApplication.shared.keyWindow {
                window.close()
            }
        } catch {
            print("❌ 사람 삭제 실패: \(error)")
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
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

#Preview {
    MacPersonDetailView(person: Person(name: "홍길동", contact: "010-1234-5678"))
        .modelContainer(for: [Person.self])
}
