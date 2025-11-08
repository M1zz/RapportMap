//
//  PersonDetailView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// 상세 뷰 탭 정의
enum PersonDetailTab: Int, CaseIterable {
    case activities = 0
    case relationship = 1
    case info = 2
    
    var title: String {
        switch self {
        case .info: return "정보"
        case .activities: return "활동"
        case .relationship: return "관계"
        }
    }
}

struct PersonDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingVoiceRecorder = false
    @State private var showingAddCriticalAction = false
    @State private var showingInteractionEdit = false
    @State private var selectedInteractionType: InteractionType?
    @State private var isMeetingRecordsExpanded = false
    @State private var showingQuickRecord = false
    @Binding var selectedTab: Int
    
    @Bindable var person: Person

    init(person: Person, selectedTab: Binding<Int> = .constant(0)) {
        self._person = Bindable(person)
        self._selectedTab = selectedTab
    }
    
    private var currentTab: PersonDetailTab {
        PersonDetailTab(rawValue: selectedTab) ?? .activities
    }
    
    var body: some View {
        Form {
            // 선택된 탭에 따라 다른 내용 표시
            switch currentTab {
            case .activities:
                activitiesTabContent  
            case .relationship:
                relationshipTabContent
            case .info:
                infoTabContent
            }
        }
        .navigationTitle(person.name)
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
        .sheet(isPresented: $showingQuickRecord) {
            QuickRecordSheet(person: person)
        }
    }
    
    // MARK: - Tab Content Views
    @ViewBuilder
    private var activitiesTabContent: some View {
        // 상호작용 섹션
        recentInteractionsSection
        
        // 녹음 섹션들
        recordingSection
        
        // 놓치면 안되는 것들
        criticalActionsSection
    }
    
    @ViewBuilder
    private var relationshipTabContent: some View {
        // 관계 상태
        relationshipStatusSection
        
        // 대화/상태
        conversationStateSection
    }
    
    @ViewBuilder
    private var infoTabContent: some View {
        // 기본 정보
        basicInfoSection
        
        // 알게 된 정보
        knowledgeSection
        
        // 액션 체크리스트
        actionChecklistSection
        
    }
    
    // MARK: - View Sections
    
    @ViewBuilder
    private var recentInteractionsSection: some View {
        Section("상호작용") {
            RecentInteractionsView(person: person)
        }
    }
    
    @ViewBuilder
    private var recordingSection: some View {
        Section("녹음") {
            voiceRecorderButton
            recordingHistoryList
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
    private var recordingHistoryList: some View {
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
    private var actionChecklistSection: some View {
        Section("액션 아이템") {
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
    private var basicInfoSection: some View {
        Section("기본 정보") {
            TextField("이름", text: $person.name)
            TextField("연락처", text: $person.contact)
        }
    }
    
    @ViewBuilder
    private var relationshipStatusSection: some View {
        Section("관계") {
            RelationshipAnalysisCard(person: person)
        }
    }
    
    @ViewBuilder
    private var conversationStateSection: some View {
        Section("대화/상태") {
            // 빠른 입력 버튼 추가
            Button {
                showingQuickRecord = true
            } label: {
                HStack {
                    Image(systemName: "bolt.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("빠른 대화 기록")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("고민, 질문, 약속을 한번에 입력")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            // 현재 미해결 대화 수 표시
            HStack {
                Text("미해결 대화:")
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(person.currentUnansweredCount)개")
                        .foregroundStyle(.secondary)
                    if person.currentUnansweredCount > 0 {
                        Text("(질문, 고민, 약속 포함)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            
            // 소홀함 상태 표시 (자동 계산됨)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: person.isNeglected ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(person.isNeglected ? .red : .green)
                    
                    Text("관계 관리 상태")
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(person.isNeglected ? "소홀함" : "양호함")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(person.isNeglected ? .red : .green)
                }
                
                Text(person.neglectedReason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            .padding()
            .background(person.isNeglected ? Color.red.opacity(0.05) : Color.green.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(person.isNeglected ? Color.red.opacity(0.2) : Color.green.opacity(0.2), lineWidth: 1)
            )
            
            // 대화 기록 버튼들과 전체 기록 보기
            ConversationRecordsView(person: person)
        }
    }
    
    // MARK: - Helper Methods
    
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
