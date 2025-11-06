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
    @State private var searchText = ""
    @State private var showingFilter = false
    @State private var filterOptions = FilterOptions()
    
    // 검색 필터링된 사람들
    private var filteredPeople: [Person] {
        var result = people
        
        // 검색 텍스트로 먼저 필터링
        if !searchText.isEmpty {
            result = result.filter { person in
                person.name.localizedCaseInsensitiveContains(searchText) ||
                person.contact.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // 관계 상태 필터
        if !filterOptions.selectedStates.isEmpty {
            result = result.filter { person in
                filterOptions.selectedStates.contains(person.state)
            }
        }
        
        // 소홀 상태 필터
        if filterOptions.showNeglectedOnly {
            result = result.filter { $0.isNeglected }
        }
        
        // 미완료 액션이 있는 사람만
        if filterOptions.showWithIncompleteActionsOnly {
            result = result.filter { person in
                person.actions.contains { !$0.isCompleted }
            }
        }
        
        // 긴급 액션이 있는 사람만
        if filterOptions.showWithCriticalActionsOnly {
            result = result.filter { person in
                let today = Calendar.current.startOfDay(for: Date())
                return person.actions.contains { action in
                    !action.isCompleted &&
                    action.action?.type == .critical &&
                    (action.reminderDate ?? Date.distantFuture) <= today
                }
            }
        }
        
        // 최근 접촉 기준 필터
        if let daysSince = filterOptions.lastContactDays {
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysSince, to: Date()) ?? Date()
            result = result.filter { person in
                guard let lastContact = person.lastContact else {
                    return filterOptions.includeNeverContacted
                }
                return lastContact >= cutoffDate
            }
        }
        
        return result
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    EmptyPeopleView()
                } else {
                    List {
                        ForEach(filteredPeople) { person in
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
                    .searchable(
                        text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .automatic),
                        prompt: "이름이나 연락처로 검색"
                    )
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
                    Button { 
                        showingFilter = true 
                    } label: { 
                        Image(systemName: filterOptions.hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(filterOptions.hasActiveFilters ? .blue : .primary)
                    }
                }
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
            .sheet(isPresented: $showingFilter) {
                PeopleFilterView(filterOptions: $filterOptions, peopleCount: people.count, filteredCount: filteredPeople.count)
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
        for index in offsets { 
            let personToDelete = filteredPeople[index]
            context.delete(personToDelete) 
        }
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
                lastContact: lastContact,
                isNeglected: isNeglected
            )
            context.insert(p)
            
            // 샘플 대화 기록 추가 (읽기 전용 프로퍼티들을 대체)
            if let question = randomQuestion() {
                let _ = p.addConversationRecord(
                    type: .question,
                    content: question,
                    priority: .normal,
                    date: Date().addingTimeInterval(-TimeInterval.random(in: 0...604800)) // 최근 1주일 내
                )
            }
            
            // 미답변 질문들 추가
            let questionCount = Int.random(in: 0...3)
            for i in 0..<questionCount {
                let _ = p.addConversationRecord(
                    type: .question,
                    content: questionPool.randomElement() ?? "질문 \(i+1)",
                    priority: .normal,
                    date: Date().addingTimeInterval(-TimeInterval.random(in: 0...1209600)) // 최근 2주일 내
                )
            }
            
            // 고민사항 추가 (30% 확률)
            if Int.random(in: 0...9) < 3 {
                let concerns = ["새 프로젝트 고민", "이직 고려 중", "건강 관리", "인간관계 스트레스"]
                let _ = p.addConversationRecord(
                    type: .concern,
                    content: concerns.randomElement() ?? "개인적인 고민",
                    priority: .normal,
                    date: Date().addingTimeInterval(-TimeInterval.random(in: 0...2592000)) // 최근 1달 내
                )
            }
            
            // 약속사항 추가 (20% 확률)
            if Int.random(in: 0...9) < 2 {
                let promises = ["추천 서적 알려주기", "맛집 정보 공유", "인맥 소개해주기", "프로젝트 도움주기"]
                let _ = p.addConversationRecord(
                    type: .promise,
                    content: promises.randomElement() ?? "약속한 일",
                    priority: .high,
                    date: Date().addingTimeInterval(-TimeInterval.random(in: 0...1209600)) // 최근 2주일 내
                )
            }
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
    @Bindable var person: Person
    @State private var showingQuickRecord = false

    // 실시간으로 계산되는 완료율
    private var completionRate: Double {
        guard !person.actions.isEmpty else { return 0 }
        let completed = person.actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(person.actions.count)
    }
    
    // 실시간으로 계산되는 관계 분석
    private var relationshipAnalysis: RelationshipAnalysis {
        person.getRelationshipAnalysis()
    }
    
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
        VStack(alignment: .leading, spacing: 12) {
            // 헤더 (이름과 관계 상태)
            headerSection
            
            // 긴급 알림
            if !urgentCriticalActions.isEmpty {
                urgentAlertSection
            }

            // 상호작용 및 정보
            interactionSection
            
            // 관계 건강도
            relationshipHealthSection
            
            // 하단 정보
            footerSection
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .sheet(isPresented: $showingQuickRecord) {
            QuickRecordSheet(person: person)
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(person.name)
                .font(.title)
                .fontWeight(.bold)
            
            Spacer()
            
            relationshipStatusBadge
        }
    }
    
    private var relationshipStatusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(person.state.color)
                .frame(width: 12, height: 12)
            Text(person.state.localizedName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(person.state.color)
        }
    }
    
    private var urgentAlertSection: some View {
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
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    @ViewBuilder
    private var interactionSection: some View {
        let allItems = getInteractionItems()
        
        if !allItems.isEmpty {
            FlowLayout(spacing: 6) {
                ForEach(allItems.indices, id: \.self) { index in
                    allItems[index]
                }
            }
        }
    }
    
    private func getInteractionItems() -> [AnyView] {
        var items: [AnyView] = []
        
        // 상호작용 기록
        if let mentoring = person.lastMentoring {
            items.append(AnyView(Chip(text: "🧑‍🏫 \(relative(mentoring))")))
        }
        
        if let meal = person.lastMeal {
            items.append(AnyView(Chip(text: "🍱 \(relative(meal))")))
        }
        
        if let contact = person.lastContact {
            items.append(AnyView(Chip(text: "📞 \(relative(contact))")))
        }
        
        // 미해결 대화
        if person.currentUnansweredCount > 0 {
            items.append(AnyView(
                Chip(text: "미해결 \(person.currentUnansweredCount)")
                    .foregroundStyle(.orange)
            ))
        }
        
        // 관계 소홀 상태
        if person.isNeglected {
            items.append(AnyView(
                Chip(text: "⚠️ 소홀함")
                    .foregroundStyle(.red)
            ))
        }
        
        // 고민과 약속
        if !person.currentConcerns.isEmpty {
            items.append(AnyView(
                Chip(text: "🧠 고민")
                    .foregroundStyle(.purple)
            ))
        }
        
        if !person.currentUnresolvedPromises.isEmpty {
            items.append(AnyView(
                Chip(text: "🤝 약속")
                    .foregroundStyle(.red)
            ))
        }
        
        if !person.allReceivedQuestions.isEmpty {
            items.append(AnyView(
                Chip(text: "❓ 질문받음")
                    .foregroundStyle(.blue)
            ))
        }
        
        return items
    }
    

    
    private var relationshipHealthSection: some View {
        let analysis = relationshipAnalysis
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.body)
                    .foregroundStyle(.blue)
                
                Text("관계 건강도")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
                
                Spacer()
                
                Text("\(Int(analysis.currentScore))%")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(progressColor(for: analysis.currentScore))
            }
            
            ProgressView(value: analysis.currentScore, total: 100)
                .tint(progressColor(for: analysis.currentScore))
                .scaleEffect(y: 0.8)
            
            if !analysis.recommendations.isEmpty {
                Text(analysis.recommendations.first ?? "")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(10)
    }
    
    private func progressColor(for score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
    
    private var footerSection: some View {
        HStack {
            if let lastContact = person.lastContact {
                Text("마지막 접촉: \(relative(lastContact))")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
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
        
        self._recentConcerns = State(initialValue: person.currentConcerns.first ?? "")
        self._receivedQuestions = State(initialValue: person.allReceivedQuestions.first ?? "")
        self._unresolvedPromises = State(initialValue: person.currentUnresolvedPromises.first ?? "")
        self._unansweredCount = State(initialValue: person.currentUnansweredCount)
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
        // 새로운 대화 기록 시스템을 사용하여 저장
        
        // 고민사항 저장
        let trimmedConcerns = recentConcerns.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedConcerns.isEmpty {
            let _ = person.addConversationRecord(
                type: .concern,
                content: trimmedConcerns,
                priority: .normal,
                date: Date()
            )
            context.insert(person.conversationRecords.last!)
        }
        
        // 받은 질문 저장
        let trimmedQuestions = receivedQuestions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuestions.isEmpty {
            let _ = person.addConversationRecord(
                type: .question,
                content: trimmedQuestions,
                priority: .normal,
                date: Date()
            )
            context.insert(person.conversationRecords.last!)
        }
        
        // 미해결 약속 저장
        let trimmedPromises = unresolvedPromises.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPromises.isEmpty {
            let _ = person.addConversationRecord(
                type: .promise,
                content: trimmedPromises,
                priority: .high,
                date: Date()
            )
            context.insert(person.conversationRecords.last!)
        }
        
        // 소홀함 플래그 저장
        person.isNeglected = isNeglected
        
        // 연락 날짜 저장
        if hasContactDate {
            person.lastContact = lastContact
        }
        
        // 관계 상태 업데이트
        person.updateRelationshipState()
        
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



struct PersonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingVoiceRecorder = false
    @State private var showingAddCriticalAction = false
    @State private var showingInteractionEdit = false
    @State private var selectedInteractionType: InteractionType?
    @State private var isMeetingRecordsExpanded = true
    
    // 대화/상태 입력을 위한 State 변수들
    @State private var newConcern = ""
    @State private var newQuestion = ""
    @State private var newPromise = ""

    @Bindable var person: Person

    init(person: Person) {
        self._person = Bindable(person)
    }
    
    var body: some View {
        Form {
            // 상호작용 섹션
            recentInteractionsSection
            
            // 액션 섹션들
            quickActionsSection
            meetingRecordsSection
            
            // 상태
            relationshipStatusSection
            conversationStateSection
            
            // 도움
            actionChecklistSection
            criticalActionsSection
            
            // 정보 섹션들
            knowledgeSection
            
            
            // 기본 정보
            basicInfoSection
        }
        .navigationTitle(person.name)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingVoiceRecorder) {
            VoiceRecorderView(person: person)
        }
        .sheet(isPresented: $showingAddCriticalAction) {
            AddCriticalActionSheet(person: person)
        }
        .sheet(isPresented: $showingInteractionEdit) {
            if let selectedType = selectedInteractionType,
               let latestRecord = person.getInteractionRecords(ofType: selectedType).first {
                EditInteractionRecordSheet(record: latestRecord)
            }
        }
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var recentInteractionsSection: some View {
        Section {
            RecentInteractionsView(person: person)
        }
    }
    
    @ViewBuilder
    private var quickActionsSection: some View {
        Section {
            voiceRecorderButton
        }
    }
    
    @ViewBuilder
    private var voiceRecorderButton: some View {
        Button {
            showingVoiceRecorder = true
        } label: {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 4) {
                    Text("오늘의 만남 녹음하기")
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
    }
    

    
    @ViewBuilder
    private var actionChecklistSection: some View {
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
                    
                    if let completionRate = calculateCompletionRate() {
                        Text("\(Int(completionRate * 100))%")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var criticalActionsSection: some View {
        Section("⚠️ 놓치면 안되는 것들") {
            ForEach(getCriticalActions(), id: \.id) { personAction in
                CriticalActionReminderRow(personAction: personAction)
            }
            
            addCriticalActionButton
            
            if getCriticalActions().isEmpty {
                emptyCriticalActionsMessage
            }
        }
    }
    
    @ViewBuilder
    private var addCriticalActionButton: some View {
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
    }
    
    @ViewBuilder
    private var emptyCriticalActionsMessage: some View {
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
    
    @ViewBuilder
    private var knowledgeSection: some View {
        if !getCompletedTrackingActions().isEmpty {
            Section("📝 알게 된 정보") {
                ForEach(getCompletedTrackingActions(), id: \.id) { personAction in
                    if let action = personAction.action, !personAction.context.isEmpty {
                        KnowledgeItemView(personAction: personAction, action: action)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var meetingRecordsSection: some View {
        if !person.meetingRecords.isEmpty {
            Section {
                // 섹션 헤더 버튼 (확장/축소)
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isMeetingRecordsExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Text("💬 만남 기록")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("(\(person.meetingRecords.count)개)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Spacer()
                        
                        Image(systemName: isMeetingRecordsExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                
                // 확장된 상태일 때만 기록들을 표시
                if isMeetingRecordsExpanded {
                    ForEach(person.meetingRecords.sorted(by: { $0.date > $1.date }).prefix(5), id: \.id) { record in
                        MeetingRecordRowView(record: record)
                    }
                    
                    if person.meetingRecords.count > 5 {
                        NavigationLink("모든 기록 보기 (\(person.meetingRecords.count)개)") {
                            AllMeetingRecordsView(person: person)
                        }
                    }
                } else {
                    // 축소된 상태일 때는 간단한 요약만 표시
                    HStack {
                        Text("가장 최근: ")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if let latestRecord = person.meetingRecords.sorted(by: { $0.date > $1.date }).first {
                            Text(latestRecord.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("탭해서 펼치기")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isMeetingRecordsExpanded = true
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var basicInfoSection: some View {
        Section("기본 정보") {
            TextField("이름", text: $person.name)
            TextField("연락처", text: $person.contact)
        }
    }
    
    @ViewBuilder
    private var relationshipStatusSection: some View {
        Section("상태") {
            RelationshipAnalysisCard(person: person)
            
        }
    }
    

    

    
    @ViewBuilder
    private var conversationStateSection: some View {
        Section("대화/상태") {
            // 현재 미해결 대화 수 표시
            HStack {
                Text("미해결 대화:")
                Spacer()
                Text("\(person.currentUnansweredCount)개")
                    .foregroundStyle(.secondary)
            }
            
            // 소홀함 토글
            Toggle("관계가 소홀함", isOn: $person.isNeglected)
            
            // 새로운 고민 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("새 고민 추가")
                    .font(.headline)
                    .foregroundStyle(.purple)
                
                TextField("이 사람이 최근에 고민하고 있는 것은?", text: $newConcern, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                
                if !newConcern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("고민 기록하기") {
                        addConversationRecord(type: .concern, content: newConcern)
                        newConcern = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                }
            }
            
            // 새로운 질문 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("받은 질문 추가")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                TextField("이 사람에게 받은 질문이나 요청사항은?", text: $newQuestion, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                
                if !newQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("질문 기록하기") {
                        addConversationRecord(type: .question, content: newQuestion)
                        newQuestion = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            
            // 새로운 약속 입력
            VStack(alignment: .leading, spacing: 8) {
                Text("새 약속 추가")
                    .font(.headline)
                    .foregroundStyle(.red)
                
                TextField("아직 지키지 못한 약속이나 해야 할 일은?", text: $newPromise, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(2...4)
                
                if !newPromise.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Button("약속 기록하기") {
                        addConversationRecord(type: .promise, content: newPromise)
                        newPromise = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            
            // 현재 대화 기록들 표시
            if person.hasConversationRecords {
                Divider()
                
                Text("현재 기록된 내용")
                    .font(.headline)
                    .padding(.top)
                
                // 현재 고민들
                if !person.currentConcerns.isEmpty {
                    ConversationRecordsList(
                        title: "고민",
                        icon: "🧠",
                        color: .purple,
                        records: person.getConversationRecords(ofType: .concern).filter { !$0.isResolved }
                    )
                }
                
                // 현재 질문들
                if !person.allReceivedQuestions.isEmpty {
                    ConversationRecordsList(
                        title: "질문",
                        icon: "❓",
                        color: .blue,
                        records: person.getConversationRecords(ofType: .question).filter { !$0.isResolved }
                    )
                }
                
                // 현재 약속들
                if !person.currentUnresolvedPromises.isEmpty {
                    ConversationRecordsList(
                        title: "약속",
                        icon: "🤝",
                        color: .red,
                        records: person.getConversationRecords(ofType: .promise).filter { !$0.isResolved }
                    )
                }
            }
        }
    }
    



    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Menu {
                quickRecordMenuItems
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .accessibilityLabel("빠른 액션")
        }
    }
    
    @ViewBuilder
    private var quickRecordMenuItems: some View {
        Button {
            person.addInteractionRecord(type: .mentoring, date: Date())
            person.updateRelationshipState()
            try? context.save()
        } label: {
            Label("멘토링 지금 기록", systemImage: "person.badge.clock")
        }
        
        Button {
            person.addInteractionRecord(type: .meal, date: Date())
            person.updateRelationshipState()
            try? context.save()
        } label: {
            Label("식사 지금 기록", systemImage: "fork.knife.circle")
        }
        
        Button {
            person.addInteractionRecord(type: .contact, date: Date())
            person.updateRelationshipState()
            try? context.save()
        } label: {
            Label("접촉 지금 기록", systemImage: "bubble.left")
        }
    }
    
    
    // MARK: - Helper Methods
    
    private func addConversationRecord(type: ConversationType, content: String) {
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedContent.isEmpty else { return }
        
        let priority: ConversationPriority = type == .promise ? .high : .normal
        let record = person.addConversationRecord(
            type: type,
            content: trimmedContent,
            priority: priority,
            date: Date()
        )
        context.insert(record)
        
        do {
            try context.save()
            print("✅ \(type.title) 기록 추가 완료")
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ \(type.title) 기록 추가 실패: \(error)")
        }
    }
    
    private func recordQuickInteraction(type: InteractionType) {
        // 새로운 InteractionRecord 생성
        person.addInteractionRecord(type: type, date: Date())
        person.updateRelationshipState()
        try? context.save()
        
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        // 편집 시트는 열지 않고 바로 저장
        print("✅ \(type.title) 빠른 기록 완료")
    }
    
    private func recalculateRelationshipState() {
        do {
            try RelationshipStateManager.shared.updatePersonRelationshipState(person, context: context)
        } catch {
            print("❌ 관계 상태 재계산 실패: \(error)")
        }
    }

    // MARK: - Computed Properties
    
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
                $0.action?.type == .critical && $0.isVisibleInDetail
            }
            .sorted { 
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted
                }
                return ($0.action?.order ?? 0) < ($1.action?.order ?? 0)
            }
    }
}

// MARK: - ConversationRecordsList
struct ConversationRecordsList: View {
    let title: String
    let icon: String
    let color: Color
    let records: [ConversationRecord]
    @Environment(\.modelContext) private var context
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(icon) \(title) (\(records.count)개)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                Spacer()
            }
            
            ForEach(records.prefix(3), id: \.id) { record in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.content)
                            .font(.body)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Text(record.relativeDate)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            
                            if record.priority == .high || record.priority == .urgent {
                                Text(record.priority.emoji)
                                    .font(.caption2)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        // 해결됨으로 표시
                        record.isResolved = true
                        try? context.save()
                        
                        // 햅틱 피드백
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } label: {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(color)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(color.opacity(0.1))
                .cornerRadius(8)
            }
            
            if records.count > 3 {
                Text("외 \(records.count - 3)개 더 있음")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
        }
    }
}

// MARK: - Helper Views

struct KnowledgeItemView: View {
    let personAction: PersonAction
    let action: RapportAction
    
    var body: some View {
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
            
            if let completedDate = personAction.completedDate {
                Text("완료: \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MeetingRecordRowView: View {
    let record: MeetingRecord
    
    var body: some View {
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

struct EditableConversationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct ConversationCard: View {
    let icon: String
    let title: String
    let content: String?
    let color: Color
    
    var body: some View {
        if let content = content, !content.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
            }
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
    
    // 기본 상호작용 타입들 (호환성을 위해)
    private let basicTypes: [InteractionType] = [.mentoring, .meal, .contact]
    
    // 최근 상호작용들을 날짜순으로 정렬 (새로운 InteractionRecord 기반)
    private var sortedInteractions: [InteractionRecord] {
        return person.getAllInteractionRecordsSorted().prefix(6).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 히스토리 보기 헤더
            HStack {
                Text("상호작용")
                    .font(.body)
                
                Spacer()
                
                Button {
                    showingHistory = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.body)
                        Text("전체 기록 보기")
                            .font(.body)
                    }
                    .foregroundStyle(.blue)
                }
            }
            
            // 가로 스크롤 카드들 (최근 6개만)
            if !sortedInteractions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sortedInteractions, id: \.id) { record in
                            InteractionRecordCard(
                                record: record,
                                onTap: {
                                    showingEditSheet = true
                                    // 편집을 위해 record를 설정해야 함
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("아직 상호작용 기록이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // 빠른 액션 버튼들
            VStack(spacing: 8) {
                Text("빠른 기록")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(basicTypes, id: \.self) { type in
                        Button {
                            // "지금" 기록 후 편집 시트 열기
                            person.addInteractionRecord(type: type, date: Date())
                            person.updateRelationshipState()
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
                                    .font(.body)
                                Text("지금")
                                    .font(.body)
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
            if let interactionType = interactionToEdit,
               let latestRecord = person.getInteractionRecords(ofType: interactionType).first {
                EditInteractionRecordSheet(record: latestRecord)
            }
        }
        .sheet(isPresented: $showingHistory) {
            InteractionHistoryView(person: person)
        }
    }
}

// MARK: - InteractionRecordCard
struct InteractionRecordCard: View {
    let record: InteractionRecord
    let onTap: () -> Void
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.date, relativeTo: .now)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 이모지와 타이틀
                VStack(spacing: 4) {
                    Text(record.type.emoji)
                        .font(.largeTitle)
                    
                    Text(record.type.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(record.type.color)
                }
                
                // 상대적 시간
                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(record.isRecent ? .green : .secondary)
                    .fontWeight(record.isRecent ? .semibold : .regular)
                
                // 정확한 날짜
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                // 내용 표시 (있는 경우)
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                } else if let location = record.location, !location.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding()
            .frame(width: 120, height: (record.notes?.isEmpty == false || record.location?.isEmpty == false) ? 160 : 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(record.isRecent ? record.type.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(record.isRecent ? record.type.color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - InteractionHistoryView
struct InteractionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    
    // 필터링 옵션
    enum FilterOption: String, CaseIterable {
        case all = "전체"
        case mentoring = "멘토링"
        case meal = "식사"
        case contact = "연락"
        
        var interactionType: InteractionType? {
            switch self {
            case .all: return nil
            case .mentoring: return .mentoring
            case .meal: return .meal
            case .contact: return .contact
            }
        }
        
        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .mentoring: return "person.badge.clock"
            case .meal: return "fork.knife"
            case .contact: return "bubble.left"
            }
        }
    }
    
    @State private var selectedFilter: FilterOption = .all
    
    // 필터링된 상호작용 기록들
    private var filteredInteractionRecords: [InteractionRecord] {
        let allRecords = person.getAllInteractionRecordsSorted()
        
        guard let filterType = selectedFilter.interactionType else {
            return allRecords
        }
        
        return allRecords.filter { record in
            // contact 필터의 경우 contact, call, message 모두 포함
            if filterType == .contact {
                return [.contact, .call, .message].contains(record.type)
            }
            return record.type == filterType
        }
    }
    
    // 타입별로 그룹화된 기록들
    private var groupedRecords: [(InteractionType, [InteractionRecord])] {
        let records = filteredInteractionRecords
        let grouped = Dictionary(grouping: records) { $0.type }
        
        // 순서를 유지하면서 반환
        return InteractionType.allCases.compactMap { type in
            guard let typeRecords = grouped[type], !typeRecords.isEmpty else { return nil }
            return (type, typeRecords)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 세그먼트 컨트롤
                VStack(spacing: 12) {
                    Picker("필터", selection: $selectedFilter) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 선택된 필터의 통계 정보
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(filteredInteractionRecords.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Text("총 기록")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if selectedFilter != .all {
                            VStack(spacing: 4) {
                                if let mostRecentRecord = filteredInteractionRecords.first {
                                    Text(mostRecentRecord.relativeDate)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                    Text("최근 기록")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("없음")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Text("최근 기록")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
                
                // 내용 영역
                if filteredInteractionRecords.isEmpty {
                    // 빈 상태 표시
                    VStack(spacing: 20) {
                        Image(systemName: selectedFilter.systemImage)
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("\(selectedFilter.rawValue) 기록이 없어요")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(selectedFilter == .all 
                             ? "멘토링, 식사, 연락 등의 기록을 추가해보세요." 
                             : "\(selectedFilter.rawValue) 기록을 추가해보세요.")
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
                        if selectedFilter == .all {
                            // 전체 보기: 타입별로 그룹화하여 섹션으로 표시
                            ForEach(groupedRecords, id: \.0) { interactionType, records in
                                Section(header: SectionHeaderView(type: interactionType)) {
                                    ForEach(records, id: \.id) { record in
                                        InteractionRecordRow(record: record)
                                    }
                                }
                            }
                        } else {
                            // 특정 타입 보기: 날짜순으로 단순 나열
                            Section {
                                ForEach(filteredInteractionRecords, id: \.id) { record in
                                    InteractionRecordRow(record: record)
                                }
                            } header: {
                                if let filterType = selectedFilter.interactionType {
                                    SectionHeaderView(type: filterType)
                                }
                            }
                        }
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
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
    }
}

// MARK: - SectionHeaderView
struct SectionHeaderView: View {
    let type: InteractionType
    
    var body: some View {
        HStack(spacing: 8) {
            Text(type.emoji)
                .font(.title3)
            Text(type.title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - InteractionRecordRow
struct InteractionRecordRow: View {
    let record: InteractionRecord
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: record.date, relativeTo: .now)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 타입 아이콘 및 색상
            VStack {
                Circle()
                    .fill(record.type.color)
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(record.type.color.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(record.type.title)
                        .font(.headline)
                        .foregroundStyle(record.type.color)
                    
                    if record.isRecent {
                        Text("최근")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                }
                
                Text(relativeDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                // 추가 정보들
                VStack(alignment: .leading, spacing: 4) {
                    if let duration = record.formattedDuration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("지속 시간: \(duration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let location = record.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("장소: \(location)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let notes = record.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(record.type.color.opacity(0.1))
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            VStack {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(record.type.color)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    withAnimation {
                        context.delete(record)
                        try? context.save()
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingEditSheet) {
            EditInteractionRecordSheet(record: record)
        }
    }
}

// MARK: - EditInteractionRecordSheet
struct EditInteractionRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var record: InteractionRecord
    @State private var tempDate: Date
    @State private var tempNotes: String
    @State private var tempLocation: String
    @State private var tempDuration: TimeInterval?
    @State private var hasDuration: Bool
    
    init(record: InteractionRecord) {
        self.record = record
        self._tempDate = State(initialValue: record.date)
        self._tempNotes = State(initialValue: record.notes ?? "")
        self._tempLocation = State(initialValue: record.location ?? "")
        self._tempDuration = State(initialValue: record.duration)
        self._hasDuration = State(initialValue: record.duration != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    HStack {
                        Text(record.type.emoji)
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.type.title)
                                .font(.headline)
                            Text("상호작용 기록을 편집해주세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("날짜 및 시간") {
                    DatePicker("날짜와 시간", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("장소") {
                    TextField("어디서 만났나요?", text: $tempLocation)
                }
                
                Section("지속 시간") {
                    Toggle("지속 시간 기록", isOn: $hasDuration)
                    
                    if hasDuration {
                        HStack {
                            Text("시간:")
                            Spacer()
                            HStack {
                                TextField("시간", value: Binding(
                                    get: { Int((tempDuration ?? 0) / 3600) },
                                    set: { newValue in 
                                        let hours = TimeInterval(newValue)
                                        let minutes = (tempDuration ?? 0).truncatingRemainder(dividingBy: 3600) / 60
                                        tempDuration = hours * 3600 + minutes * 60
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                
                                Text("시간")
                                
                                TextField("분", value: Binding(
                                    get: { Int(((tempDuration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                                    set: { newValue in 
                                        let hours = (tempDuration ?? 0) / 3600
                                        let minutes = TimeInterval(newValue)
                                        tempDuration = hours * 3600 + minutes * 60
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                
                                Text("분")
                            }
                        }
                    }
                }
                
                Section("메모") {
                    TextField("이번 \(record.type.title)에서 어떤 이야기를 나눴나요?", text: $tempNotes, axis: .vertical)
                        .lineLimit(3...8)
                        .autocorrectionDisabled(false)
                }
                
                Section("미리보기") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(record.type.emoji)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.type.title)
                                    .font(.headline)
                                    .foregroundStyle(record.type.color)
                                
                                Text(tempDate.formatted(date: .long, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if !tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(tempLocation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if hasDuration, let duration = tempDuration, duration > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                let minutes = Int(duration) / 60
                                let hours = minutes / 60
                                let remainingMinutes = minutes % 60
                                if hours > 0 {
                                    Text("\(hours)시간 \(remainingMinutes)분")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(minutes)분")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        if !tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Divider()
                            Text(tempNotes)
                                .font(.body)
                                .foregroundStyle(.primary)
                                .padding(.top, 2)
                        }
                    }
                    .padding()
                    .background(record.type.color.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .navigationTitle("상호작용 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
        }
        .onDisappear {
            if !hasDuration {
                tempDuration = nil
            }
        }
    }
    
    private func saveChanges() {
        record.date = tempDate
        record.notes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.location = tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        record.duration = hasDuration ? tempDuration : nil
        
        // 기존 lastXXX 필드도 업데이트 (최신 기록인 경우에만)
        if let person = record.person {
            let sameTypeRecords = person.getInteractionRecords(ofType: record.type)
            if sameTypeRecords.first?.id == record.id {
                // 이것이 해당 타입의 가장 최근 기록이면 lastXXX 업데이트
                switch record.type {
                case .mentoring:
                    person.lastMentoring = record.date
                    person.mentoringNotes = record.notes
                case .meal:
                    person.lastMeal = record.date
                    person.mealNotes = record.notes
                case .contact, .call, .message:
                    person.lastContact = record.date
                    person.contactNotes = record.notes
                case .meeting:
                    break
                }
            }
            
            // 관계 상태 업데이트
            person.updateRelationshipState()
        }
        
        do {
            try context.save()
            print("✅ 상호작용 기록 수정 완료")
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ 상호작용 기록 수정 실패: \(error)")
        }
    }
}





// MARK: - EditInteractionSheet (레거시 호환성을 위해 유지)
struct EditInteractionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var person: Person
    let interactionType: InteractionType
    
    @State private var selectedDate: Date
    @State private var hasDate: Bool
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var duration: TimeInterval?
    @State private var hasDuration: Bool = false
    
    init(person: Person, interactionType: InteractionType) {
        self.person = person
        self.interactionType = interactionType
        
        // 기존 기록이 있으면 그것을 기준으로, 없으면 현재 시간
        let existingRecord = person.getInteractionRecords(ofType: interactionType).first
        let currentDate = existingRecord?.date ?? Date()
        self._selectedDate = State(initialValue: currentDate)
        self._hasDate = State(initialValue: existingRecord != nil)
        
        // 기존 데이터 로드
        self._notes = State(initialValue: existingRecord?.notes ?? "")
        self._location = State(initialValue: existingRecord?.location ?? "")
        self._duration = State(initialValue: existingRecord?.duration)
        self._hasDuration = State(initialValue: existingRecord?.duration != nil)
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
                
                Section("장소") {
                    TextField("어디서 만났나요?", text: $location)
                }
                
                Section("지속 시간") {
                    Toggle("지속 시간 기록", isOn: $hasDuration)
                    
                    if hasDuration {
                        HStack {
                            Text("시간:")
                            Spacer()
                            HStack {
                                TextField("시간", value: Binding(
                                    get: { Int((duration ?? 0) / 3600) },
                                    set: { newValue in 
                                        let hours = TimeInterval(newValue)
                                        let minutes = (duration ?? 0).truncatingRemainder(dividingBy: 3600) / 60
                                        duration = hours * 3600 + minutes * 60
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                
                                Text("시간")
                                
                                TextField("분", value: Binding(
                                    get: { Int(((duration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                                    set: { newValue in 
                                        let hours = (duration ?? 0) / 3600
                                        let minutes = TimeInterval(newValue)
                                        duration = hours * 3600 + minutes * 60
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                
                                Text("분")
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
                    Section("기록 삭제") {
                        Button("이 기록 삭제", role: .destructive) {
                            deleteRecord()
                            dismiss()
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
            // 새로운 InteractionRecord 생성 또는 업데이트
            let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
            
            person.addInteractionRecord(
                type: interactionType,
                date: selectedDate,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                duration: hasDuration ? duration : nil,
                location: trimmedLocation.isEmpty ? nil : trimmedLocation
            )
            person.updateRelationshipState()
        } else {
            // 기록 삭제
            deleteRecord()
            person.updateRelationshipState()
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
    
    private func deleteRecord() {
        // 해당 타입의 기록들을 삭제
        let recordsToDelete = person.getInteractionRecords(ofType: interactionType)
        for record in recordsToDelete {
            context.delete(record)
        }
        
        // 기존 lastXXX 필드도 클리어
        switch interactionType {
        case .mentoring:
            person.lastMentoring = nil
            person.mentoringNotes = nil
        case .meal:
            person.lastMeal = nil
            person.mealNotes = nil
        case .contact:
            person.lastContact = nil
            person.contactNotes = nil
        case .call, .message:
            person.lastContact = nil
            person.contactNotes = nil
        case .meeting:
            break
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
                    
                    // 관계 상태 즉시 업데이트
                    personAction.person?.updateRelationshipState()
                    
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

// MARK: - FilterOptions
@Observable
class FilterOptions {
    var selectedStates: Set<RelationshipState> = []
    var showNeglectedOnly = false
    var showWithIncompleteActionsOnly = false
    var showWithCriticalActionsOnly = false
    var lastContactDays: Int? = nil
    var includeNeverContacted = true
    
    var hasActiveFilters: Bool {
        !selectedStates.isEmpty ||
        showNeglectedOnly ||
        showWithIncompleteActionsOnly ||
        showWithCriticalActionsOnly ||
        lastContactDays != nil
    }
    
    func reset() {
        selectedStates.removeAll()
        showNeglectedOnly = false
        showWithIncompleteActionsOnly = false
        showWithCriticalActionsOnly = false
        lastContactDays = nil
        includeNeverContacted = true
    }
}

// MARK: - PeopleFilterView
struct PeopleFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterOptions: FilterOptions
    let peopleCount: Int
    let filteredCount: Int
    
    var body: some View {
        NavigationStack {
            Form {
                // 결과 요약
                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("전체: \(peopleCount)명")
                                .font(.headline)
                            Text("필터링된 결과: \(filteredCount)명")
                                .font(.subheadline)
                                .foregroundStyle(filteredCount < peopleCount ? .blue : .secondary)
                        }
                        
                        Spacer()
                        
                        if filterOptions.hasActiveFilters {
                            Button("모두 해제") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    filterOptions.reset()
                                }
                            }
                            .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // 관계 상태 필터
                Section("관계 상태") {
                    ForEach(RelationshipState.allCases, id: \.self) { state in
                        HStack {
                            Text(state.emoji)
                                .font(.title3)
                            
                            Text(state.localizedName)
                                .font(.body)
                            
                            Spacer()
                            
                            if filterOptions.selectedStates.contains(state) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                if filterOptions.selectedStates.contains(state) {
                                    filterOptions.selectedStates.remove(state)
                                } else {
                                    filterOptions.selectedStates.insert(state)
                                }
                            }
                        }
                    }
                }
                
                // 특별 조건 필터
                Section("특별 조건") {
                    Toggle("소홀한 관계만 보기", isOn: $filterOptions.showNeglectedOnly)
                        .tint(.orange)
                    
                    Toggle("미완료 액션이 있는 사람만", isOn: $filterOptions.showWithIncompleteActionsOnly)
                        .tint(.blue)
                    
                    Toggle("긴급 액션이 있는 사람만", isOn: $filterOptions.showWithCriticalActionsOnly)
                        .tint(.red)
                }
                
                // 최근 접촉 기준
                Section("최근 접촉 기준") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("최근 접촉:")
                            Spacer()
                            if let days = filterOptions.lastContactDays {
                                Text("\(days)일 이내")
                                    .foregroundStyle(.blue)
                            } else {
                                Text("모든 기간")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        // 빠른 선택 버튼들
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach([7, 14, 30, 60, 90], id: \.self) { days in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        filterOptions.lastContactDays = (filterOptions.lastContactDays == days) ? nil : days
                                    }
                                } label: {
                                    Text("\(days)일")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(
                                            filterOptions.lastContactDays == days 
                                                ? Color.blue 
                                                : Color(.systemGray5)
                                        )
                                        .foregroundStyle(
                                            filterOptions.lastContactDays == days 
                                                ? .white 
                                                : .primary
                                        )
                                        .cornerRadius(16)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    filterOptions.lastContactDays = nil
                                }
                            } label: {
                                Text("전체")
                                    .font(.caption)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        filterOptions.lastContactDays == nil 
                                            ? Color.blue 
                                            : Color(.systemGray5)
                                    )
                                    .foregroundStyle(
                                        filterOptions.lastContactDays == nil 
                                            ? .white 
                                            : .primary
                                    )
                                    .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if filterOptions.lastContactDays != nil {
                            Toggle("연락 기록이 없는 사람도 포함", isOn: $filterOptions.includeNeverContacted)
                                .font(.caption)
                                .tint(.gray)
                        }
                    }
                }
                
                // 필터 프리셋
                Section("빠른 필터") {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterOptions.reset()
                            filterOptions.showNeglectedOnly = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundStyle(.orange)
                            Text("소홀한 관계들")
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterOptions.reset()
                            filterOptions.showWithCriticalActionsOnly = true
                        }
                    } label: {
                        HStack {
                            Image(systemName: "alarm")
                                .foregroundStyle(.red)
                            Text("긴급 처리 필요")
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterOptions.reset()
                            filterOptions.lastContactDays = 14
                            filterOptions.includeNeverContacted = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark")
                                .foregroundStyle(.blue)
                            Text("최근 2주간 접촉")
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            filterOptions.reset()
                            filterOptions.selectedStates.insert(.close)
                        }
                    } label: {
                        HStack {
                            Text("❤️")
                                .font(.body)
                            Text("가까운 관계들")
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
            .navigationTitle("필터 설정")
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
}

// MARK: - FlowLayout
struct FlowLayout: Layout {
    let spacing: CGFloat
    
    init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        
        for (index, subview) in subviews.enumerated() {
            let position = CGPoint(
                x: bounds.minX + result.positions[index].x,
                y: bounds.minY + result.positions[index].y
            )
            subview.place(at: position, proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        let size: CGSize
        let positions: [CGPoint]
        
        init(in maxWidth: CGFloat, subviews: Layout.Subviews, spacing: CGFloat) {
            var positions: [CGPoint] = []
            var currentY: CGFloat = 0
            var currentX: CGFloat = 0
            var lineHeight: CGFloat = 0
            var totalHeight: CGFloat = 0
            
            for subview in subviews {
                let subviewSize = subview.sizeThatFits(.unspecified)
                
                // 현재 줄에 들어갈 수 없다면 다음 줄로
                if currentX + subviewSize.width > maxWidth && currentX > 0 {
                    currentY += lineHeight + spacing
                    currentX = 0
                    lineHeight = 0
                }
                
                positions.append(CGPoint(x: currentX, y: currentY))
                
                currentX += subviewSize.width + spacing
                lineHeight = max(lineHeight, subviewSize.height)
                totalHeight = max(totalHeight, currentY + subviewSize.height)
            }
            
            self.positions = positions
            self.size = CGSize(width: maxWidth, height: totalHeight)
        }
    }
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
    @Bindable var person: Person
    @State private var showingDetailedAnalysis = false
    
    // 실시간으로 계산되는 analysis
    private var analysis: RelationshipAnalysis {
        person.getRelationshipAnalysis()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상태 요약
            HStack {
                Text(analysis.currentState.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(analysis.currentState.localizedName)
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
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingDetailedAnalysis) {
            DetailedRelationshipAnalysisView(person: person, analysis: analysis)
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

