//
//  MacPeopleListView.swift
//  mac
//
//  macOS용 Person 목록 화면
//

import SwiftUI
import SwiftData

struct MacPeopleListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Binding var selectedPerson: Person?

    @State private var showingAddPerson = false
    @State private var showingFilter = false
    @State private var showingAllCalendar = false
    @State private var searchText = ""
    @State private var filterOptions = FilterOptions.load()

    private var filteredPeople: [Person] {
        applyFilters(to: people)
    }

    var body: some View {
        List(selection: $selectedPerson) {
            ForEach(filteredPeople) { person in
                MacPersonRow(person: person)
                    .tag(person)
            }
            .onDelete(perform: deletePeople)
        }
        .navigationTitle("관계 지도")
        .searchable(text: $searchText, prompt: "이름이나 연락처로 검색")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingAllCalendar = true
                } label: {
                    Label("전체 일정", systemImage: "calendar")
                }
            }

            ToolbarItem(placement: .automatic) {
                Button {
                    showingFilter = true
                } label: {
                    Label("필터", systemImage: filterOptions.hasActiveFilters ?
                          "line.3.horizontal.decrease.circle.fill" :
                          "line.3.horizontal.decrease.circle")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddPerson = true
                } label: {
                    Label("추가", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPerson) {
            MacAddPersonSheet { name, contact in
                addPerson(name: name, contact: contact)
            }
        }
        .sheet(isPresented: $showingFilter) {
            MacPeopleFilterView(
                filterOptions: $filterOptions,
                peopleCount: people.count,
                filteredCount: filteredPeople.count
            )
        }
        .sheet(isPresented: $showingAllCalendar) {
            MacAllCalendarView()
        }
        .onChange(of: filterOptions) { oldValue, newValue in
            // 필터가 변경될 때마다 자동 저장
            newValue.save()
        }
    }

    // MARK: - Filtering Logic

    private func applyFilters(to people: [Person]) -> [Person] {
        var result = people

        // 1. 검색 텍스트 필터
        if !searchText.isEmpty {
            result = result.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.contact.localizedCaseInsensitiveContains(searchText)
            }
        }

        // 2. 관계 상태 필터
        if !filterOptions.selectedStates.isEmpty {
            result = result.filter { person in
                filterOptions.selectedStates.contains(person.state)
            }
        }

        // 3. 소홀 상태 필터
        if filterOptions.showNeglectedOnly {
            result = result.filter { $0.isNeglected }
        }

        // 4. 미완료 액션 필터
        if filterOptions.showWithIncompleteActionsOnly {
            result = result.filter { person in
                person.actions.contains { !$0.isCompleted }
            }
        }

        // 5. 긴급 액션 필터
        if filterOptions.showWithCriticalActionsOnly {
            let today = Calendar.current.startOfDay(for: Date())
            result = result.filter { person in
                person.actions.contains { action in
                    !action.isCompleted &&
                    action.action?.type == .critical &&
                    (action.reminderDate ?? Date.distantFuture) <= today
                }
            }
        }

        // 6. 마지막 접촉 필터
        if let daysSince = filterOptions.lastContactDays {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysSince, to: Date()) ?? Date()
            result = result.filter { person in
                guard let lastContact = person.lastContact else {
                    return filterOptions.includeNeverContacted
                }
                return lastContact >= cutoffDate
            }
        }

        // 7. 정렬 적용
        switch filterOptions.sortOption {
        case .name:
            result = result.sorted { $0.name < $1.name }
        case .lastContact:
            result = result.sorted { person1, person2 in
                let date1 = person1.mostRecentInteractionDate ?? person1.relationshipStartDate
                let date2 = person2.mostRecentInteractionDate ?? person2.relationshipStartDate
                return date1 > date2 // 최근이 먼저
            }
        case .relationshipState:
            result = result.sorted { person1, person2 in
                // close > warming > distant 순서
                let stateOrder: [RelationshipState: Int] = [.close: 0, .warming: 1, .distant: 2]
                let order1 = stateOrder[person1.state] ?? 3
                let order2 = stateOrder[person2.state] ?? 3
                if order1 != order2 {
                    return order1 < order2
                }
                return person1.name < person2.name // 같은 상태면 이름순
            }
        case .incompleteActions:
            result = result.sorted { person1, person2 in
                let count1 = person1.actions.filter { !$0.isCompleted }.count
                let count2 = person2.actions.filter { !$0.isCompleted }.count
                if count1 != count2 {
                    return count1 > count2 // 미완료 액션이 많은 순
                }
                return person1.name < person2.name // 같으면 이름순
            }
        }

        return result
    }

    private func addPerson(name: String, contact: String) {
        let newPerson = Person(name: name, contact: contact)
        context.insert(newPerson)

        do {
            try context.save()
            print("✅ [macOS] 새 Person 저장 완료: \(name)")

            // 새 Person에 대한 액션 인스턴스들 생성
            DataSeeder.createPersonActionsForNewPerson(person: newPerson, context: context)

            // 자동으로 선택
            selectedPerson = newPerson
        } catch {
            print("❌ [macOS] 새 Person 저장 실패: \(error)")
        }
    }

    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            let person = filteredPeople[index]
            context.delete(person)
        }
    }
}

// MARK: - Person Row

struct MacPersonRow: View {
    let person: Person

    // 날짜를 상대적인 시간으로 포맷팅
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    var body: some View {
        HStack(spacing: 12) {
            // 프로필 이미지
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
            .frame(width: 40, height: 40)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.headline)

                if !person.contact.isEmpty {
                    Text(person.contact)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // 마지막 접촉일
                if let lastInteractionDate = person.mostRecentInteractionDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(formatRelativeDate(lastInteractionDate))
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text("접촉 기록 없음")
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                }

                // 관계 상태 배지
                HStack(spacing: 4) {
                    Circle()
                        .fill(person.state.color)
                        .frame(width: 8, height: 8)
                    Text(person.state.localizedName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // 미완료 액션 개수
            if person.incompleteActionsCount > 0 {
                Text("\(person.incompleteActionsCount)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue)
                    )
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Person Sheet

struct MacAddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var contact = ""

    let onAdd: (String, String) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("새로운 사람 추가")
                .font(.title2)
                .fontWeight(.bold)

            Form {
                TextField("이름", text: $name)
                    .textFieldStyle(.roundedBorder)

                TextField("연락처 (선택사항)", text: $contact)
                    .textFieldStyle(.roundedBorder)
            }
            .padding()

            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("추가") {
                    onAdd(name, contact)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 250)
        .padding()
    }
}

#Preview {
    MacPeopleListView(selectedPerson: .constant(nil))
        .modelContainer(for: [Person.self])
}
