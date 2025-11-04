//
//  PersonActionChecklistView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import SwiftUI
import SwiftData

struct PersonActionChecklistView: View {
    @Environment(\.modelContext) private var context
    let person: Person
    
    @State private var selectedPhase: ActionPhase
    @State private var showingAddAction = false
    
    init(person: Person) {
        self.person = person
        _selectedPhase = State(initialValue: person.currentPhase)
    }
    
    // 이 사람의 액션들을 Phase별로 필터링
    private var actionsForPhase: [PersonAction] {
        person.actions
            .filter { $0.action?.phase == selectedPhase }
            .sorted { ($0.action?.order ?? 0) < ($1.action?.order ?? 0) }
    }
    
    // Phase별 완성도 계산
    private func completionRate(for phase: ActionPhase) -> Double {
        let phaseActions = person.actions.filter { $0.action?.phase == phase }
        guard !phaseActions.isEmpty else { return 0 }
        let completed = phaseActions.filter { $0.isCompleted }.count
        return Double(completed) / Double(phaseActions.count)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Phase 선택기
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ActionPhase.allCases) { phase in
                        PhaseButton(
                            phase: phase,
                            isSelected: selectedPhase == phase,
                            completionRate: completionRate(for: phase)
                        ) {
                            selectedPhase = phase
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
            
            Divider()
            
            // 액션 리스트
            List {
                Section {
                    ForEach(actionsForPhase) { personAction in
                        PersonActionRow(personAction: personAction)
                    }
                    .onDelete(perform: deleteActions)
                } header: {
                    Text(selectedPhase.description)
                } footer: {
                    Text("왼쪽으로 스와이프하면 액션을 삭제할 수 있어요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("\(person.preferredName.isEmpty ? person.name : person.preferredName)의 액션")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    showingAddAction = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    ForEach(ActionPhase.allCases) { phase in
                        Button {
                            person.currentPhase = phase
                            try? context.save()
                        } label: {
                            HStack {
                                Text("\(phase.emoji) \(phase.rawValue)")
                                if person.currentPhase == phase {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    Label("Phase", systemImage: "arrow.up.arrow.down")
                }
            }
        }
        .sheet(isPresented: $showingAddAction) {
            AddCustomActionSheet(person: person, phase: selectedPhase)
        }
        .onAppear {
            // 액션이 없으면 생성
            if person.actions.isEmpty {
                DataSeeder.createPersonActionsForNewPerson(person: person, context: context)
            }
        }
    }
    
    private func deleteActions(at offsets: IndexSet) {
        for index in offsets {
            let personAction = actionsForPhase[index]
            context.delete(personAction)
        }
        try? context.save()
    }
}

// MARK: - AddCustomActionSheet (새로 추가!)
struct AddCustomActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let person: Person
    let phase: ActionPhase
    
    @State private var title = ""
    @State private var description = ""
    @State private var placeholder = ""
    @State private var type: ActionType = .tracking
    
    var body: some View {
        NavigationStack {
            Form {
                Section("액션 정보") {
                    TextField("제목", text: $title)
                        .autocorrectionDisabled()
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("입력 예시 (선택)", text: $placeholder)
                        .autocorrectionDisabled()
                }
                
                Section("설정") {
                    Picker("Phase", selection: .constant(phase)) {
                        Text("\(phase.emoji) \(phase.rawValue)")
                    }
                    .disabled(true)
                    
                    Picker("타입", selection: $type) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.emoji)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("커스텀 액션 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addCustomAction()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addCustomAction() {
        // 1. RapportAction 생성 (전역)
        let maxOrder = (try? context.fetch(FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.phase == phase }
        )))?.map { $0.order }.max() ?? 0
        
        let newAction = RapportAction(
            title: title,
            actionDescription: description,
            phase: phase,
            type: type,
            order: maxOrder + 1,
            isDefault: false,
            isActive: true,
            placeholder: placeholder.isEmpty ? "예: 입력하세요" : placeholder
        )
        context.insert(newAction)
        
        // 2. PersonAction 생성 (이 사람용)
        let personAction = PersonAction(
            person: person,
            action: newAction
        )
        context.insert(personAction)
        
        try? context.save()
    }
}

// MARK: - PhaseButton
struct PhaseButton: View {
    let phase: ActionPhase
    let isSelected: Bool
    let completionRate: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(phase.emoji)
                    .font(.title2)
                
                Text(phase.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                // 완성도 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(completionRate >= 1.0 ? Color.green : Color.blue)
                            .frame(width: geometry.size.width * completionRate)
                    }
                }
                .frame(height: 3)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.blue.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PersonActionRow (대폭 개선!)
struct PersonActionRow: View {
    @Bindable var personAction: PersonAction
    @Environment(\.modelContext) private var context
    @State private var showingResultInput = false
    @FocusState private var isResultFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 체크박스
                Button {
                    if personAction.isCompleted {
                        // 완료 취소
                        personAction.markIncomplete()
                        try? context.save()
                    } else {
                        // 완료 처리하면서 결과 입력 화면 띄우기
                        showingResultInput = true
                    }
                } label: {
                    Image(systemName: personAction.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(personAction.isCompleted ? .green : .gray)
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let action = personAction.action {
                            Text(action.title)
                                .font(.headline)
                                .foregroundStyle(personAction.isCompleted ? .secondary : .primary)
                                .strikethrough(personAction.isCompleted)
                            
                            Spacer()
                            
                            if action.type == .critical {
                                Text("⚠️")
                                    .font(.caption)
                            }
                        }
                    }
                    
                    if let action = personAction.action, !action.actionDescription.isEmpty {
                        Text(action.actionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // 결과값 표시 (중요!)
                    if !personAction.context.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "note.text")
                                .font(.caption2)
                            Text(personAction.context)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.gradient)
                        )
                    }
                    
                    // 마지막 실행일
                    if let lastDate = personAction.lastActionDate {
                        Text("마지막: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $showingResultInput) {
            ActionResultInputSheet(personAction: personAction)
        }
    }
}

// MARK: - ActionResultInputSheet (새로 추가!)
struct ActionResultInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var personAction: PersonAction
    
    @State private var resultText: String = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 액션 제목
                if let action = personAction.action {
                    VStack(spacing: 8) {
                        Text(action.title)
                            .font(.title2)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        if !action.actionDescription.isEmpty {
                            Text(action.actionDescription)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.top, 30)
                }
                
                Spacer()
                
                // 결과 입력 섹션
                VStack(alignment: .leading, spacing: 12) {
                    Label("무엇을 알아냈나요?", systemImage: "lightbulb.fill")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    
                    TextField(personAction.action?.placeholder ?? "예: 입력하세요", text: $resultText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        .focused($isInputFocused)
                        .padding(.horizontal, 4)
                    
                    Text("이 정보는 나중에 이 사람을 만나기 전에 다시 확인할 수 있어요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(.systemGray6))
                )
                
                Spacer()
                
                // 버튼들
                VStack(spacing: 12) {
                    // 완료 버튼
                    Button {
                        completeAction()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("완료")
                        }
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.gradient)
                        .cornerRadius(12)
                    }
                    
                    // 건너뛰기 버튼
                    Button {
                        dismiss()
                    } label: {
                        Text("나중에 입력하기")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                resultText = personAction.context
                // 키보드 자동으로 올리기
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isInputFocused = true
                }
            }
        }
    }
    
    private func completeAction() {
        personAction.context = resultText
        personAction.markCompleted()
        try? context.save()
        dismiss()
    }
}

// MARK: - PersonActionDetailSheet (기존 유지, 추가 편집용)
struct PersonActionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var personAction: PersonAction
    
