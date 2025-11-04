//
//  PeopleListView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/2/25.
//

import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @State private var showingAdd = false
    
    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    EmptyPeopleView()
                } else {
                    List {
                        ForEach(people) { person in
                            NavigationLink(destination: PersonDetailView(person: person)) {
                                PersonCard(person: person)
                            }
                        }
                        .onDelete(perform: delete)
                    }
                }
            }
            .navigationTitle("관계 지도")
            .toolbar {
                // Use navigationBarLeading/trailing for broad iOS compatibility
                #if DEBUG
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("샘플") {
                        addSampleData()
                    }
                }
                #endif
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ActionManagementView()) {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPersonSheet { name, contact in
                    let new = Person(name: name, contact: contact)
                    context.insert(new)
                    
                    // 새 Person에 대한 액션 인스턴스들 생성
                    DataSeeder.createPersonActionsForNewPerson(person: new, context: context)
                }
            }
            .onAppear {
                // 앱 최초 실행 시 기본 액션 30개 생성
                DataSeeder.seedDefaultActionsIfNeeded(context: context)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(people[index]) }
    }

    private func addSampleData() {
        let now = Date()
        let day: TimeInterval = 60 * 60 * 24

        let namePool = ["가비", "도딘", "라온", "민수", "지연", "하린", "준호", "서윤", "현우", "다연", "유나", "세진"]
        let questionPool = [
            "요즘 프로젝트는 어떻게 진행되고 있어?",
            "최근에 읽은 책 있어?",
            "주말에 시간 돼?",
            "요새 컨디션은 어때?",
            "다음에 같이 밥 먹을래?",
            "새로운 취미 시작했어?",
            "요즘 관심 있는 주제가 뭐야?"
        ]

        func randomPhone() -> String {
            let mid = Int.random(in: 1000...9999)
            let tail = Int.random(in: 1000...9999)
            return "010-\(mid)-\(tail)"
        }

        func randomEmail(for name: String) -> String {
            let id = UUID().uuidString.prefix(6).lowercased()
            return "\(name.lowercased())\(id)@example.com"
        }

        func randomPastDate(maxDays: Int) -> Date? {
            // 30% 확률로 nil 반환해서 비어있는 케이스도 만들기
            if Bool.random() && Int.random(in: 0...9) < 3 { return nil }
            let offset = TimeInterval(Int.random(in: 1...maxDays)) * day
            return now.addingTimeInterval(-offset)
        }

        func randomQuestion() -> String? {
            // 40% 확률로 질문 없음
            if Int.random(in: 0...9) < 4 { return nil }
            return questionPool.randomElement()!
        }

        let count = 2 // 터치당 2명만 생성

        for _ in 0..<count {
            let name = namePool.randomElement()!
            let contact: String = Bool.random() ? randomPhone() : randomEmail(for: name)
            let state = RelationshipState.allCases.randomElement()!
            let lastMentoring = randomPastDate(maxDays: 60)
            let lastMeal = randomPastDate(maxDays: 90)
            let lastContact = randomPastDate(maxDays: 120)
            let lastQuestion = randomQuestion()
            let unansweredCount = Int.random(in: 0...5)
            // 소홀 여부는 마지막 접촉일이 오래됐거나 상태가 distant일 때 높게
            let neglectedBias = (state == .distant ? 2 : 0) + ((lastContact == nil || (lastContact! < now.addingTimeInterval(-45 * day))) ? 2 : 0)
            let isNeglected = Int.random(in: 0...4) < neglectedBias

            let p = Person(
                id: UUID(),
                name: name,
                contact: contact,
                state: state,
                lastMentoring: lastMentoring,
                lastMeal: lastMeal,
                lastQuestion: lastQuestion,
                unansweredCount: unansweredCount,
                lastContact: lastContact,
                isNeglected: isNeglected
            )
            context.insert(p)
        }

        try? context.save()
    }
}

