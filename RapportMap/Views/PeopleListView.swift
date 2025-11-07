//
//  PeopleListView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/2/25.
//

import SwiftUI
import SwiftData
import UserNotifications
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
                            NavigationLink(destination: PersonDetailView(person: person, selectedTab: .constant(0))) {
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

            let p = Person(
                id: UUID(),
                name: name,
                contact: contact,
                state: state,
                lastMentoring: lastMentoring,
                lastMeal: lastMeal,
                lastContact: lastContact
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

struct PersonCard: View {
    @Bindable var person: Person

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
            items.append(AnyView(Chip(text: "🧑‍🏫 \(mentoring.relative())")))
        }
        
        if let meal = person.lastMeal {
            items.append(AnyView(Chip(text: "🍱 \(meal.relative())")))
        }
        
        if let contact = person.lastContact {
            items.append(AnyView(Chip(text: "📞 \(contact.relative())")))
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
                Text("마지막 접촉: \(lastContact.relative())")
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