    var body: some View {
        NavigationStack {
            Form {
                if let action = personAction.action {
                    Section("액션 정보") {
                        LabeledContent("제목", value: action.title)
                        if !action.actionDescription.isEmpty {
                            LabeledContent("설명") {
                                Text(action.actionDescription)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        LabeledContent("Phase", value: "\(action.phase.emoji) \(action.phase.rawValue)")
                        LabeledContent("타입", value: "\(action.type.emoji) \(action.type.rawValue)")
                    }
                }
                
                Section("실행 기록") {
                    Toggle("완료", isOn: $personAction.isCompleted)
                    
                    if let completedDate = personAction.completedDate {
                        LabeledContent("완료일") {
                            Text(completedDate.formatted(date: .long, time: .shortened))
                        }
                    }
                    
                    if let lastDate = personAction.lastActionDate {
                        LabeledContent("마지막 실행") {
                            Text(lastDate.formatted(date: .long, time: .shortened))
                        }
                    }
                    
                    if let days = personAction.daysSinceLastAction {
                        LabeledContent("경과", value: "\(days)일 전")
                    }
                }
                
                Section("결과 & 메모") {
                    TextField("결과 (예: 커피 안 마심)", text: $personAction.context, axis: .vertical)
                        .lineLimit(2...4)
                    
                    TextField("추가 메모", text: $personAction.note, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Button("지금 완료 처리") {
                        personAction.markCompleted()
                        try? context.save()
                        dismiss()
                    }
                    .disabled(personAction.isCompleted)
                }
            }
            .navigationTitle("액션 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, RapportAction.self, PersonAction.self, configurations: config)
    
    let person = Person(name: "김철수")
    container.mainContext.insert(person)
    
    return NavigationStack {
        PersonActionChecklistView(person: person)
            .modelContainer(container)
    }
}
