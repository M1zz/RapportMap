//
//  PeopleListView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/2/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import AVFoundation
import Combine

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
                            .simultaneousGesture(
                                TapGesture().onEnded {
                                    // PersonDetailView로 이동할 때 상태 저장
                                    AppStateManager.shared.selectPerson(person)
                                }
                            )
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
                    Menu {
                        Button("샘플 데이터") {
                            addSampleData()
                        }
                        Button("액션 리셋") {
                            DataSeeder.resetDefaultActions(context: context)
                        }
                    } label: {
                        Text("개발")
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
                    
                    // 먼저 저장
                    do {
                        try context.save()
                        print("✅ 새 Person 저장 완료: \(name)")
                        
                        // 새 Person에 대한 액션 인스턴스들 생성
                        DataSeeder.createPersonActionsForNewPerson(person: new, context: context)
                    } catch {
                        print("❌ 새 Person 저장 실패: \(error)")
                    }
                }
            }
            .onAppear {
                // 앱 최초 실행 시 기본 액션 30개 생성
                DataSeeder.seedDefaultActionsIfNeeded(context: context)
                
                // 관계 상태 자동 업데이트 스케줄링
                RelationshipStateManager.shared.scheduleRelationshipStateCheck(context: context)
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
    @State private var showingQuickRecord = false

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
                // 새로운 정보들 간단 표시 + 클릭 가능한 기록 버튼들
                if let _ = person.recentConcerns, !person.recentConcerns!.isEmpty {
                    Chip(text: "🧠 고민")
                        .foregroundStyle(.purple)
                }
                if let _ = person.unresolvedPromises, !person.unresolvedPromises!.isEmpty {
                    Chip(text: "🤝 약속")
                        .foregroundStyle(.red)
                }
                
                // 빠른 기록 버튼 (새로 추가)
                Button {
                    showingQuickRecord = true
                } label: {
                    Chip(text: "📝 기록하기")
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
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
        .sheet(isPresented: $showingQuickRecord) {
            QuickRecordSheet(person: person)
        }
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

// MARK: - QuickRecordSheet
struct QuickRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var person: Person
    
    @State private var recentConcerns: String = ""
    @State private var receivedQuestions: String = ""
    @State private var unresolvedPromises: String = ""
    @State private var unansweredCount: Int = 0
    @State private var isNeglected: Bool = false
    @State private var lastContact: Date?
    @State private var hasContactDate: Bool = false
    
    init(person: Person) {
        self.person = person
        self._recentConcerns = State(initialValue: person.recentConcerns ?? "")
        self._receivedQuestions = State(initialValue: person.receivedQuestions ?? "")
        self._unresolvedPromises = State(initialValue: person.unresolvedPromises ?? "")
        self._unansweredCount = State(initialValue: person.unansweredCount)
        self._isNeglected = State(initialValue: person.isNeglected)
        self._lastContact = State(initialValue: person.lastContact)
        self._hasContactDate = State(initialValue: person.lastContact != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Text(person.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text(person.state.emoji)
                            .font(.title)
                    }
                    .padding(.vertical, 4)
                }
                
                Section("📞 연락 기록") {
                    Toggle("방금 연락했음", isOn: $hasContactDate)
                    
                    if hasContactDate {
                        DatePicker("연락 시간", selection: Binding(
                            get: { lastContact ?? Date() },
                            set: { lastContact = $0 }
                        ), displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        
                        // 빠른 시간 선택
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            Button("지금") {
                                lastContact = Date()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("1시간 전") {
                                lastContact = Date().addingTimeInterval(-3600)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Button("오늘 오전") {
                                lastContact = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
                
                Section("💬 대화 상태") {
                    Stepper(value: $unansweredCount, in: 0...20) {
                        Text("미해결 대화: \(unansweredCount)개")
                    }
                    
                    Toggle("관계가 소홀해짐", isOn: $isNeglected)
                }
                
                Section(header: Text("🧠 최근의 고민"), footer: Text("예: 이직 고민, 건강 문제, 인간관계 등")
                    .font(.caption)
                    .foregroundStyle(.secondary)) {
                    TextField("이 사람이 최근에 고민하고 있는 것은?", text: $recentConcerns, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                }
                
                Section(header: Text("❓ 받았던 질문"), footer: Text("예: 추천 요청, 조언 구함, 도움 요청 등")
                    .font(.caption)
                    .foregroundStyle(.secondary)) {
                    TextField("이 사람에게 받은 질문이나 요청사항은?", text: $receivedQuestions, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                }
                
                Section(header: Text("🤝 미해결된 약속"), footer: Text("예: 약속한 만남, 전해줄 정보, 도와주기로 한 일 등")
                    .font(.caption)
                    .foregroundStyle(.secondary)) {
                    TextField("아직 지키지 못한 약속이나 해야 할 일은?", text: $unresolvedPromises, axis: .vertical)
                        .lineLimit(3...6)
                        .autocorrectionDisabled(false)
                }
                
                // 미리보기 섹션
                if !recentConcerns.isEmpty || !receivedQuestions.isEmpty || !unresolvedPromises.isEmpty || unansweredCount > 0 || isNeglected {
                    Section("📋 기록 미리보기") {
                        VStack(alignment: .leading, spacing: 12) {
                            if !recentConcerns.isEmpty {
                                PreviewCard(icon: "🧠", title: "고민", content: recentConcerns, color: .purple)
                            }
                            
                            if !receivedQuestions.isEmpty {
                                PreviewCard(icon: "❓", title: "질문", content: receivedQuestions, color: .blue)
                            }
                            
                            if !unresolvedPromises.isEmpty {
                                PreviewCard(icon: "🤝", title: "약속", content: unresolvedPromises, color: .red)
                            }
                            
                            if unansweredCount > 0 {
                                HStack(spacing: 8) {
                                    Text("💬")
                                        .font(.caption)
                                    Text("미해결 대화 \(unansweredCount)개")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                }
                            }
                            
                            if isNeglected {
                                HStack(spacing: 8) {
                                    Text("⚠️")
                                        .font(.caption)
                                    Text("관계가 소홀해짐")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("대화 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveRecord()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveRecord() {
        // 텍스트 필드 내용 저장
        person.recentConcerns = recentConcerns.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : recentConcerns.trimmingCharacters(in: .whitespacesAndNewlines)
        person.receivedQuestions = receivedQuestions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : receivedQuestions.trimmingCharacters(in: .whitespacesAndNewlines)
        person.unresolvedPromises = unresolvedPromises.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : unresolvedPromises.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 숫자/불린 값들 저장
        person.unansweredCount = unansweredCount
        person.isNeglected = isNeglected
        
        // 연락 날짜 저장
        if hasContactDate {
            person.lastContact = lastContact
        }
        
        // 데이터베이스 저장
        do {
            try context.save()
            print("✅ \(person.name)님의 대화 기록 저장 완료")
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ 대화 기록 저장 실패: \(error)")
        }
    }
}

// MARK: - PreviewCard (Helper)
struct PreviewCard: View {
    let icon: String
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            
            Text(content)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .cornerRadius(8)
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
    @State private var showingAddCriticalAction = false
    @State private var showingInteractionEdit = false
    @State private var selectedInteractionType: RecentInteractionsView.InteractionType?

    @Bindable var person: Person

    init(person: Person) {
        self._person = Bindable(person)
    }
    
    var body: some View {
        Form {
            // 📅 최근 상호작용 (맨 위로 이동)
            Section("📅 최근 상호작용") {
                RecentInteractionsView(person: person)
            }
            
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
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 빠른 상호작용 기록
                HStack(spacing: 16) {
                    ForEach([RecentInteractionsView.InteractionType.mentoring, .meal, .contact], id: \.self) { type in
                        Button {
                            // 현재 시간으로 기록하고 편집 시트 열기
                            type.setDate(for: person, date: Date())
                            try? context.save()
                            selectedInteractionType = type
                            showingInteractionEdit = true
                            
                            // 햅틱 피드백
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        } label: {
                            VStack(spacing: 6) {
                                Text(type.emoji)
                                    .font(.title2)
                                Text(type.title)
                                    .font(.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
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
            Section("⚠️ 놓치면 안되는 것들") {
                ForEach(getCriticalActions(), id: \.id) { personAction in
                    CriticalActionReminderRow(personAction: personAction)
                }
                
                // 크리티컬 액션 추가 버튼
                Button {
                    showingAddCriticalAction = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.orange)
                        Text("놓치면 안되는 것 추가하기")
                            .foregroundStyle(.orange)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                if getCriticalActions().isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("여기에 표시할 중요한 것이 없어요")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("라포 액션 체크리스트에서 중요한 액션들을 완료한 후 눈 모양 버튼을 눌러 여기에 표시하도록 설정하거나, 위의 버튼으로 새로운 중요한 것을 추가해보세요.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
            }
            
            // 알게 된 정보 (트래킹 액션만)
            if !getCompletedTrackingActions().isEmpty {
                Section("📝 알게 된 정보") {
                    ForEach(getCompletedTrackingActions(), id: \.id) { personAction in
                        if let action = personAction.action, !personAction.context.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Image(systemName: "chart.line.uptrend.xyaxis")
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                    
                                    Text(action.title)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("정보")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Capsule().fill(Color.blue.opacity(0.2)))
                                        .foregroundStyle(.blue)
                                }
                                
                                Text(personAction.context)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                
                                // 완료일 표시
                                if let completedDate = personAction.completedDate {
                                    Text("완료: \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
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
                // 관계 상태 분석 카드
                RelationshipAnalysisCard(person: person)
                
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
                        HStack {
                            Text(person.state.emoji)
                            Text(stateLabel)
                                .foregroundColor(stateColor)
                        }
                        
                        Button("재계산") {
                            do {
                                try RelationshipStateManager.shared.updatePersonRelationshipState(person, context: context)
                            } catch {
                                print("❌ 관계 상태 재계산 실패: \(error)")
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.blue)
                    }
                }
            }

            
            Section("대화/상태") {
                if isEditing {
                    Stepper(value: $person.unansweredCount, in: 0...100) {
                        Text("미해결 대화: \(person.unansweredCount)")
                    }
                    Toggle("관계가 소홀함", isOn: $person.isNeglected)
                    
                    // 최근의 고민
                    VStack(alignment: .leading, spacing: 4) {
                        Text("최근의 고민")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("이 사람이 최근에 고민하고 있는 것은?", text: Binding(
                            get: { person.recentConcerns ?? "" },
                            set: { person.recentConcerns = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    // 받았던 질문
                    VStack(alignment: .leading, spacing: 4) {
                        Text("받았던 질문")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("이 사람에게 받은 질문이나 요청사항은?", text: Binding(
                            get: { person.receivedQuestions ?? "" },
                            set: { person.receivedQuestions = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    }
                    
                    // 미해결된 약속
                    VStack(alignment: .leading, spacing: 4) {
                        Text("미해결된 약속")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("아직 지키지 못한 약속이나 해야 할 일은?", text: Binding(
                            get: { person.unresolvedPromises ?? "" },
                            set: { person.unresolvedPromises = $0.isEmpty ? nil : $0 }
                        ), axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                    }
                } else {
                    if person.unansweredCount > 0 {
                        Text("미해결 대화: \(person.unansweredCount)")
                            .foregroundColor(.orange)
                    }
                    if person.isNeglected {
                        Text("이 사람과의 관계가 소홀해졌습니다. 다시 연결하세요.")
                            .foregroundColor(.blue)
                    }
                    
                    // 최근의 고민 표시
                    if let concerns = person.recentConcerns, !concerns.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "brain.head.profile")
                                    .font(.caption)
                                    .foregroundStyle(.purple)
                                Text("최근의 고민")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.purple)
                            }
                            Text(concerns)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // 받았던 질문 표시
                    if let questions = person.receivedQuestions, !questions.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "questionmark.bubble")
                                    .font(.caption)
                                    .foregroundStyle(.blue)
                                Text("받았던 질문")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Text(questions)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // 미해결된 약속 표시
                    if let promises = person.unresolvedPromises, !promises.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "hand.raised")
                                    .font(.caption)
                                    .foregroundStyle(.red)
                                Text("미해결된 약속")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.red)
                            }
                            Text(promises)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(8)
                        }
                    }
                    
                    // 빈 상태일 때 안내 메시지
                    if person.unansweredCount == 0 && 
                       !person.isNeglected && 
                       (person.recentConcerns?.isEmpty ?? true) && 
                       (person.receivedQuestions?.isEmpty ?? true) && 
                       (person.unresolvedPromises?.isEmpty ?? true) {
                        VStack(spacing: 8) {
                            Image(systemName: "bubble.left.and.text.page")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            
                            Text("대화 기록이 비어있어요")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Text("편집 모드에서 최근 고민, 받은 질문, 약속 등을 기록해보세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
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
                // Person 삭제 시 앱 상태도 초기화
                AppStateManager.shared.clearSelection()
                context.delete(person)
                try? context.save()
                dismiss()
            }
            Button("취소", role: .cancel) { }
        }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView(person: person)
        }
        .sheet(isPresented: $showingAddCriticalAction) {
            AddCriticalActionSheet(person: person)
        }
        .sheet(isPresented: $showingInteractionEdit) {
            if let selectedType = selectedInteractionType {
                EditInteractionSheet(person: person, interactionType: selectedType)
            }
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
                // Critical 액션이면서 PersonDetailView에서 보이도록 설정된 것들만
                $0.action?.type == .critical && $0.isVisibleInDetail
            }
            .sorted { 
                // 미완료를 먼저, 완료된 것들은 아래로 (취소선으로 표시됨)
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted // 미완료가 먼저, 완료된 것은 아래로
                }
                return ($0.action?.order ?? 0) < ($1.action?.order ?? 0)
            }
    }
}

// MARK: - RecentInteractionsView
struct RecentInteractionsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @State private var showingEditSheet = false
    @State private var showingHistory = false
    @State private var interactionToEdit: InteractionType?
    
    enum InteractionType: CaseIterable {
        case mentoring
        case meal
        case contact
        
        var title: String {
            switch self {
            case .mentoring: return "멘토링"
            case .meal: return "식사"
            case .contact: return "연락"
            }
        }
        
        var emoji: String {
            switch self {
            case .mentoring: return "🧑‍🏫"
            case .meal: return "🍽️"  
            case .contact: return "💬"
            }
        }
        
        var systemImage: String {
            switch self {
            case .mentoring: return "person.badge.clock"
            case .meal: return "fork.knife"
            case .contact: return "bubble.left"
            }
        }
        
        func getDate(from person: Person) -> Date? {
            switch self {
            case .mentoring: return person.lastMentoring
            case .meal: return person.lastMeal
            case .contact: return person.lastContact
            }
        }
        
        func setDate(for person: Person, date: Date?) {
            switch self {
            case .mentoring: person.lastMentoring = date
            case .meal: person.lastMeal = date
            case .contact: person.lastContact = date
            }
        }
    }
    
    // 최근 상호작용들을 날짜순으로 정렬
    private var sortedInteractions: [(InteractionType, Date)] {
        let interactions: [(InteractionType, Date?)] = [
            (.mentoring, person.lastMentoring),
            (.meal, person.lastMeal),
            (.contact, person.lastContact)
        ]
        
        return interactions
            .compactMap { type, date in
                guard let date = date else { return nil }
                return (type, date)
            }
            .sorted { $0.1 > $1.1 } // 최신순
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 히스토리 보기 헤더
            HStack {
                Text("최근 상호작용")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    showingHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption)
                        Text("기록 보기")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            
            // 가로 스크롤 카드들
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedInteractions, id: \.0) { interactionType, date in
                        InteractionCard(
                            type: interactionType,
                            date: date,
                            person: person,
                            onTap: {
                                interactionToEdit = interactionType
                                showingEditSheet = true
                            }
                        )
                    }
                    
                    // 기록이 없는 상호작용들도 표시 (빈 카드)
                    ForEach(InteractionType.allCases.filter { type in
                        !sortedInteractions.contains { $0.0 == type }
                    }, id: \.self) { type in
                        EmptyInteractionCard(type: type) {
                            interactionToEdit = type
                            showingEditSheet = true
                        }
                    }
                }
                .padding(.horizontal)
            }
            .scrollTargetBehavior(.viewAligned)
            
            // 빠른 액션 버튼들
            VStack(spacing: 8) {
                Text("빠른 기록")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(InteractionType.allCases, id: \.self) { type in
                        Button {
                            // "지금" 기록 후 편집 시트 열기
                            type.setDate(for: person, date: Date())
                            try? context.save()
                            
                            // 햅틱 피드백
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // 편집 시트 열기
                            interactionToEdit = type
                            showingEditSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                    .font(.caption)
                                Text("지금")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let interactionType = interactionToEdit {
                EditInteractionSheet(person: person, interactionType: interactionType)
            }
        }
        .sheet(isPresented: $showingHistory) {
            InteractionHistoryView(person: person)
        }
    }
}

// MARK: - InteractionHistoryView
struct InteractionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    
    // 실제 기록된 상호작용들만 표시
    private var historyRecords: [(Date, RecentInteractionsView.InteractionType)] {
        var records: [(Date, RecentInteractionsView.InteractionType)] = []
        
        // 실제 기록된 상호작용들만 추가
        if let mentoring = person.lastMentoring {
            records.append((mentoring, .mentoring))
        }
        if let meal = person.lastMeal {
            records.append((meal, .meal))
        }
        if let contact = person.lastContact {
            records.append((contact, .contact))
        }
        
        // 날짜순 정렬 (최신순)
        return records.sorted { $0.0 > $1.0 }
    }
    
    var body: some View {
        NavigationStack {
            if historyRecords.isEmpty {
                // 빈 상태 표시
                VStack(spacing: 20) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    
                    Text("상호작용 기록이 없어요")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("멘토링, 식사, 연락 등의 기록을 추가해보세요.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    
                    Button("기록 추가하러 가기") {
                        dismiss()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(10)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemGroupedBackground))
            } else {
                List {
                    ForEach(Array(historyRecords.enumerated()), id: \.offset) { index, record in
                        InteractionHistoryRow(
                            date: record.0,
                            type: record.1,
                            person: person
                        )
                    }
                }
            }
        }
        .navigationTitle("상호작용 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("완료") {
                    dismiss()
                }
            }
        }
    }
}

// MARK: - InteractionHistoryRow
struct InteractionHistoryRow: View {
    let date: Date
    let type: RecentInteractionsView.InteractionType
    let person: Person
    
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    
    private var isCurrentRecord: Bool {
        switch type {
        case .mentoring: return person.lastMentoring == date
        case .meal: return person.lastMeal == date
        case .contact: return person.lastContact == date
        }
    }
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 타입 아이콘
            Text(type.emoji)
                .font(.title2)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(type.title)
                        .font(.headline)
                    
                    if isCurrentRecord {
                        Text("현재")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue))
                            .foregroundStyle(.white)
                    }
                }
                
                Text(relativeDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Spacer()
            
            // 편집 버튼 (현재 기록인 경우에만)
            if isCurrentRecord {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingEditSheet) {
            EditInteractionSheet(person: person, interactionType: type)
        }
    }
}

// MARK: - InteractionCard
struct InteractionCard: View {
    let type: RecentInteractionsView.InteractionType
    let date: Date
    let onTap: () -> Void
    let person: Person
    
    init(type: RecentInteractionsView.InteractionType, date: Date, person: Person, onTap: @escaping () -> Void) {
        self.type = type
        self.date = date
        self.person = person
        self.onTap = onTap
    }
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
    
    private var isRecent: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince <= 3
    }
    
    private var notes: String? {
        switch type {
        case .mentoring: return person.mentoringNotes
        case .meal: return person.mealNotes
        case .contact: return person.contactNotes
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 미모지와 타이틀
                VStack(spacing: 4) {
                    Text(type.emoji)
                        .font(.largeTitle)
                    
                    Text(type.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                
                // 상대적 시간
                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(isRecent ? .green : .secondary)
                    .fontWeight(isRecent ? .semibold : .regular)
                
                // 정확한 날짜
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                // 내용 표시 (있는 경우)
                if let notes = notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                }
            }
            .padding()
            .frame(width: 120, height: notes?.isEmpty == false ? 160 : 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isRecent ? Color.green.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isRecent ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EmptyInteractionCard
struct EmptyInteractionCard: View {
    let type: RecentInteractionsView.InteractionType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(type.emoji)
                        .font(.largeTitle)
                        .opacity(0.5)
                    
                    Text(type.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                
                Text("기록 없음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("탭해서 추가")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
            .padding()
            .frame(width: 120, height: 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - EditInteractionSheet
struct EditInteractionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var person: Person
    let interactionType: RecentInteractionsView.InteractionType
    
    @State private var selectedDate: Date
    @State private var hasDate: Bool
    @State private var notes: String = ""
    
    init(person: Person, interactionType: RecentInteractionsView.InteractionType) {
        self.person = person
        self.interactionType = interactionType
        
        let currentDate = interactionType.getDate(from: person) ?? Date()
        self._selectedDate = State(initialValue: currentDate)
        self._hasDate = State(initialValue: interactionType.getDate(from: person) != nil)
        
        // 기존 노트 불러오기
        self._notes = State(initialValue: Self.getExistingNotes(person: person, type: interactionType))
    }
    
    // Person 모델에 mentoringNotes, mealNotes, contactNotes 프로퍼티가 추가되었습니다.
    
    private static func getExistingNotes(person: Person, type: RecentInteractionsView.InteractionType) -> String {
        switch type {
        case .mentoring: return person.mentoringNotes ?? ""
        case .meal: return person.mealNotes ?? ""
        case .contact: return person.contactNotes ?? ""
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("상호작용 정보") {
                    HStack {
                        Text(interactionType.emoji)
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(interactionType.title)
                                .font(.headline)
                            Text("마지막 \(interactionType.title) 날짜를 설정해주세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("날짜 설정") {
                    Toggle("날짜 기록하기", isOn: $hasDate)
                    
                    if hasDate {
                        DatePicker("날짜와 시간", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                        
                        // 빠른 선택 버튼들
                        VStack(alignment: .leading, spacing: 8) {
                            Text("빠른 선택")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 8) {
                                QuickDateButton(title: "지금", date: Date()) { date in
                                    selectedDate = date
                                }
                                QuickDateButton(title: "1시간 전", date: Date().addingTimeInterval(-3600)) { date in
                                    selectedDate = date
                                }
                                QuickDateButton(title: "오늘 오전", date: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()) { date in
                                    selectedDate = date
                                }
                                QuickDateButton(title: "어제", date: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()) { date in
                                    selectedDate = date
                                }
                            }
                        }
                    }
                }
                
                // 내용 추가 섹션
                Section("상호작용 내용") {
                    TextField("이번 \(interactionType.title)에서 어떤 이야기를 나눴나요?", text: $notes, axis: .vertical)
                        .lineLimit(3...8)
                        .autocorrectionDisabled(false)
                }
                
                if hasDate {
                    Section("미리보기") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: interactionType.systemImage)
                                    .foregroundStyle(.blue)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("마지막 \(interactionType.title)")
                                        .font(.headline)
                                    
                                    Text(selectedDate.formatted(date: .long, time: .shortened))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                    
                                    let relativeFormatter = RelativeDateTimeFormatter()
                                    Text(relativeFormatter.localizedString(for: selectedDate, relativeTo: .now))
                                        .font(.caption)
                                        .foregroundStyle(.blue)
                                }
                            }
                            
                            // 내용 미리보기
                            if !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Divider()
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("내용:")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(notes)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .padding(.top, 2)
                                }
                            }
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                
                if hasDate {
                    Section {
                        Button("기록 삭제", role: .destructive) {
                            hasDate = false
                        }
                    }
                }
            }
            .navigationTitle("\(interactionType.title) 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveInteraction()
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveInteraction() {
        if hasDate {
            interactionType.setDate(for: person, date: selectedDate)
        } else {
            interactionType.setDate(for: person, date: nil)
        }
        
        // 노트 저장
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        switch interactionType {
        case .mentoring:
            person.mentoringNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        case .meal:
            person.mealNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        case .contact:
            person.contactNotes = trimmedNotes.isEmpty ? nil : trimmedNotes
        }
        
        do {
            try context.save()
            print("✅ \(interactionType.title) 기록 저장 완료")
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ \(interactionType.title) 기록 저장 실패: \(error)")
        }
    }
}

// MARK: - QuickDateButton
struct QuickDateButton: View {
    let title: String
    let date: Date
    let onTap: (Date) -> Void
    
    var body: some View {
        Button {
            onTap(date)
        } label: {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundStyle(.blue)
                .cornerRadius(16)
        }
        .buttonStyle(.plain)
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
                            // Critical 액션 완료 시 특별 표시
                            if personAction.isCompleted {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .font(.caption)
                                    .foregroundStyle(.green) // 초록색으로 변경
                            }
                            
                            Text(action.title)
                                .font(.headline)
                                .foregroundStyle(
                                    personAction.isCompleted 
                                        ? .secondary // Critical 완료 시 회색으로 변경
                                        : .primary
                                )
                                .strikethrough(personAction.isCompleted, color: .orange) // Critical 액션도 완료되면 취소선 적용
                            
                            // 긴급도 뱃지 (미완료 시에만)
                            if !personAction.isCompleted {
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
                            } else {
                                // 완료된 경우 완료 표시
                                Text("완료됨")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.green)) // 초록색으로 변경
                                    .foregroundStyle(.white)
                            }
                        }
                        
                        if !action.actionDescription.isEmpty {
                            Text(action.actionDescription)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 완료된 액션의 결과 표시
                        if personAction.isCompleted && !personAction.context.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                Text(personAction.context)
                                    .font(.subheadline)
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.orange.gradient) // Critical 액션이므로 오렌지색 유지
                            )
                        }
                    }
                }
                
                Spacer()
                
                // 숨기기 버튼
                Button {
                    personAction.isVisibleInDetail = false
                    try? context.save()
                } label: {
                    Image(systemName: "eye.slash")
                        .font(.caption)
                        .foregroundStyle(.gray)
                }
                .buttonStyle(.plain)
                
                // 완료 체크박스
                Button {
                    // 완료 상태 토글 허용 (Critical 액션도 포함)
                    personAction.isCompleted.toggle()
                    if personAction.isCompleted {
                        personAction.markCompleted()
                    } else {
                        personAction.markIncomplete()
                    }
                    try? context.save()
                } label: {
                    Image(systemName: personAction.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(personAction.isCompleted ? .green : .gray) // 완료된 Critical도 초록색으로
                }
                .buttonStyle(.plain) // 버튼 스타일 추가
            }
            
            // 리마인더 설정 (미완료 시에만)
            if !personAction.isCompleted {
                HStack {
                    Button {
                        showingReminderPicker = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: personAction.reminderDate != nil ? "bell.fill" : "bell")
                                .font(.caption)
                            
                            if let reminderDate = personAction.reminderDate {
                                Text(reminderDate.formatted(date: .abbreviated, time: .shortened))
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
                    .buttonStyle(.plain) // 버튼 스타일 추가
                    
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
                        .buttonStyle(.plain) // 버튼 스타일 추가
                    }
                }
            } else {
                // 완료된 액션의 완료일 표시
                if let completedDate = personAction.completedDate {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green) // 초록색으로 변경
                        Text("완료일: \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary) // 회색으로 변경
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle()) // 전체 영역을 탭 가능하게 하지만 기본 동작은 없음
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
    @State private var isSettingReminder = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("리마인더 일시") {
                    DatePicker("날짜와 시간", selection: $selectedDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("미리보기") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(.blue)
                            Text("알림 예정")
                                .font(.headline)
                        }
                        
                        Text(selectedDate.formatted(date: .complete, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        if let action = personAction.action {
                            Text("\"\(action.title)\" 액션을 확인하세요")
                                .font(.caption)
                                .foregroundStyle(.blue)
                        }
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
                if let existingDate = personAction.reminderDate {
                    selectedDate = existingDate
                } else {
                    // 기본값: 1시간 후로 설정
                    selectedDate = Date().addingTimeInterval(3600)
                }
            }
        }
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
        
        guard let action = personAction.action else {
            isSettingReminder = false
            return
        }
        
        let title = "\(action.title) 리마인더"
        let body = "\(personAction.person?.preferredName ?? personAction.person?.name ?? "")님과 관련된 중요한 액션을 확인해보세요"
        
        let success = await NotificationManager.shared.scheduleActionReminder(
            for: personAction,
            at: selectedDate,
            title: title,
            body: body
        )
        
        isSettingReminder = false
        
        if success {
            // 데이터베이스에 리마인더 정보 저장
            personAction.reminderDate = selectedDate
            personAction.isReminderActive = true
            try? context.save()
            
            // 성공 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            dismiss()
        }
        // TODO: 실패 시 에러 얼럿 표시
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
                
                // 오디오 플레이어 (음성 파일이 있는 경우)
                if let urlString = record.audioFileURL, let url = URL(string: urlString) {
                    AudioPlayerView(audioURL: url, totalDuration: record.duration)
                }
                
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

// MARK: - AudioPlayerView
struct AudioPlayerView: View {
    let audioURL: URL
    let totalDuration: TimeInterval
    
    @StateObject private var player = AudioPlayer()
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var isDragging = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                Text("음성 기록")
                    .font(.headline)
                Spacer()
                Text(formatTime(player.duration > 0 ? player.duration : totalDuration))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 프로그레스 바
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 배경
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        // 진행률
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: progressWidth(geometry: geometry), height: 4)
                            .cornerRadius(2)
                        
                        // 드래그 핸들
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 16, height: 16)
                            .offset(x: progressWidth(geometry: geometry) - 8)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        isDragging = true
                                        let progress = min(max(0, (value.location.x / geometry.size.width)), 1)
                                        let seekTime = progress * (player.duration > 0 ? player.duration : totalDuration)
                                        currentTime = seekTime
                                    }
                                    .onEnded { value in
                                        let progress = min(max(0, (value.location.x / geometry.size.width)), 1)
                                        let seekTime = progress * (player.duration > 0 ? player.duration : totalDuration)
                                        player.seek(to: seekTime)
                                        isDragging = false
                                    }
                            )
                    }
                }
                .frame(height: 16)
                
                // 시간 표시
                HStack {
                    Text(formatTime(isDragging ? currentTime : player.currentTime))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .leading)
                    
                    Spacer()
                    
                    Text(formatTime(player.duration > 0 ? player.duration : totalDuration))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
            }
            
            // 컨트롤 버튼들
            HStack {
                // 15초 뒤로
                Button {
                    player.skip(by: -15)
                } label: {
                    Image(systemName: "gobackward.15")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(!player.isReady)
                
                Spacer()
                
                // 재생/일시정지
                Button {
                    if isPlaying {
                        player.pause()
                    } else {
                        player.play()
                    }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                }
                .disabled(!player.isReady)
                
                Spacer()
                
                // 15초 앞으로
                Button {
                    player.skip(by: 15)
                } label: {
                    Image(systemName: "goforward.15")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .disabled(!player.isReady)
            }
            .padding(.horizontal)
            
            // 재생 속도 조절
            HStack {
                Text("재생 속도:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                HStack(spacing: 8) {
                    ForEach([0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { speed in
                        Button {
                            player.setPlaybackRate(Float(speed))
                        } label: {
                            Text("\(speed, specifier: "%.2g")x")
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    player.playbackRate == Float(speed) 
                                        ? Color.blue 
                                        : Color.gray.opacity(0.2)
                                )
                                .foregroundStyle(
                                    player.playbackRate == Float(speed) 
                                        ? .white 
                                        : .primary
                                )
                                .cornerRadius(12)
                        }
                        .disabled(!player.isReady)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            player.loadAudio(from: audioURL)
        }
        .onDisappear {
            player.stop()
        }
        .onReceive(player.timePublisher) { time in
            if !isDragging {
                currentTime = time
            }
        }
        .onReceive(player.didFinishPlaying) {
            isPlaying = false
        }
    }
    
    private func progressWidth(geometry: GeometryProxy) -> CGFloat {
        let duration = player.duration > 0 ? player.duration : totalDuration
        guard duration > 0 else { return 0 }
        
        let time = isDragging ? currentTime : player.currentTime
        let progress = time / duration
        return geometry.size.width * progress
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - AudioPlayer ObservableObject
class AudioPlayer: NSObject, ObservableObject {
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    
    @Published var isReady = false
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0
    
    let timePublisher = PassthroughSubject<TimeInterval, Never>()
    let didFinishPlaying = PassthroughSubject<Void, Never>()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }
    
    func loadAudio(from url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            audioPlayer?.enableRate = true
            
            duration = audioPlayer?.duration ?? 0
            isReady = true
        } catch {
            print("Failed to load audio: \(error)")
            isReady = false
        }
    }
    
    func play() {
        guard let player = audioPlayer else { return }
        player.play()
        isPlaying = true
        startTimer()
    }
    
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimer()
    }
    
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        currentTime = 0
        isPlaying = false
        stopTimer()
    }
    
    func seek(to time: TimeInterval) {
        guard let player = audioPlayer else { return }
        player.currentTime = time
        currentTime = time
    }
    
    func skip(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(0, min(duration, player.currentTime + seconds))
        seek(to: newTime)
    }
    
    func setPlaybackRate(_ rate: Float) {
        audioPlayer?.rate = rate
        playbackRate = rate
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.currentTime = self.audioPlayer?.currentTime ?? 0
            self.timePublisher.send(self.currentTime)
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

// MARK: - AVAudioPlayerDelegate
extension AudioPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        currentTime = 0
        stopTimer()
        didFinishPlaying.send()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Audio player decode error: \(error?.localizedDescription ?? "Unknown error")")
        isPlaying = false
        stopTimer()
    }
}



// MARK: - RelationshipAnalysisCard
struct RelationshipAnalysisCard: View {
    let person: Person
    @State private var analysis: RelationshipAnalysis?
    @State private var showingDetailedAnalysis = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let analysis = analysis {
                // 상태 요약
                HStack {
                    Text(analysis.currentState.emoji)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(analysis.currentState.rawValue)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("점수: \(Int(analysis.currentScore))/100")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingDetailedAnalysis = true
                    } label: {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .foregroundStyle(.blue)
                    }
                }
                
                // 진행률 바
                ProgressView(value: analysis.currentScore, total: 100) {
                    Text("관계 건강도")
                        .font(.caption)
                } currentValueLabel: {
                    Text("\(Int(analysis.currentScore))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .tint(progressColor(for: analysis.currentScore))
                
                // 빠른 인사이트
                if !analysis.recommendations.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("💡 추천")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                        
                        Text(analysis.recommendations.first ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                
                // 마지막 상호작용
                if analysis.daysSinceLastInteraction > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text("마지막 상호작용: \(analysis.daysSinceLastInteraction)일 전")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            analysis = person.getRelationshipAnalysis()
        }
        .sheet(isPresented: $showingDetailedAnalysis) {
            if let analysis = analysis {
                DetailedRelationshipAnalysisView(person: person, analysis: analysis)
            }
        }
    }
    
    private func progressColor(for score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - DetailedRelationshipAnalysisView
struct DetailedRelationshipAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let analysis: RelationshipAnalysis
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 현재 상태 카드
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(analysis.currentState.emoji)
                                .font(.largeTitle)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(analysis.currentState.rawValue)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("현재 점수: \(Int(analysis.currentScore))/100")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Text(analysis.currentState.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        ProgressView(value: analysis.currentScore, total: 100)
                            .tint(progressColor(for: analysis.currentScore))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 상세 지표들
                    VStack(alignment: .leading, spacing: 16) {
                        Text("📊 상세 분석")
                            .font(.headline)
                        
                        MetricRow(
                            title: "전체 액션 완료율",
                            value: analysis.actionCompletionRate,
                            icon: "checkmark.circle",
                            color: .blue
                        )
                        
                        MetricRow(
                            title: "중요 액션 완료율",
                            value: analysis.criticalActionCompletionRate,
                            icon: "exclamationmark.triangle",
                            color: .orange
                        )
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.gray)
                            Text("마지막 상호작용")
                            Spacer()
                            Text("\(analysis.daysSinceLastInteraction)일 전")
                                .fontWeight(.semibold)
                                .foregroundStyle(analysis.daysSinceLastInteraction > 14 ? .red : .secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 추천사항
                    if !analysis.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 관계 개선 추천")
                                .font(.headline)
                            
                            ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                    
                                    Text(recommendation)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("\(person.name) 관계 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    private func progressColor(for score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - MetricRow
struct MetricRow: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(title)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(value * 100))%")
                    .fontWeight(.semibold)
                
                ProgressView(value: value, total: 1.0)
                    .frame(width: 50)
                    .tint(color)
            }
        }
    }
}