// MARK: - AddPersonSheet
struct AddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var contact = ""
    var onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $name)
                    TextField("연락처 (선택)", text: $contact)
                }
            }
            .navigationTitle("새로운 사람 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        onAdd(name, contact)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct PersonCard: View {
    let person: Person

    private var color: Color {
        switch person.state {
        case .distant: return .blue
        case .warming: return .orange
        case .close: return .pink
        }
    }
    private var label: String {
        switch person.state {
        case .distant: return "멀어짐"
        case .warming: return "따뜻해지는 중"
        case .close: return "끈끈함"
        }
    }
    
    private var completionRate: Double {
        guard !person.actions.isEmpty else { return 0 }
        let completed = person.actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(person.actions.count)
    }
    
    // 긴급 크리티컬 액션 (오늘이거나 지난 것)
    private var urgentCriticalActions: [PersonAction] {
        let today = Calendar.current.startOfDay(for: Date())
        return person.actions.filter { action in
            guard !action.isCompleted,
                  action.action?.type == .critical,
                  let reminderDate = action.reminderDate else {
                return false
            }
            return reminderDate <= today
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(person.name)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(label)
                        .foregroundStyle(color)
                }
            }
            
            // 긴급 알림 (최우선)
            if !urgentCriticalActions.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                    Text("긴급 \(urgentCriticalActions.count)개")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.red)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.1)))
            }
            
            // Phase & 완성도
            HStack(spacing: 8) {
                Chip(text: "\(person.currentPhase.emoji) \(person.currentPhase.rawValue)")
                    .foregroundStyle(.blue)
                
                if !person.actions.isEmpty {
                    Chip(text: "액션 \(Int(completionRate * 100))%")
                        .foregroundStyle(completionRate >= 0.5 ? .green : .orange)
                }
            }

            HStack(spacing: 8) {
                if let m = person.lastMentoring {
                    Chip(text: "🧑‍🏫 \(relative(m))")
                }
                if let meal = person.lastMeal {
                    Chip(text: "🍱 \(relative(meal))")
                }
                if person.unansweredCount > 0 {
                    Chip(text: "미해결 \(person.unansweredCount)")
                        .foregroundStyle(.orange)
                }
            }

            if let q = person.lastQuestion, !q.isEmpty {
                Text("\"\(q)\"")
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }

            HStack {
                if let c = person.lastContact {
                    Text("마지막 접촉: \(relative(c))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if person.isNeglected {
                    Chip(text: "다시 연결하기")
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }
}

struct Chip: View {
    let text: String
    var body: some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.thinMaterial))
    }
}

private func relative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: .now)
}

/*
struct PersonHintRow: View {
    let hint: RelationshipHint

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(hint.person.name)
                Spacer()
                Text(hint.statusLabel)
                    .foregroundStyle(hint.color)
            }

            if let kind = hint.lastInteractionKind, let date = hint.lastInteractionDate {
                Text("마지막 \(kind.rawValue): \(date.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.secondary)
            }

            if hint.unresolvedCount > 0 {
                Text("해결되지 않은 대화 \(hint.unresolvedCount)건")
                    .foregroundStyle(.orange)
            }

            if let next = hint.nextRecommendedContact {
                Text("다음 연락 추천일: \(next.formatted(date: .abbreviated, time: .omitted))")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 12)
    }
}
*/

