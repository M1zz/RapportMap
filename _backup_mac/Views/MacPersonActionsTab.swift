//
//  MacPersonActionsTab.swift
//  mac
//
//  macOS용 Person 활동 탭
//

import SwiftUI
import SwiftData

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

// MARK: - Person Action Row

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
