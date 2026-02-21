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

    @State private var showingSettings = false

    var body: some View {
        Group {
            if people.isEmpty {
                // 데이터가 전혀 없을 때 빈 화면
                emptyDataView
            } else {
                List(selection: $selectedPerson) {
                    ForEach(filteredPeople) { person in
                        MacPersonRow(person: person)
                            .tag(person)
                    }
                    .onDelete(perform: deletePeople)
                }
            }
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

    // MARK: - Empty Data View

    private var emptyDataView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.crop.circle.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("아직 등록된 사람이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                showingAddPerson = true
            } label: {
                Label("새로운 사람 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)

            Divider()
                .padding(.vertical, 8)

            // iCloud 복원 안내
            VStack(spacing: 8) {
                Image(systemName: "icloud.and.arrow.down")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)

                Text("다른 기기에서 사용하던\n데이터가 있으신가요?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingSettings = true
                } label: {
                    Text("설정에서 iCloud 복원하기")
                        .font(.caption)
                }
                .buttonStyle(.link)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .sheet(isPresented: $showingSettings) {
            MacSettingsView()
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

        // 2. 소홀 상태 필터
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

        // 6. 마지막 접촉 필터 (최근 N일 내 연락한 사람)
        if let daysSince = filterOptions.lastContactDays {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysSince, to: Date()) ?? Date()
            result = result.filter { person in
                guard let lastContact = person.mostRecentInteractionDate else {
                    return filterOptions.includeNeverContacted
                }
                return lastContact >= cutoffDate
            }
        }
        
        // 7. 연락 안 한 기간 필터 (N일 이상 연락 안 한 사람)
        if let minDays = filterOptions.noContactFilter.days {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -minDays, to: Date()) ?? Date()
            result = result.filter { person in
                guard let lastContact = person.mostRecentInteractionDate else {
                    return true  // 연락 기록 없으면 포함
                }
                return lastContact < cutoffDate  // 마지막 연락이 cutoff 이전이면 포함
            }
        }

        // 8. 정렬 적용
        switch filterOptions.sortOption {
        case .name:
            result = result.sorted { $0.name < $1.name }
        case .lastContact:
            result = result.sorted { person1, person2 in
                let date1 = person1.mostRecentInteractionDate ?? person1.relationshipStartDate
                let date2 = person2.mostRecentInteractionDate ?? person2.relationshipStartDate
                return date1 > date2 // 최근이 먼저
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
        case .criticalActions:
            result = result.sorted { person1, person2 in
                let count1 = person1.criticalActionsCount
                let count2 = person2.criticalActionsCount
                if count1 != count2 {
                    return count1 > count2 // 긴급 액션이 많은 순
                }
                return person1.name < person2.name
            }
        case .relationshipStart:
            result = result.sorted { person1, person2 in
                return person1.relationshipStartDate > person2.relationshipStartDate // 최근 시작이 먼저
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
    @State private var showingImagePreview = false
    
    // MARK: - Nudge 계산
    
    /// 넛지 타입
    enum NudgeType: Identifiable {
        case todayReminder      // 오늘 리마인더가 있음
        case neglected          // 오래 연락 안 함
        case unresolvedPromise  // 미해결 약속
        case unresolvedConcern  // 미해결 고민
        case criticalAction     // 긴급 액션 필요
        
        var id: String {
            switch self {
            case .todayReminder: return "today"
            case .neglected: return "neglected"
            case .unresolvedPromise: return "promise"
            case .unresolvedConcern: return "concern"
            case .criticalAction: return "critical"
            }
        }
        
        var icon: String {
            switch self {
            case .todayReminder: return "calendar.badge.clock"
            case .neglected: return "exclamationmark.triangle.fill"
            case .unresolvedPromise: return "checkmark.circle"
            case .unresolvedConcern: return "heart.fill"
            case .criticalAction: return "bolt.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .todayReminder: return .blue
            case .neglected: return .orange
            case .unresolvedPromise: return .purple
            case .unresolvedConcern: return .pink
            case .criticalAction: return .red
            }
        }
        
        var tooltip: String {
            switch self {
            case .todayReminder: return "오늘 일정이 있어요"
            case .neglected: return "연락한 지 오래됐어요"
            case .unresolvedPromise: return "약속을 확인하세요"
            case .unresolvedConcern: return "고민을 들어주세요"
            case .criticalAction: return "긴급 액션 필요"
            }
        }
    }
    
    /// 현재 사람에게 해당하는 넛지들
    private var activeNudges: [NudgeType] {
        var nudges: [NudgeType] = []
        let today = Calendar.current.startOfDay(for: Date())
        
        // 1. 오늘 리마인더가 있는지 확인
        let hasTodayReminder = person.actions.contains { action in
            guard let reminderDate = action.reminderDate else { return false }
            return Calendar.current.isDate(reminderDate, inSameDayAs: today) && !action.isCompleted
        }
        if hasTodayReminder {
            nudges.append(.todayReminder)
        }
        
        // 2. 긴급 액션이 있는지 (마감 지남)
        let hasOverdueCritical = person.actions.contains { action in
            guard !action.isCompleted,
                  action.action?.type == .critical,
                  let reminderDate = action.reminderDate else { return false }
            return reminderDate < today
        }
        if hasOverdueCritical {
            nudges.append(.criticalAction)
        }
        
        // 3. 소홀 상태인지 (이미 Person에 computed property 있음)
        if person.isNeglected && !hasTodayReminder && !hasOverdueCritical {
            nudges.append(.neglected)
        }
        
        // 4. 미해결 약속이 있는지
        let hasUnresolvedPromise = person.conversationRecords.contains {
            $0.type == .promise && !$0.isResolved
        }
        if hasUnresolvedPromise {
            nudges.append(.unresolvedPromise)
        }
        
        // 5. 미해결 고민이 있는지 (1주일 이상 된 것만)
        let hasOldConcern = person.conversationRecords.contains { record in
            guard record.type == .concern && !record.isResolved else { return false }
            let daysSince = Calendar.current.dateComponents([.day], from: record.createdDate, to: Date()).day ?? 0
            return daysSince >= 7
        }
        if hasOldConcern {
            nudges.append(.unresolvedConcern)
        }
        
        return nudges
    }
    
    /// 마지막 접촉으로부터 경과일
    private var daysSinceLastContact: Int? {
        guard let lastDate = person.mostRecentInteractionDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day
    }
    
    /// 접촉 상태에 따른 색상
    private var contactStatusColor: Color {
        guard let days = daysSinceLastContact else {
            return .gray  // 접촉 기록 없음
        }
        
        switch days {
        case 0...7:
            return .green      // 최근 (1주일 이내)
        case 8...14:
            return .mint       // 양호 (2주 이내)
        case 15...21:
            return .yellow     // 주의 (3주 이내)
        case 22...30:
            return .orange     // 경고 (1달 이내)
        default:
            return .red        // 위험 (1달 초과)
        }
    }

    // 날짜를 상대적인 시간으로 포맷팅
    private func formatRelativeDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    @ViewBuilder
    private var profileImageView: some View {
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

    @ViewBuilder
    private var profileImagePreview: some View {
        VStack(spacing: 12) {
            if let imageData = person.profileImageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 300, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(person.name)
                .font(.headline)
        }
        .padding()
    }

    var body: some View {
        HStack(spacing: 10) {
            // 접촉 상태 인디케이터 (왼쪽 바)
            RoundedRectangle(cornerRadius: 2)
                .fill(contactStatusColor)
                .frame(width: 4)
            
            // 프로필 이미지 (클릭하면 프리뷰)
            profileImageView
                .frame(width: 36, height: 36)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(contactStatusColor.opacity(0.5), lineWidth: 2)
                )
                .onTapGesture {
                    if person.profileImageData != nil {
                        showingImagePreview = true
                    }
                }
                .popover(isPresented: $showingImagePreview, arrowEdge: .trailing) {
                    profileImagePreview
                }

            VStack(alignment: .leading, spacing: 3) {
                // 이름
                Text(person.name)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                // 마지막 접촉일 (시각적으로 강조)
                HStack(spacing: 4) {
                    if let lastDate = person.mostRecentInteractionDate {
                        Text(formatRelativeDate(lastDate))
                            .font(.system(size: 11))
                            .foregroundStyle(contactStatusColor)
                    } else {
                        Text("기록 없음")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // 넛지 뱃지들
            HStack(spacing: 6) {
                ForEach(activeNudges.prefix(3)) { nudge in
                    Text(Image(systemName: nudge.icon))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(
                            Circle()
                                .fill(nudge.color)
                        )
                        .help(nudge.tooltip)
                }
            }
        }
        .padding(.vertical, 6)
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