struct PersonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    @State private var showingVoiceRecorder = false

    @Bindable var person: Person

    init(person: Person) {
        self._person = Bindable(person)
    }
    
    var body: some View {
        Form {
            // 빠른 액션 버튼들
            Section {
                Button {
                    showingVoiceRecorder = true
                } label: {
                    HStack {
                        Image(systemName: "waveform.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("오늘의 만남 기록하기")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            Text("음성으로 빠르게 기록")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                }
            }
            
            // 라포 액션 체크리스트
            Section {
                NavigationLink(destination: PersonActionChecklistView(person: person)) {
                    HStack {
                        Image(systemName: "checklist")
                            .foregroundStyle(.blue)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("라포 액션 체크리스트")
                                .font(.headline)
                            Text("\(person.currentPhase.emoji) \(person.currentPhase.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        
                        // 완성도 표시
                        if let completionRate = calculateCompletionRate() {
                            Text("\(Int(completionRate * 100))%")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
                    }
                }
            }
            
            // 크리티컬 액션 리마인더
            if !getCriticalActions().isEmpty {
                Section("⚠️ 놓치면 안되는 것들") {
                    ForEach(getCriticalActions(), id: \.id) { personAction in
                        CriticalActionReminderRow(personAction: personAction)
                    }
                }
            }
            
            // 알게 된 정보 (트래킹 액션)
            if !getCompletedTrackingActions().isEmpty {
                Section("📝 알게 된 정보") {
                    ForEach(getCompletedTrackingActions(), id: \.id) { personAction in
                        if let action = personAction.action, !personAction.context.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(action.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                
                                Text(personAction.context)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            
            // 만남 기록
            if !person.meetingRecords.isEmpty {
                Section("💬 만남 기록") {
                    ForEach(person.meetingRecords.sorted(by: { $0.date > $1.date }).prefix(5), id: \.id) { record in
                        NavigationLink(destination: MeetingRecordDetailView(record: record)) {
                            HStack {
                                Text(record.meetingType.emoji)
                                    .font(.title3)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.meetingType.rawValue)
                                        .font(.headline)
                                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    if !record.transcribedText.isEmpty {
                                        Text(record.transcribedText)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                    
                    if person.meetingRecords.count > 5 {
                        NavigationLink("모든 기록 보기 (\(person.meetingRecords.count)개)") {
                            AllMeetingRecordsView(person: person)
                        }
                    }
                }
            }
            
            Section(header: Text("기본 정보")) {
                if isEditing {
                    TextField("이름", text: $person.name)
                    TextField("연락처", text: $person.contact)
                } else {
                    Text("이름: \(person.name)")
                    if !person.contact.isEmpty {
                        Text("연락처: \(person.contact)")
                    }
                }
            }
            
            Section(header: Text("상태")) {
                HStack {
                    Text("관계 상태:")
                    Spacer()
                    if isEditing {
                        Picker("관계 상태", selection: $person.state) {
                            ForEach(RelationshipState.allCases, id: \.self) { state in
                                Text(label(for: state)).tag(state)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Text(stateLabel)
                            .foregroundColor(stateColor)
                    }
                }
            }
            
            Section(header: Text("최근 상호작용")) {
                // Mentoring
                DateEditorRow(title: "마지막 멘토링", date: $person.lastMentoring, isEditing: isEditing)
                Button {
                    person.lastMentoring = Date()
                    try? context.save()
                } label: {
                    Label("멘토링 지금 기록하기", systemImage: "clock.badge.checkmark")
                }

                // Meal
                DateEditorRow(title: "마지막 식사", date: $person.lastMeal, isEditing: isEditing)
                Button {
                    person.lastMeal = Date()
                    try? context.save()
                } label: {
                    Label("식사 지금 기록하기", systemImage: "clock.badge.checkmark")
                }

                // Contact
                DateEditorRow(title: "마지막 접촉", date: $person.lastContact, isEditing: isEditing)
                Button {
                    person.lastContact = Date()
                    try? context.save()
                } label: {
                    Label("접촉 지금 기록하기", systemImage: "bubble.left")
                }

                if isEditing {
                    TextField("마지막 질문", text: Binding(
                        get: { person.lastQuestion ?? "" },
                        set: { person.lastQuestion = $0.isEmpty ? nil : $0 }
                    ))
                } else if let lastQuestion = person.lastQuestion, !lastQuestion.isEmpty {
                    Text("마지막 질문: \(lastQuestion)")
                }
            }
            
            Section("대화/상태") {
                if isEditing {
                    Stepper(value: $person.unansweredCount, in: 0...100) {
                        Text("미해결 대화: \(person.unansweredCount)")
                    }
                    Toggle("관계가 소홀함", isOn: $person.isNeglected)
                } else {
                    if person.unansweredCount > 0 {
                        Text("미해결 대화: \(person.unansweredCount)")
                            .foregroundColor(.orange)
                    }
                    if person.isNeglected {
                        Text("이 사람과의 관계가 소홀해졌습니다. 다시 연결하세요.")
                            .foregroundColor(.blue)
                    }
                }
            }

            if isEditing {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("이 사람 삭제")
                    }
                }
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "완료" : "편집") {
                    isEditing.toggle()
                    try? context.save()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        person.lastMentoring = Date()
                        try? context.save()
                    } label: {
                        Label("멘토링 지금 기록", systemImage: "person.badge.clock")
                    }
                    Button {
                        person.lastMeal = Date()
                        try? context.save()
                    } label: {
                        Label("식사 지금 기록", systemImage: "fork.knife.circle")
                    }
                    Button {
                        person.lastContact = Date()
                        try? context.save()
                    } label: {
                        Label("접촉 지금 기록", systemImage: "bubble.left")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("빠른 액션")
            }
        }
        .confirmationDialog("정말 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                context.delete(person)
                try? context.save()
                dismiss()
            }
            Button("취소", role: .cancel) { }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView(person: person)
        }
    }
    
    private var stateColor: Color {
        switch person.state {
        case .distant: return .blue
        case .warming: return .orange
        case .close: return .pink
        }
    }
    
    private var stateLabel: String { label(for: person.state) }

    private func label(for state: RelationshipState) -> String {
        switch state {
        case .distant: return "멀어짐"
        case .warming: return "따뜻해지는 중"
        case .close: return "끈끈함"
        }
    }
    
    private func calculateCompletionRate() -> Double? {
        guard !person.actions.isEmpty else { return nil }
        let completed = person.actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(person.actions.count)
    }
    
    private func getCompletedTrackingActions() -> [PersonAction] {
        person.actions
            .filter { 
                $0.isCompleted && 
                !$0.context.isEmpty && 
                $0.action?.type == .tracking 
            }
            .sorted { ($0.action?.order ?? 0) < ($1.action?.order ?? 0) }
    }
    
    private func getCriticalActions() -> [PersonAction] {
        person.actions
            .filter { 
                !$0.isCompleted && // 미완료만
                $0.action?.type == .critical 
            }
            .sorted { ($0.action?.order ?? 0) < ($1.action?.order ?? 0) }
    }
}

// MARK: - DateEditorRow
private struct DateEditorRow: View {
    let title: String
    @Binding var date: Date?
    let isEditing: Bool

    var body: some View {
        if isEditing {
            Toggle(isOn: Binding(
                get: { date != nil },
                set: { newValue in
                    if newValue {
                        if date == nil { date = Date() }
                    } else {
                        date = nil
                    }
                }
            )) {
                Text(title)
            }
            if date != nil {
                DatePicker("", selection: Binding(get: { date ?? Date() }, set: { date = $0 }), displayedComponents: [.date])
                    .datePickerStyle(.compact)
            }
        } else {
            if let d = date {
                Text("\(title): \(d, formatter: dateFormatter)")
            }
        }
    }
}

private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter
}

// MARK: - CriticalActionReminderRow
struct CriticalActionReminderRow: View {
    @Bindable var personAction: PersonAction
    @Environment(\.modelContext) private var context
    @State private var showingReminderPicker = false
    
    // 리마인더 상태 체크
    private var reminderStatus: ReminderStatus {
        guard let reminderDate = personAction.reminderDate else {
            return .notSet
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let reminder = calendar.startOfDay(for: reminderDate)
        
        let days = calendar.dateComponents([.day], from: today, to: reminder).day ?? 0
        
        if days < 0 {
            return .overdue(days: abs(days))
        } else if days == 0 {
            return .today
        } else if days <= 3 {
            return .soon(days: days)
        } else {
            return .future
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let action = personAction.action {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(action.title)
                                .font(.headline)
                            
                            // 긴급도 뱃지
                            switch reminderStatus {
                            case .overdue(let days):
                                Text("\(days)일 지남")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .foregroundStyle(.white)
                            case .today:
                                Text("오늘!")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.red))
                                    .foregroundStyle(.white)
                            case .soon(let days):
                                Text("\(days)일 후")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.orange))
                                    .foregroundStyle(.white)
                            case .future, .notSet:
                                EmptyView()
                            }
                        }
                        
                        if !action.actionDescription.isEmpty {
                            Text(action.actionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 완료 체크박스
                Button {
                    personAction.isCompleted.toggle()
                    if personAction.isCompleted {
                        personAction.markCompleted()
                    }
                    try? context.save()
                } label: {
                    Image(systemName: personAction.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(personAction.isCompleted ? .green : .orange)
                }
            }
            
            // 리마인더 설정
            HStack {
                Button {
                    showingReminderPicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: personAction.reminderDate != nil ? "bell.fill" : "bell")
                            .font(.caption)
                        
                        if let reminderDate = personAction.reminderDate {
                            Text(reminderDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                        } else {
                            Text("리마인더 설정")
                                .font(.caption)
                        }
                    }
                    .foregroundStyle(reminderStatus == .today || {
                        if case .overdue = reminderStatus { return true } else { return false }
                    }() ? Color.red : ( {
                        if case .soon = reminderStatus { return true } else { return false }
                    }() ? Color.orange : Color.blue))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill({ () -> Color in
                            if reminderStatus == .today { return Color.red.opacity(0.1) }
                            if case .overdue = reminderStatus { return Color.red.opacity(0.1) }
                            if case .soon = reminderStatus { return Color.orange.opacity(0.1) }
                            return Color.blue.opacity(0.1)
                        }())
                    )
                }
                
                if personAction.reminderDate != nil {
                    Button {
                        personAction.reminderDate = nil
                        personAction.isReminderActive = false
                        try? context.save()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingReminderPicker) {
            ReminderPickerSheet(personAction: personAction)
        }
    }
}

// MARK: - ReminderStatus
enum ReminderStatus: Equatable {
    case notSet
    case overdue(days: Int)
    case today
    case soon(days: Int)
    case future
}

// MARK: - ReminderPickerSheet
struct ReminderPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var personAction: PersonAction
    
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationStack {
            Form {
                Section("리마인더 날짜") {
                    DatePicker("날짜", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                }
                
                Section {
                    Button("설정") {
                        personAction.reminderDate = selectedDate
                        personAction.isReminderActive = true
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .navigationTitle("리마인더 설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
            }
            .onAppear {
                if let existingDate = personAction.reminderDate {
                    selectedDate = existingDate
                }
            }
        }
    }
}

// MARK: - MeetingRecordDetailView
struct MeetingRecordDetailView: View {
    @Environment(\.modelContext) private var context
    let record: MeetingRecord
    @State private var showingShareSheet = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(record.meetingType.emoji)
                            .font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(record.meetingType.rawValue)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(record.date.formatted(date: .long, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if record.duration > 0 {
                        Text("길이: \(formatDuration(record.duration))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // 텍스트 변환 결과
                if !record.transcribedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("대화 내용")
                            .font(.headline)
                        
                        Text(record.transcribedText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                    }
                }
                
                // 요약
                if !record.summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("요약")
                            .font(.headline)
                        
                        Text(record.summary)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                // 음성 파일 공유
                if record.audioFileURL != nil {
                    Button {
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("음성 파일 공유")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("만남 기록")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingShareSheet) {
            if let urlString = record.audioFileURL, let url = URL(string: urlString) {
                ShareSheet(items: [url])
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d분 %d초", minutes, seconds)
    }
}

// MARK: - AllMeetingRecordsView
struct AllMeetingRecordsView: View {
    let person: Person
    
    var sortedRecords: [MeetingRecord] {
        person.meetingRecords.sorted { $0.date > $1.date }
    }
    
    var body: some View {
        List {
            ForEach(sortedRecords, id: \.id) { record in
                NavigationLink(destination: MeetingRecordDetailView(record: record)) {
                    HStack {
                        Text(record.meetingType.emoji)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.meetingType.rawValue)
                                .font(.headline)
                            Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            if !record.transcribedText.isEmpty {
                                Text(record.transcribedText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("모든 만남 기록")
    }
}

struct EmptyPeopleView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("아직 등록된 사람이 없어요.")
                .font(.headline)
            Text("상단의 + 버튼을 눌러 새로운 관계를 추가해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}

#Preview {
    PeopleListView()
}

