//
//  MacPersonDetailView.swift
//  mac
//
//  macOS용 Person 상세 화면
//

import SwiftUI
import SwiftData
import EventKit

struct MacPersonDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var selectedTab = 0
    @State private var showingImagePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            personHeader
                .padding()
                .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 탭 뷰
            TabView(selection: $selectedTab) {
                // 정보 탭
                MacPersonInfoTab(person: person)
                    .tabItem {
                        Label("정보", systemImage: "info.circle")
                    }
                    .tag(0)

                // 활동 탭
                MacPersonActionsTab(person: person)
                    .tabItem {
                        Label("활동", systemImage: "checklist")
                    }
                    .tag(1)

                // 기록 탭
                MacPersonRecordsTab(person: person)
                    .tabItem {
                        Label("기록", systemImage: "calendar")
                    }
                    .tag(2)

                // 분석 탭
                MacPersonAnalyticsTab(person: person)
                    .tabItem {
                        Label("분석", systemImage: "chart.bar.fill")
                    }
                    .tag(3)
            }
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

                // 관계 상태
                HStack(spacing: 12) {
                    Menu {
                        ForEach(RelationshipState.allCases, id: \.self) { state in
                            Button {
                                person.state = state
                            } label: {
                                HStack {
                                    Circle()
                                        .fill(state.color)
                                        .frame(width: 10, height: 10)
                                    Text(state.localizedName)
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(person.state.color)
                                .frame(width: 10, height: 10)
                            Text(person.state.localizedName)
                                .font(.callout)
                            Image(systemName: "chevron.down")
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(Color.gray.opacity(0.1))
                        )
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
            }

            Spacer()

            // 미완료 액션 개수
            VStack {
                let incompleteCount = person.actions.filter { !$0.isCompleted }.count
                Text("\(incompleteCount)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("미완료 액션")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Info Tab

struct MacPersonInfoTab: View {
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()
    @State private var showingMentoringSession = false

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
        }
        .sheet(isPresented: $showingMentoringSession) {
            MacPersonMentoringSessionsView(person: person, manager: mentoringManager)
                .frame(minWidth: 700, minHeight: 500)
        }
    }
}

// MARK: - Actions Tab (활동)

struct MacPersonActionsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()
    @State private var showingMentoringSession = false
    @State private var selectedPhase: ActionPhase = .surface
    @Query(sort: \RapportAction.order) private var allRapportActions: [RapportAction]

    private var actionsByPhase: [ActionPhase: [PersonAction]] {
        Dictionary(grouping: person.actions.filter { $0.isVisibleInDetail }) { action in
            action.action?.phase ?? .surface
        }
    }

    private var actionsForSelectedPhase: [PersonAction] {
        actionsByPhase[selectedPhase]?.sorted { ($0.action?.order ?? 999) < ($1.action?.order ?? 999) } ?? []
    }

    private var availableRapportActions: [RapportAction] {
        allRapportActions.filter { $0.phase == selectedPhase && $0.isActive }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                // Phase 선택기
                Picker("Phase", selection: $selectedPhase) {
                    ForEach(ActionPhase.allCases) { phase in
                        Text("\(phase.emoji) \(phase.rawValue)")
                            .tag(phase)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)

                Spacer()

                Button {
                    showingMentoringSession = true
                } label: {
                    Label("멘토링 기록", systemImage: "person.2.fill")
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Phase 설명
            HStack {
                Text(selectedPhase.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
    @Bindable var person: Person
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var mentoringManager = MentoringManager()

    @State private var showingAddEvent = false
    @State private var showingMentoringSession = false
    @State private var upcomingEvents: [EKEvent] = []

    private var sortedMeetings: [MeetingRecord] {
        person.meetingRecords.sorted { $0.date > $1.date }
    }

    private var personMentoringSessions: [MentoringSession] {
        mentoringManager.sessions.filter { $0.personId == person.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 일정 추가 버튼
            HStack {
                Text("일정 및 기록")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showingMentoringSession = true
                } label: {
                    Label("멘토링 기록", systemImage: "person.2.fill")
                }

                Button {
                    showingAddEvent = true
                } label: {
                    Label("일정 추가", systemImage: "plus.circle.fill")
                }
            }
            .padding(.horizontal)
            .padding(.top)

            Divider()
                .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 16) {
                    // 멘토링 세션 섹션
                    if !personMentoringSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("멘토링 세션")
                                    .font(.headline)
                                    .foregroundStyle(.purple)
                                Spacer()
                                Text("\(personMentoringSessions.count)회")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            ForEach(personMentoringSessions.prefix(3)) { session in
                                MacMentoringSessionCompactCard(session: session)
                            }

                            if personMentoringSessions.count > 3 {
                                Button {
                                    showingMentoringSession = true
                                } label: {
                                    HStack {
                                        Text("전체 보기 (\(personMentoringSessions.count)회)")
                                            .font(.caption)
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                    }
                                    .foregroundStyle(.purple)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)

                        Divider()
                            .padding(.vertical, 8)
                    }

                    // 다가오는 일정 섹션
                    if !upcomingEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("다가오는 일정")
                                .font(.headline)
                                .foregroundStyle(.blue)

                            ForEach(upcomingEvents, id: \.eventIdentifier) { event in
                                MacUpcomingEventRow(event: event)
                            }
                        }
                        .padding(.horizontal)

                        Divider()
                            .padding(.vertical, 8)
                    }

                    // 과거 미팅 기록 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("과거 기록")
                            .font(.headline)
                            .foregroundStyle(.secondary)

                        if sortedMeetings.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "calendar.badge.clock")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.secondary)
                                Text("아직 미팅 기록이 없습니다")
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                        } else {
                            ForEach(sortedMeetings) { meeting in
                                MacMeetingRecordRow(meeting: meeting)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom)
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            MacAddEventSheet(person: person) { _ in
                loadUpcomingEvents()
            }
        }
        .sheet(isPresented: $showingMentoringSession) {
            MacPersonMentoringSessionsView(person: person, manager: mentoringManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .onAppear {
            loadUpcomingEvents()
        }
    }

    private func loadUpcomingEvents() {
        upcomingEvents = calendarManager.fetchUpcomingEvents(for: person, days: 30)
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

#Preview {
    MacPersonDetailView(person: Person(name: "홍길동", contact: "010-1234-5678"))
        .modelContainer(for: [Person.self])
}
