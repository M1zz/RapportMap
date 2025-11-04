//
//  PersonActionChecklistView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import SwiftUI
import SwiftData
import UserNotifications

// MARK: - NotificationManager
class NotificationManager {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            return granted
        } catch {
            print("알림 권한 요청 실패: \(error)")
            return false
        }
    }
    
    func scheduleActionReminder(
        for personAction: PersonAction,
        at date: Date,
        title: String,
        body: String
    ) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.badge = 1
        
        // 메타데이터 추가
        if let personId = personAction.person?.persistentModelID.hashValue,
           let actionId = personAction.action?.persistentModelID.hashValue {
            content.userInfo = [
                "personId": personId,
                "actionId": actionId,
                "type": "actionReminder"
            ]
        }
        
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
        
        let identifier = "reminder_\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            print("알림 스케줄링 실패: \(error)")
            return false
        }
    }
    
    func cancelAllActionReminders() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
}

// MARK: - Keyboard Dismiss Helper
extension View {
    /// Dismiss keyboard by ending editing across the app window
    func endEditing() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
}

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
            .contentShape(Rectangle())
            .onTapGesture {
                endEditing()
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
            ZStack {
                // Transparent tap area to dismiss keyboard
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        endEditing()
                    }

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
    @State private var showingReminderSetting = false
    @FocusState private var isResultFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 체크박스
                Button {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if personAction.isCompleted {
                            // 완료 취소 허용 (모든 액션 타입)
                            personAction.markIncomplete()
                            try? context.save()
                        } else {
                            // 완료 처리하면서 결과 입력 화면 띄우기
                            showingResultInput = true
                        }
                    }
                } label: {
                    Image(systemName: personAction.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(
                            personAction.isCompleted 
                                ? (personAction.action?.type == .critical ? .orange : .green)
                                : .gray
                        )
                }
                .buttonStyle(.plain)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if let action = personAction.action {
                            HStack(spacing: 6) {
                                // Critical 액션 완료 시 특별 표시
                                if action.type == .critical && personAction.isCompleted {
                                    Image(systemName: "exclamationmark.shield.fill")
                                        .font(.caption)
                                        .foregroundStyle(.green) // 초록색으로 변경 (완료됨을 나타냄)
                                }
                                
                                Text(action.title)
                                    .font(.headline)
                                    .foregroundStyle(
                                        personAction.isCompleted 
                                            ? (action.type == .critical ? .secondary : .secondary) // Critical도 완료 시 회색
                                            : .primary
                                    )
                                    .strikethrough(
                                        personAction.isCompleted, // 모든 액션에 취소선 적용
                                        color: action.type == .critical ? .orange : .red // Critical은 오렌지, 일반은 빨간 취소선
                                    )
                                    .animation(.easeInOut(duration: 0.3), value: personAction.isCompleted)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                // 리마인더 버튼
                                Button {
                                    showingReminderSetting = true
                                } label: {
                                    Image(systemName: "bell")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                
                                if action.type == .critical {
                                    HStack(spacing: 2) {
                                        Text("⚠️")
                                            .font(.caption)
                                        Text("중요")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                            .fontWeight(.medium)
                                    }
                                }
                            }
                        }
                    }
                    
                    if let action = personAction.action, !action.actionDescription.isEmpty {
                        Text(action.actionDescription)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    
                    // Critical 액션 완료 시 특별 안내
                    if let action = personAction.action, action.type == .critical && personAction.isCompleted {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(.green)
                            Text("중요한 액션이 완료되었습니다. 체크박스를 다시 누르면 완료를 취소할 수 있어요.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.green.opacity(0.1))
                        )
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
                                .fill(Color.blue.gradient) // 모든 액션 결과값을 파란색으로 통일
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
        .sheet(isPresented: $showingReminderSetting) {
            ReminderSettingSheet(personAction: personAction)
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
            ZStack {
                // Transparent tap area to dismiss keyboard
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isInputFocused = false
                        endEditing()
                    }
                
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
            }
        }
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
    
    private func completeAction() {
        personAction.context = resultText
        personAction.markCompleted()
        try? context.save()
        dismiss()
    }
}

// MARK: - ReminderSettingSheet (새로 추가!)
struct ReminderSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var personAction: PersonAction
    
    @State private var selectedDate = Date()
    @State private var reminderTitle = ""
    @State private var reminderBody = ""
    @State private var isSettingReminder = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("리마인더 시간") {
                    DatePicker("알림 시간", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("알림 내용") {
                    TextField("제목", text: $reminderTitle)
                        .autocorrectionDisabled()
                    
                    TextField("내용 (선택)", text: $reminderBody, axis: .vertical)
                        .lineLimit(2...4)
                }
                
                Section("미리보기") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(reminderTitle.isEmpty ? (personAction.action?.title ?? "액션 리마인더") : reminderTitle)
                            .font(.headline)
                        
                        let bodyText = reminderBody.isEmpty ? "\(personAction.person?.preferredName ?? personAction.person?.name ?? "")님과 관련된 액션을 확인해보세요" : reminderBody
                        Text(bodyText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(selectedDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                
                Section {
                    Button {
                        Task {
                            await setupReminder()
                        }
                    } label: {
                        HStack {
                            if isSettingReminder {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding(.trailing, 4)
                            }
                            Text("리마인더 설정")
                        }
                    }
                    .disabled(selectedDate <= Date() || isSettingReminder)
                } footer: {
                    if selectedDate <= Date() {
                        Text("미래 시간을 선택해주세요")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("리마인더 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { 
                        dismiss() 
                    }
                    .disabled(isSettingReminder)
                }
            }
            .onAppear {
                setupInitialValues()
            }
        }
    }
    
    private func setupInitialValues() {
        if let action = personAction.action {
            reminderTitle = "\(action.title) 리마인더"
            reminderBody = "\(personAction.person?.preferredName ?? personAction.person?.name ?? "")님과 관련된 액션을 확인해보세요"
        }
        selectedDate = Date().addingTimeInterval(3600) // 1시간 후로 기본 설정
    }
    
    private func setupReminder() async {
        isSettingReminder = true
        
        // 권한 요청
        let hasPermission = await NotificationManager.shared.requestPermission()
        
        guard hasPermission else {
            isSettingReminder = false
            // TODO: 설정 앱으로 이동하도록 안내하는 얼럿 표시
            return
        }
        
        let title = reminderTitle.isEmpty ? (personAction.action?.title ?? "액션 리마인더") : reminderTitle
        let body = reminderBody.isEmpty ? "\(personAction.person?.preferredName ?? personAction.person?.name ?? "")님과 관련된 액션을 확인해보세요" : reminderBody
        
        let success = await NotificationManager.shared.scheduleActionReminder(
            for: personAction,
            at: selectedDate,
            title: title,
            body: body
        )
        
        isSettingReminder = false
        
        if success {
            // 성공 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            dismiss()
        }
        // TODO: 실패 시 에러 얼럿 표시
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
