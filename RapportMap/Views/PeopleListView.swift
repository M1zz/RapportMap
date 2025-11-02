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
            List {
#if DEBUG
                ForEach(demoSnapshots) { s in
                    RelationshipCard(s: s)
                }
#endif
                // Note: Remove PersonHintRow list for now; only show RelationshipCard UI
            }
            .navigationTitle("관계 지도")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddPersonSheet { name, contact in
                    let new = Person(name: name, contact: contact)
                    context.insert(new)
                }
            }
#if DEBUG
            .onAppear {
                if people.isEmpty {
                    let gavi = Person(name: "가비", contact: "gavi@example.com")
                    gavi.lastContact = Calendar.current.date(byAdding: .day, value: -2, to: .now)

                    let dodin = Person(name: "도딘", contact: "dodin@example.com")
                    dodin.lastContact = Calendar.current.date(byAdding: .day, value: -16, to: .now)

                    context.insert(gavi)
                    context.insert(dodin)
                }
            }
#endif
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets { context.delete(people[index]) }
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

// MARK: - UI-only Relationship Snapshot (not persisted)
struct RelationshipSnapshot: Identifiable {
    enum State: String { case distant, warming, close }
    let id = UUID()
    let name: String
    let state: State
    let lastMentoring: Date?
    let lastMeal: Date?
    let lastQuestion: String?
    let unansweredCount: Int
    let lastContact: Date?
    let isNeglected: Bool
}

struct RelationshipCard: View {
    let s: RelationshipSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1) 헤더: 이름 + 상태 점
            HStack(alignment: .firstTextBaseline) {
                Text(s.name)
                Spacer()
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 10, height: 10)
                    Text(label)
                        .foregroundStyle(color)
                }
            }

            // 2) 핵심 힌트: 멘토링 / 식사 / 미해결 질문 (이모지 사용)
            HStack(spacing: 8) {
                if let m = s.lastMentoring {
                    Chip(text: "🧑‍🏫 \(relative(m))")
                }
                if let meal = s.lastMeal {
                    Chip(text: "🍱 \(relative(meal))")
                }
                if s.unansweredCount > 0 {
                    Chip(text: "미해결 \(s.unansweredCount)")
                        .foregroundStyle(.orange)
                }
            }

            // 3) 마지막 질문(요약)
            if let q = s.lastQuestion, !q.isEmpty {
                Text("\"\(q)\"")
                    .lineLimit(2)
                    .foregroundStyle(.secondary)
            }

            // 4) 푸터: 마지막 접촉 + 방치 여부
            HStack {
                if let c = s.lastContact {
                    Text("마지막 접촉: \(relative(c))")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if s.isNeglected {
                    Chip(text: "다시 연결하기")
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
    }

    private var color: Color {
        switch s.state {
        case .distant: return .blue
        case .warming: return .orange
        case .close: return .pink
        }
    }
    private var label: String {
        switch s.state {
        case .distant: return "멀어짐"
        case .warming: return "따뜻해지는 중"
        case .close: return "끈끈함"
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

private func relative(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: .now)
}

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


// Placeholder PersonDetailView so the app can build successfully.
struct PersonDetailView: View {
    let person: Person

    var body: some View {
        VStack(spacing: 16) {
            Text(person.name)
                .padding(.top, 40)
            Text("Person detail view is under construction.")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(person.name)
    }
}


private func makePreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, configurations: config)
    let context = container.mainContext

    // 가비: 최근에 연락한 멘티 (2일 전 연락)
    let gavi = Person(name: "가비", contact: "gavi@example.com")
    gavi.lastContact = Calendar.current.date(byAdding: .day, value: -2, to: .now)

    // 도딘: 한동안 연락이 뜸한 디자이너 멘티 (16일 전 연락)
    let dodin = Person(name: "도딘", contact: "dodin@example.com")
    dodin.lastContact = Calendar.current.date(byAdding: .day, value: -16, to: .now)

    context.insert(gavi)
    context.insert(dodin)

    return container
}

#if DEBUG
private let demoSnapshots: [RelationshipSnapshot] = {
    let gavi = RelationshipSnapshot(
        name: "가비",
        state: .close,
        lastMentoring: Calendar.current.date(byAdding: .day, value: -3, to: .now),
        lastMeal: Calendar.current.date(byAdding: .day, value: -2, to: .now),
        lastQuestion: "다음 주 발표 자료 구성, 피드백 포인트 뭐가 좋을까요?",
        unansweredCount: 0,
        lastContact: Calendar.current.date(byAdding: .day, value: -1, to: .now),
        isNeglected: false
    )

    let dodin = RelationshipSnapshot(
        name: "도딘",
        state: .distant,
        lastMentoring: Calendar.current.date(byAdding: .day, value: -17, to: .now),
        lastMeal: nil,
        lastQuestion: "포트폴리오 톤앤매너를 개발자 관점에서 어떻게 정리할까요?",
        unansweredCount: 1,
        lastContact: Calendar.current.date(byAdding: .day, value: -16, to: .now),
        isNeglected: true
    )

    return [gavi, dodin]
}()
#endif

#Preview {
    let container = makePreviewContainer()
    return NavigationStack {
        PeopleListView()
            .modelContainer(container)
    }
}
