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
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPersonSheet { name, contact in
                    let new = Person(name: name, contact: contact)
                    context.insert(new)
                }
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

    @Bindable var person: Person

    init(person: Person) {
        self._person = Bindable(person)
    }
    
    var body: some View {
        Form {
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
