//
//  PersonActionChecklistView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import SwiftUI
import SwiftData
import UserNotifications



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
    @State private var showingUserActions = false // 사용자 추가 액션 표시 여부
    @State private var debugMode = false // 디버그 모드 토글
    
    init(person: Person) {
        self.person = person
        _selectedPhase = State(initialValue: person.currentPhase)
    }
    
    // 이 사람의 액션들을 Phase별로 필터링하고 타입별로 그룹화
    private var actionsForPhase: [PersonAction] {
        // 디버깅용 출력 (디버그 모드에서만)
        if debugMode {
            print("🔍 [DEBUG] person.actions 총 개수: \(person.actions.count)")
            print("🔍 [DEBUG] showingUserActions: \(showingUserActions)")
            print("🔍 [DEBUG] selectedPhase: \(selectedPhase)")
        }
        
        let baseFilter = showingUserActions 
            ? person.actions.filter { 
                let isUserAction = $0.action?.isDefault == false
                if debugMode {
                    print("🔍 [DEBUG] User action check - title: \($0.action?.title ?? "nil"), isDefault: \($0.action?.isDefault ?? true), result: \(isUserAction)")
                }
                return isUserAction
            }
            : person.actions.filter { 
                let isPhaseMatch = $0.action?.phase == selectedPhase
                let isDefaultAction = $0.action?.isDefault == true
                let result = isPhaseMatch && isDefaultAction
                if debugMode {
                    print("🔍 [DEBUG] Phase action check - title: \($0.action?.title ?? "nil"), phase: \($0.action?.phase.rawValue ?? "nil"), isDefault: \($0.action?.isDefault ?? false), result: \(result)")
                }
                return result
            }
        
        if debugMode {
            print("🔍 [DEBUG] baseFilter 결과 개수: \(baseFilter.count)")
        }
        
        return baseFilter
            .sorted { action1, action2 in
                // 1순위: Critical 액션을 우선으로
                if action1.action?.type != action2.action?.type {
                    return (action1.action?.type == .critical) && (action2.action?.type != .critical)
                }
                // 2순위: 완료되지 않은 액션을 우선으로
                if action1.isCompleted != action2.isCompleted {
                    return !action1.isCompleted && action2.isCompleted
                }
                // 3순위: order 순서대로
                return (action1.action?.order ?? 0) < (action2.action?.order ?? 0)
            }
    }
    
    // Critical 액션들만 필터링
    private var criticalActionsForPhase: [PersonAction] {
        actionsForPhase.filter { $0.action?.type == .critical }
    }
    
    // Tracking 액션들만 필터링  
    private var trackingActionsForPhase: [PersonAction] {
        actionsForPhase.filter { $0.action?.type == .tracking }
    }
    
    // 미완료 Critical 액션 개수
    private var incompleteCriticalCount: Int {
        criticalActionsForPhase.filter { !$0.isCompleted }.count
    }
    
    // Phase별 완성도 계산
    private func completionRate(for phase: ActionPhase) -> Double {
        let phaseActions = person.actions.filter { $0.action?.phase == phase }
        guard !phaseActions.isEmpty else { return 0 }
        let completed = phaseActions.filter { $0.isCompleted }.count
        return Double(completed) / Double(phaseActions.count)
    }
    
    // Phase별 미완료 Critical 액션 개수
    private func incompleteCriticalCount(for phase: ActionPhase) -> Int {
        person.actions
            .filter { $0.action?.phase == phase && $0.action?.type == .critical && !$0.isCompleted }
            .count
    }
    
    // 사용자 추가 액션 개수
    private func getUserActionCount() -> Int {
        person.actions.filter { $0.action?.isDefault == false }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Phase 선택기
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ActionPhase.allCases, id: \.self) { phase in
                        let isCurrentPhase = selectedPhase == phase
                        let phaseCompletionRate = completionRate(for: phase)
                        let criticalCount = incompleteCriticalCount(for: phase)
                        let hasAction = criticalCount > 0
                        
                        PhaseButton(
                            phase: phase,
                            isSelected: isCurrentPhase && !showingUserActions,
                            completionRate: phaseCompletionRate,
                            action: {
                                selectedPhase = phase
                                showingUserActions = false
                            },
                            hasCriticalActions: hasAction,
                            incompleteCriticalCount: criticalCount
                        )
                    }
                    
                    // 사용자 추가 액션 버튼 (관계유지 다음에)
                    if ActionPhase.allCases.last == .phase6 {
                        UserActionsButton(
                            isSelected: showingUserActions,
                            userActionCount: getUserActionCount()
                        ) {
                            showingUserActions = true
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
                if showingUserActions {
                    // 사용자 추가 액션들
                    if !actionsForPhase.isEmpty {
                        Section {
                            ForEach(actionsForPhase) { personAction in
                                PersonActionRow(personAction: personAction)
                            }
                            .onDelete { offsets in
                                deleteActions(at: offsets)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .foregroundStyle(.purple)
                                Text("🎯 내가 추가한 중요한 것들")
                                    .fontWeight(.semibold)
                            }
                        } footer: {
                            Text("내가 직접 추가한 중요한 액션들입니다. 왼쪽으로 스와이프하면 삭제할 수 있어요.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Section {
                            VStack(spacing: 16) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.purple)
                                
                                Text("아직 추가한 액션이 없어요")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                Text("+ 버튼을 눌러 이 사람과의 관계에서 중요한 것들을 추가해보세요")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
                } else {
                    // 기본 액션들 (기존 로직)
                    // 중요한 액션들이 있을 때 우선 표시
                    if !criticalActionsForPhase.isEmpty {
                        Section {
                            ForEach(criticalActionsForPhase) { personAction in
                                PersonActionRow(personAction: personAction)
                            }
                            .onDelete { offsets in
                                deleteActions(from: criticalActionsForPhase, at: offsets)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("🚨 놓치면 안 되는 중요한 일들")
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if incompleteCriticalCount > 0 {
                                    Text("\(incompleteCriticalCount)개 남음")
                                        .font(.caption)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .clipShape(Capsule())
                                }
                            }
                        } footer: {
                            Text("중요한 액션들입니다. 완료하지 않으면 관계에 영향을 줄 수 있어요. 눈 모양 버튼을 눌러 PersonDetailView에 표시하도록 설정하세요.")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                    
                    // 일반 추적/기록용 액션들
                    if !trackingActionsForPhase.isEmpty {
                        Section {
                            ForEach(trackingActionsForPhase) { personAction in
                                PersonActionRow(personAction: personAction)
                            }
                            .onDelete { offsets in
                                deleteActions(from: trackingActionsForPhase, at: offsets)
                            }
                        } header: {
                            HStack {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundStyle(.blue)
                                Text("📝 알아두면 좋은 정보들")
                                    .fontWeight(.medium)
                            }
                        } footer: {
                            Text("이 사람에 대해 더 잘 알기 위한 정보 수집 액션들이에요. 왼쪽으로 스와이프하면 삭제할 수 있어요.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 액션이 없는 경우
                    if actionsForPhase.isEmpty {
                        Section {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.orange)
                                
                                Text("\(selectedPhase.rawValue) 단계에 액션이 없어요")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                
                                Text("데이터를 불러오는 중이거나 액션이 누락되었을 수 있어요")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                
                                // 디버깅 정보
                                VStack(spacing: 4) {
                                    HStack {
                                        Toggle("디버그 모드", isOn: $debugMode)
                                            .font(.caption)
                                        Spacer()
                                    }
                                    
                                    if debugMode {
                                        Text("전체 액션 수: \(person.actions.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("현재 Phase: \(selectedPhase.rawValue)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("사용자 액션 모드: \(showingUserActions ? "ON" : "OFF")")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text("필터링된 액션 수: \(actionsForPhase.count)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                
                                // 새로고침 버튼
                                Button {
                                    if debugMode {
                                        print("🔄 [DEBUG] 강제 새로고침 버튼 클릭")
                                    }
                                    DataSeeder.seedDefaultActionsIfNeeded(context: context)
                                    DataSeeder.createPersonActionsForNewPerson(person: person, context: context)
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.clockwise")
                                        Text("액션 다시 로드")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue)
                                    .cornerRadius(8)
                                }
                                
                                Text("+ 버튼을 눌러 새로운 액션을 추가할 수도 있어요")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        }
                    }
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
                    ForEach(ActionPhase.allCases, id: \.self) { phase in
                        Button {
                            person.currentPhase = phase
                            do {
                                try context.save()
                            } catch {
                                print("❌ Phase 변경 저장 실패: \(error)")
                            }
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
            if showingUserActions {
                AddCriticalActionSheet(person: person)
            } else {
                AddCustomActionSheet(person: person, phase: selectedPhase)
            }
        }
        .onAppear {
            if debugMode {
                print("🚀 [PersonActionChecklistView] onAppear 시작")
                print("🚀 [DEBUG] Person: \(person.name)")
                print("🚀 [DEBUG] Current Phase: \(person.currentPhase)")
                print("🚀 [DEBUG] Total actions: \(person.actions.count)")
            }
            
            // 액션이 없으면 생성
            if person.actions.isEmpty {
                if debugMode {
                    print("🚀 [DEBUG] 액션이 비어있음 - 새로 생성")
                }
                DataSeeder.createPersonActionsForNewPerson(person: person, context: context)
            } else {
                if debugMode {
                    print("🚀 [DEBUG] 기존 액션들:")
                    for action in person.actions {
                        if let rapportAction = action.action {
                            print("  - \(rapportAction.title) (Phase: \(rapportAction.phase.rawValue), Type: \(rapportAction.type.rawValue), Default: \(rapportAction.isDefault))")
                        } else {
                            print("  - [액션 없음] PersonAction ID: \(action.id)")
                        }
                    }
                }
            }
            
            // DataSeeder에서 기본 액션들도 확인해보자
            Task {
                do {
                    let descriptor = FetchDescriptor<RapportAction>()
                    let allRapportActions = try context.fetch(descriptor)
                    
                    if debugMode {
                        print("🚀 [DEBUG] 전체 RapportAction 개수: \(allRapportActions.count)")
                    }
                    
                    let defaultActions = allRapportActions.filter { $0.isDefault }
                    if debugMode {
                        print("🚀 [DEBUG] 기본 액션 개수: \(defaultActions.count)")
                    }
                    
                    // 만약 기본 액션이 없다면 생성
                    if defaultActions.isEmpty {
                        if debugMode {
                            print("🚀 [DEBUG] 기본 액션이 없음 - DataSeeder 실행")
                        }
                        DataSeeder.seedDefaultActionsIfNeeded(context: context)
                        
                        // 기본 액션 생성 후 PersonAction도 다시 생성
                        DataSeeder.createPersonActionsForNewPerson(person: person, context: context)
                    }
                } catch {
                    if debugMode {
                        print("🚀 [ERROR] RapportAction fetch 실패: \(error)")
                    }
                }
            }
        }
    }
    
    private func deleteActions(at offsets: IndexSet) {
        for index in offsets {
            guard index < actionsForPhase.count else { continue }
            let personAction = actionsForPhase[index]
            context.delete(personAction)
        }
        do {
            try context.save()
        } catch {
            print("❌ PersonAction 삭제 저장 실패: \(error)")
        }
    }
    
    private func deleteActions(from actions: [PersonAction], at offsets: IndexSet) {
        for index in offsets {
            guard index < actions.count else { continue }
            let personAction = actions[index]
            context.delete(personAction)
        }
        do {
            try context.save()
        } catch {
            print("❌ PersonAction 삭제 저장 실패: \(error)")
        }
    }
}

// MARK: - AddCriticalActionSheet (사용자 중요 액션 추가)
struct AddCriticalActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let person: Person
    
    @State private var title = ""
    @State private var description = ""
    @State private var placeholder = ""
    
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
                    Section {
                        TextField("제목", text: $title)
                            .autocorrectionDisabled(true)
                        TextField("설명 (선택)", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("입력 예시 (선택)", text: $placeholder)
                            .autocorrectionDisabled(true)
                    } header: {
                        HStack {
                            Text("🎯")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text("중요한 것들을 추가하세요")
                                    .font(.headline)
                                Text("이 사람과의 관계에서 절대 놓치면 안 되는 것들")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    
                    Section("예시") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("🎂")
                                Text("생일 챙기기")
                                    .fontWeight(.medium)
                            }
                            Text("이 사람의 생일이 언제인지 꼭 기억해야 해요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            HStack {
                                Text("☕️")
                                Text("커피 취향 기억하기")
                                    .fontWeight(.medium)
                            }
                            Text("어떤 음료를 좋아하는지 알아두면 좋아요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Divider()
                            
                            HStack {
                                Text("📞")
                                Text("정기적으로 안부 묻기")
                                    .fontWeight(.medium)
                            }
                            Text("관계 유지를 위해 주기적으로 연락하는 것")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("중요 액션 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addCriticalAction()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addCriticalAction() {
        do {
            // 1. RapportAction 생성 (전역) - 사용자 액션은 phase와 관계없이 항상 접근 가능
            let maxOrder = (try? context.fetch(FetchDescriptor<RapportAction>(
                predicate: #Predicate { !$0.isDefault }
            )))?.map { $0.order }.max() ?? 1000 // 사용자 액션은 1000번대부터 시작
            
            let newAction = RapportAction(
                title: title,
                actionDescription: description,
                phase: .phase1, // 사용자 액션은 phase1에 저장하되, 실제로는 phase와 무관하게 표시됨
                type: .critical, // 사용자가 추가하는 것들은 모두 중요한 것들
                order: maxOrder + 1,
                isDefault: false, // 사용자 커스텀 액션
                isActive: true,
                placeholder: placeholder.isEmpty ? "예: 기억해야 할 내용을 입력하세요" : placeholder
            )
            context.insert(newAction)
            
            // 2. PersonAction 생성 (이 사람용)
            let personAction = PersonAction(
                person: person,
                action: newAction,
                isVisibleInDetail: false // 기본적으로 숨김, 사용자가 눈 버튼으로 표시 설정 가능
            )
            context.insert(personAction)
            
            try context.save()
            print("✅ 사용자 중요 액션 추가됨: \(title)")
        } catch {
            print("❌ 사용자 중요 액션 추가 실패: \(error)")
        }
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
                            .autocorrectionDisabled(true)
                        TextField("설명 (선택)", text: $description, axis: .vertical)
                            .lineLimit(2...4)
                        TextField("입력 예시 (선택)", text: $placeholder)
                            .autocorrectionDisabled(true)
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
        do {
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
                action: newAction,
                isVisibleInDetail: newAction.type == .critical ? false : false // 기본적으로 숨김, 사용자가 선택해서 보이게 할 수 있음
            )
            context.insert(personAction)
            
            try context.save()
            print("✅ 커스텀 액션 추가됨: \(title)")
        } catch {
            print("❌ 커스텀 액션 추가 실패: \(error)")
        }
    }
}

// MARK: - UserActionsButton
struct UserActionsButton: View {
    let isSelected: Bool
    let userActionCount: Int
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Text("🎯")
                        .font(.title2)
                    
                    // 사용자 액션 개수 표시
                    if userActionCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -2, y: 2)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 30)
                
                Text("사용자 추가")
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                // 완성도 바 (항상 보라색)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(Color.purple)
                            .frame(width: userActionCount > 0 ? geometry.size.width * 0.8 : 0)
                    }
                }
                .frame(height: 3)
                
                // 사용자 액션 개수 표시
                if userActionCount > 0 {
                    Text("📝 \(userActionCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.purple.opacity(0.15) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - PhaseButton
struct PhaseButton: View {
    let phase: ActionPhase
    let isSelected: Bool
    let completionRate: Double
    let action: () -> Void
    
    // Phase에 critical 액션이 있는지 확인하기 위한 person 참조 필요
    var hasCriticalActions: Bool = false
    var incompleteCriticalCount: Int = 0
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    Text(phase.emoji)
                        .font(.title2)
                    
                    // Critical 액션이 미완료인 경우 빨간 점 표시
                    if incompleteCriticalCount > 0 {
                        VStack {
                            HStack {
                                Spacer()
                                Circle()
                                    .fill(Color.red)
                                    .frame(width: 8, height: 8)
                                    .offset(x: -2, y: 2)
                            }
                            Spacer()
                        }
                    }
                }
                .frame(height: 30)
                
                Text(phase.rawValue)
                    .font(.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                // 완성도 바
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(
                                incompleteCriticalCount > 0 ? Color.red : // Critical 액션이 미완료면 빨간색
                                completionRate >= 1.0 ? Color.green : Color.blue
                            )
                            .frame(width: geometry.size.width * completionRate)
                    }
                }
                .frame(height: 3)
                
                // Critical 액션 개수 표시
                if incompleteCriticalCount > 0 {
                    Text("⚠️ \(incompleteCriticalCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected 
                        ? (incompleteCriticalCount > 0 ? Color.red.opacity(0.15) : Color.blue.opacity(0.15))
                        : Color.clear
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected 
                        ? (incompleteCriticalCount > 0 ? Color.red : Color.blue)
                        : Color.clear, 
                        lineWidth: 2
                    )
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
                            do {
                                try context.save()
                            } catch {
                                print("❌ PersonAction 완료 취소 저장 실패: \(error)")
                            }
                        } else {
                            // 완료 처리하면서 결과 입력 화면 띄우기
                            showingResultInput = true
                        }
                        
                        // 관계 상태 업데이트 (안전하게)
                        if let person = personAction.person {
                            do {
                                try RelationshipStateManager.shared.updatePersonRelationshipState(person, context: context)
                            } catch {
                                print("❌ 관계 상태 업데이트 실패: \(error)")
                            }
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
                            HStack(spacing: 8) {
                                // 액션 타입별 아이콘
                                if action.type == .critical {
                                    Image(systemName: personAction.isCompleted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                                        .font(.caption)
                                        .foregroundStyle(personAction.isCompleted ? .green : .red)
                                } else {
                                    Image(systemName: personAction.isCompleted ? "chart.line.uptrend.xyaxis" : "chart.line.uptrend.xyaxis.circle")
                                        .font(.caption)
                                        .foregroundStyle(personAction.isCompleted ? .green : .blue)
                                }
                                
                                Text(action.title)
                                    .font(.headline)
                                    .foregroundStyle(
                                        personAction.isCompleted 
                                            ? .secondary
                                            : (action.type == .critical ? .primary : .primary)
                                    )
                                    .strikethrough(
                                        personAction.isCompleted,
                                        color: action.type == .critical ? .orange : .secondary
                                    )
                                    .animation(.easeInOut(duration: 0.3), value: personAction.isCompleted)
                            }
                            
                            Spacer()
                            
                            HStack(spacing: 12) {
                                // 액션 타입 라벨
                                if action.type == .critical {
                                    HStack(spacing: 4) {
                                        Text("🚨")
                                            .font(.caption2)
                                        Text("중요")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(personAction.isCompleted ? .gray : .red)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(personAction.isCompleted ? Color.gray.opacity(0.2) : Color.red.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(personAction.isCompleted ? Color.gray : Color.red, lineWidth: 1)
                                    )
                                } else {
                                    HStack(spacing: 4) {
                                        Text("📝")
                                            .font(.caption2)
                                        Text("정보")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(personAction.isCompleted ? .gray : .blue)
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(personAction.isCompleted ? Color.gray.opacity(0.2) : Color.blue.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(personAction.isCompleted ? Color.gray : Color.blue, lineWidth: 1)
                                    )
                                }
                                
                                // PersonDetailView 표시 토글 버튼 (Critical 액션만)
                                if action.type == .critical {
                                    Button {
                                        personAction.isVisibleInDetail.toggle()
                                        do {
                                            try context.save()
                                        } catch {
                                            print("❌ PersonAction 가시성 변경 저장 실패: \(error)")
                                        }
                                    } label: {
                                        Image(systemName: personAction.isVisibleInDetail ? "eye.fill" : "eye.slash")
                                            .font(.caption)
                                            .foregroundStyle(personAction.isVisibleInDetail ? .blue : .gray)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                // 리마인더 버튼
                                Button {
                                    showingReminderSetting = true
                                } label: {
                                    Image(systemName: "bell")
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                                .buttonStyle(.plain)
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
                            Text("중요한 액션이 완료되었습니다. 체크박스를 다시 누르면 완료를 취소할 수 있고, 눈 모양 버튼으로 PersonDetailView에 표시/숨김을 설정할 수 있어요.")
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
                            Image(systemName: personAction.action?.type == .critical ? "exclamationmark.triangle.fill" : "note.text")
                                .font(.caption2)
                            Text(personAction.context)
                                .font(.subheadline)
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    personAction.action?.type == .critical 
                                        ? Color.orange.gradient 
                                        : Color.blue.gradient
                                )
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
        
        // 관계 상태 업데이트 (안전하게)
        if let person = personAction.person {
            do {
                try RelationshipStateManager.shared.updatePersonRelationshipState(person, context: context)
            } catch {
                print("❌ 관계 상태 업데이트 실패: \(error)")
            }
        }
        
        do {
            try context.save()
        } catch {
            print("❌ PersonAction 완료 저장 실패: \(error)")
        }
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
                        .autocorrectionDisabled(true)
                    
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
                        do {
                            try context.save()
                        } catch {
                            print("❌ PersonAction 완료 처리 저장 실패: \(error)")
                        }
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
                        do {
                            try context.save()
                        } catch {
                            print("❌ PersonAction 상세 정보 저장 실패: \(error)")
                        }
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
