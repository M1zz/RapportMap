//
//  PersonDetailView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData
import Contacts

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

// 연락처 동기화 상태 정의
enum ContactSyncStatus {
    case unknown
    case checking
    case synced(CNContact)
    case notFound
    case error(String)
    
    var displayText: String {
        switch self {
        case .unknown:
            return "확인 중..."
        case .checking:
            return "연락처 검색 중..."
        case .synced:
            return "iPhone 연락처와 연동됨"
        case .notFound:
            return "iPhone 연락처에 없음"
        case .error(let message):
            return "오류: \(message)"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown, .checking:
            return .secondary
        case .synced:
            return .green
        case .notFound:
            return .orange
        case .error:
            return .red
        }
    }
    
    var systemImage: String {
        switch self {
        case .unknown, .checking:
            return "magnifyingglass"
        case .synced:
            return "checkmark.circle.fill"
        case .notFound:
            return "exclamationmark.triangle.fill"
        case .error:
            return "xmark.circle.fill"
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
    @State private var showingContactPicker = false
    @State private var isLoadingContact = false
    @State private var refreshTrigger = 0 // UI 강제 새로고침을 위한 트리거
    @State private var isSyncingContact = false // 연락처 동기화 로딩 상태
    @State private var contactSyncStatus: ContactSyncStatus = .unknown // 연락처 동기화 상태
    @State private var syncSuccessMessage: String? = nil // 동기화 성공 메시지
    @State private var showingSyncSuccess = false // 동기화 성공 알림 표시
    @StateObject private var contactsManager = ContactsManager.shared
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
        .id(refreshTrigger) // refreshTrigger 값이 변경되면 전체 뷰가 새로고침됨
        .onReceive(NotificationCenter.default.publisher(for: .importantRecordingAdded)) { notification in
            // 현재 Person과 알림의 Person이 일치하는지 확인
            if let notificationPerson = notification.object as? Person,
               notificationPerson.id == person.id {
                // UI 강제 새로고침
                withAnimation(.easeInOut(duration: 0.3)) {
                    refreshTrigger += 1
                }
                print("🔄 PersonDetailView refreshed for important recording")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .criticalActionAdded)) { notification in
            // 현재 Person과 알림의 Person이 일치하는지 확인
            if let notificationPerson = notification.object as? Person,
               notificationPerson.id == person.id {
                print("🔄 PersonDetailView received criticalActionAdded notification")
                print("🔍 Person actions count: \(person.actions.count)")
                
                // UI 강제 새로고침
                withAnimation(.easeInOut(duration: 0.5)) {
                    refreshTrigger += 1
                }
                
                // 약간의 지연 후 추가 새로고침 (SwiftData 동기화 시간)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        refreshTrigger += 1
                    }
                }
                
                print("🔄 PersonDetailView refreshed for new critical action (trigger: \(refreshTrigger))")
            }
        }
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
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(isPresented: $showingContactPicker) { contact in
                // 연락처에서 선택한 정보로 Person의 연락처 업데이트
                let contactInfo = extractContactInfo(from: contact)
                if !contactInfo.isEmpty {
                    person.contact = contactInfo
                    try? context.save()
                    print("✅ \(person.name)의 연락처 정보 업데이트됨: \(contactInfo)")
                }
                
                // 동기화 상태를 즉시 synced로 설정 (연락처에서 선택했으므로)
                contactSyncStatus = .synced(contact)
                contactsManager.lastError = nil
                
                // 추가 확인을 위한 비동기 체크
                Task {
                    await checkContactSyncStatus()
                }
            }
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
            // 기존 Critical Actions
            ForEach(getCriticalActions(), id: \.id) { personAction in
                CriticalActionReminderRow(personAction: personAction)
                    .id("\(personAction.id)-\(refreshTrigger)") // 새로고침 시 효과
            }
            
            // 중요한 상호작용 기록들 추가
            ForEach(person.getImportantInteractionRecords(), id: \.id) { interaction in
                ImportantInteractionRow(interaction: interaction)
                    .id("\(interaction.id)-\(refreshTrigger)") // 새로고침 시 깜빡이는 효과
            }
            
            // 중요한 미팅 기록들 추가
            ForEach(person.getImportantMeetingRecords(), id: \.id) { meeting in
                ImportantMeetingRow(meeting: meeting)
                    .id("\(meeting.id)-\(refreshTrigger)") // 새로고침 시 깜빡이는 효과
            }
            
            // 중요한 대화 기록들 추가
            ForEach(person.getImportantConversationRecords(), id: \.id) { conversation in
                ImportantConversationRow(conversation: conversation)
                    .id("\(conversation.id)-\(refreshTrigger)") // 새로고침 시 깜빡이는 효과
            }
            
            addCriticalActionButton
            
            if getCriticalActions().isEmpty && !person.hasImportantRecords {
                emptyCriticalActionsMessage
            }
        }
        .onAppear {
            // 기존 대화 기록들을 자동으로 중요하게 표시
            var hasChanges = false
            for record in person.conversationRecords {
                if (record.type == .concern || record.type == .promise || record.type == .question) && !record.isImportant {
                    record.isImportant = true
                    hasChanges = true
                }
            }
            
            // 변경사항이 있으면 저장하고 알림 발송
            if hasChanges {
                try? context.save()
                
                // UI 새로고침을 위한 알림 발송
                NotificationCenter.default.post(
                    name: .importantRecordingAdded,
                    object: person
                )
                
                print("✅ 기존 고민, 약속, 질문을 자동으로 중요하게 표시했습니다.")
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
            Text("라포 액션 체크리스트에서 중요한 액션들을 완료한 후 눈 모양 버튼을 눌러 여기에 표시하도록 설정하거나, 대화 기록에서 고민, 질문, 약속을 중요하다고 표시하거나, 위의 버튼으로 새로운 중요한 것을 추가해보세요.")
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
            
            HStack {
                TextField("연락처", text: $person.contact)
                    .onChange(of: person.contact) { oldValue, newValue in
                        // 연락처가 변경되면 동기화 상태 재확인
                        Task {
                            await checkContactSyncStatus()
                        }
                    }
                
                // 연락처가 비어있거나 "연락처 없음"일 때 연락처에서 가져오기 버튼 표시
                if person.contact.isEmpty || person.contact == "연락처 없음" {
                    Button {
                        showingContactPicker = true
                    } label: {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.borderless)
                }
            }
            
            // 연락처 자동 찾기 버튼 (연락처가 없을 때)
            if person.contact.isEmpty || person.contact == "연락처 없음" {
                Button {
                    Task {
                        isLoadingContact = true
                        if let foundContact = await contactsManager.updatePersonContactFromContacts(person) {
                            await MainActor.run {
                                person.contact = foundContact
                                try? context.save()
                                isLoadingContact = false
                            }
                            // 연락처를 찾았으므로 동기화 상태 재확인
                            await checkContactSyncStatus()
                        } else {
                            await MainActor.run {
                                isLoadingContact = false
                            }
                        }
                    }
                } label: {
                    HStack {
                        if isLoadingContact {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "magnifyingglass.circle")
                                .foregroundStyle(.orange)
                        }
                        
                        Text(isLoadingContact ? "연락처 검색 중..." : "iPhone 연락처에서 자동으로 찾기")
                            .foregroundStyle(.orange)
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .disabled(isLoadingContact)
            }
            
            // 에러 표시 (연락처 동기화 관련 에러만)
            if case .error(let errorMessage) = contactSyncStatus {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
        }
        .onAppear {
            Task {
                await checkContactSyncStatus()
            }
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
        let criticalActions = person.actions
            .filter {
                $0.action?.type == .critical && $0.isVisibleInDetail
            }
            .sorted {
                if $0.isCompleted != $1.isCompleted {
                    return !$0.isCompleted
                }
                return ($0.action?.order ?? 0) < ($1.action?.order ?? 0)
            }
        
        // 디버깅 로그
        print("🔍 [PersonDetailView] Getting critical actions for \(person.name):")
        print("  Total actions: \(person.actions.count)")
        print("  Critical actions found: \(criticalActions.count)")
        
        for action in person.actions {
            if let rapportAction = action.action {
                print("  Action: \(rapportAction.title), Type: \(rapportAction.type), Visible: \(action.isVisibleInDetail), Critical: \(rapportAction.type == .critical)")
            }
        }
        
        return criticalActions
    }
    
    /// CNContact에서 연락처 정보를 추출하는 헬퍼 메소드
    private func extractContactInfo(from contact: CNContact) -> String {
        // 전화번호 우선 (모바일 > 기본 > 첫 번째)
        let mobilePhone = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMobile }
        let mainPhone = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMain }
        
        if let mobile = mobilePhone {
            return mobile.value.stringValue
        } else if let main = mainPhone {
            return main.value.stringValue
        } else if let firstPhone = contact.phoneNumbers.first {
            return firstPhone.value.stringValue
        } else if let email = contact.emailAddresses.first {
            return email.value as String
        }
        
        return ""
    }
    
    /// 연락처 동기화 상태를 확인하는 메소드
    private func checkContactSyncStatus() async {
        // 연락처 정보가 없으면 확인하지 않음
        guard !person.contact.isEmpty && person.contact != "연락처 없음" else {
            await MainActor.run {
                contactSyncStatus = .notFound
                // 에러 메시지 초기화
                contactsManager.lastError = nil
            }
            return
        }
        
        await MainActor.run {
            contactSyncStatus = .checking
            // 검색 시작할 때 이전 에러 메시지 초기화
            contactsManager.lastError = nil
        }
        
        // 연락처 검색 시도
        do {
            if let contact = await contactsManager.findContact(for: person) {
                await MainActor.run {
                    contactSyncStatus = .synced(contact)
                    // 성공하면 에러 메시지 초기화
                    contactsManager.lastError = nil
                    print("✅ 연락처 동기화 상태: 연동됨 (\(contact.givenName) \(contact.familyName))")
                }
            } else {
                await MainActor.run {
                    contactSyncStatus = .notFound
                    // 찾지 못한 경우는 에러가 아니므로 에러 메시지 초기화
                    contactsManager.lastError = nil
                    print("⚠️ 연락처 동기화 상태: iPhone 연락처에 없음")
                }
            }
        } catch {
            // 실제 에러가 발생한 경우에만 에러 상태로 설정
            await MainActor.run {
                contactSyncStatus = .error("연락처 검색 실패: \(error.localizedDescription)")
                print("❌ 연락처 동기화 에러: \(error.localizedDescription)")
            }
        }
    }
    
    /// iPhone 연락처에서 정보를 가져와서 Person 정보를 업데이트하는 메소드
    private func syncContactInfo(from contact: CNContact) async {
        await MainActor.run {
            isSyncingContact = true
            syncSuccessMessage = nil
            showingSyncSuccess = false
        }
        
        var hasUpdates = false
        var updatedInfo: [String] = []
        
        // 이름 동기화 (공백 포함된 형태로 업데이트)
        let contactFullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
        if !contactFullName.isEmpty && contactFullName != person.name {
            await MainActor.run {
                person.name = contactFullName
            }
            hasUpdates = true
            updatedInfo.append("이름")
        }
        
        // 연락처 정보 동기화 (더 나은 정보로 업데이트)
        let newContactInfo = extractContactInfo(from: contact)
        if !newContactInfo.isEmpty && newContactInfo != person.contact {
            // 기존 연락처와 다르면 업데이트 여부를 확인
            let shouldUpdate = person.contact.isEmpty || 
                              person.contact == "연락처 없음" || 
                              newContactInfo.count > person.contact.count // 더 완전한 정보인 경우
            
            if shouldUpdate {
                await MainActor.run {
                    person.contact = newContactInfo
                }
                hasUpdates = true
                updatedInfo.append("연락처")
            }
        }
        
        // 추가적으로 동기화할 수 있는 정보들
        if !contact.emailAddresses.isEmpty {
            let emails = contact.emailAddresses.map { $0.value as String }
            // 이메일 정보를 Person 모델에 추가하려면 Person 모델에 email 필드를 추가해야 함
            print("📧 사용 가능한 이메일: \(emails.joined(separator: ", "))")
        }
        
        if !contact.phoneNumbers.isEmpty {
            let phones = contact.phoneNumbers.map { "\($0.label ?? "기타"): \($0.value.stringValue)" }
            print("📞 사용 가능한 전화번호: \(phones.joined(separator: ", "))")
        }
        
        // 메모나 기타 정보
        if !contact.note.isEmpty {
            print("📝 연락처 메모: \(contact.note)")
        }
        
        // 변경사항 저장 및 피드백
        await MainActor.run {
            if hasUpdates {
                try? context.save()
                syncSuccessMessage = "\(updatedInfo.joined(separator: ", ")) 업데이트됨"
                print("✅ 연락처 정보 동기화 완료: \(updatedInfo.joined(separator: ", "))")
            } else {
                syncSuccessMessage = "모든 정보가 최신 상태입니다"
                print("ℹ️ 업데이트할 정보가 없습니다.")
            }
            
            isSyncingContact = false
            showingSyncSuccess = true
        }
        
        // 성공 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        // 3초 후에 성공 메시지 숨기기
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeOut(duration: 0.3)) {
                showingSyncSuccess = false
            }
            
            // 추가 1초 후에 메시지 완전 제거
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                syncSuccessMessage = nil
            }
        }
    }
    
    /// Person을 iPhone 연락처에 추가하는 메소드
    private func addToPhoneContacts() async {
        // 추가 시작할 때 에러 메시지 초기화
        await MainActor.run {
            contactsManager.lastError = nil
            syncSuccessMessage = nil
            showingSyncSuccess = false
        }
        
        let success = await contactsManager.addPersonToContacts(person)
        
        if success {
            // 추가 성공하면 동기화 상태 재확인
            await checkContactSyncStatus()
            
            // 성공 피드백
            await MainActor.run {
                syncSuccessMessage = "iPhone 연락처에 추가됨"
                showingSyncSuccess = true
            }
            
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            
            print("✅ \(person.name)을 iPhone 연락처에 추가했습니다.")
            
            // 3초 후에 성공 메시지 숨기기
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showingSyncSuccess = false
                }
                
                // 추가 1초 후에 메시지 완전 제거
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    syncSuccessMessage = nil
                }
            }
            
        } else {
            // 실패한 경우 동기화 상태를 에러로 설정
            await MainActor.run {
                if let error = contactsManager.lastError {
                    contactSyncStatus = .error(error)
                } else {
                    contactSyncStatus = .error("iPhone 연락처 추가 실패")
                }
            }
            print("❌ iPhone 연락처 추가 실패")
        }
    }
}

// MARK: - Important Record Row Views

struct ImportantInteractionRow: View {
    let interaction: InteractionRecord
    @State private var isNewlyAdded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 상호작용 타입 아이콘
            ZStack {
                Circle()
                    .fill(interaction.type.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: interaction.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(interaction.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(interaction.type.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 중요 표시
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    
                    // 새로 추가된 항목 표시
                    if isRecentlyAdded(interaction.date) {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(for: interaction.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let notes = interaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                if let duration = interaction.formattedDuration {
                    Text("지속시간: \(duration)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded(interaction.date) ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    // 최근 5분 내에 추가된 항목인지 확인
    private func isRecentlyAdded(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 300 // 5분 = 300초
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ImportantMeetingRow: View {
    let meeting: MeetingRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // 미팅 타입 아이콘
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Text(meeting.meetingType.emoji)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meeting.meetingType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 중요 표시
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    
                    // 오디오 파일 있음 표시
                    if meeting.hasAudio {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    // 새로 추가된 항목 표시
                    if isRecentlyAdded(meeting.date) {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(for: meeting.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !meeting.transcribedText.isEmpty {
                    Text(meeting.transcribedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Text("길이: \(meeting.formattedDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded(meeting.date) ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    // 최근 5분 내에 추가된 항목인지 확인
    private func isRecentlyAdded(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 300 // 5분 = 300초
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ImportantConversationRow: View {
    let conversation: ConversationRecord
    @Environment(\.modelContext) private var context
    
    var body: some View {
        HStack(spacing: 12) {
            // 대화 타입 아이콘
            ZStack {
                Circle()
                    .fill(conversation.type.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: conversation.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(conversation.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.type.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 중요 표시
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    
                    // 우선순위 표시 (긴급/높음일 때만)
                    if conversation.priority == .urgent || conversation.priority == .high {
                        Text(conversation.priority.emoji)
                            .font(.caption2)
                    }
                    
                    // 새로 추가된 항목 표시
                    if isRecentlyAdded(conversation.createdDate) {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(for: conversation.createdDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 대화 내용
                Text(conversation.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // 미해결 상태 표시 (해결된 것은 이미 목록에서 제외됨)
                Text("⏳ 미해결")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            // 해결 체크 버튼
            Button {
                toggleResolvedStatus()
            } label: {
                ZStack {
                    Circle()
                        .fill(conversation.isResolved ? Color.green : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(conversation.isResolved ? Color.green : Color.gray, lineWidth: 2)
                        )
                    
                    if conversation.isResolved {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded(conversation.createdDate) ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    private func toggleResolvedStatus() {
        // 해결 상태를 토글하고 해결 날짜 설정
        conversation.isResolved.toggle()
        
        if conversation.isResolved {
            conversation.resolvedDate = Date()
        } else {
            conversation.resolvedDate = nil
        }
        
        // 데이터베이스 저장
        try? context.save()
        
        // 해결된 경우 UI에서 사라지도록 새로고침 알림 발송
        if conversation.isResolved {
            NotificationCenter.default.post(
                name: .importantRecordingAdded,
                object: conversation.person
            )
        }
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let status = conversation.isResolved ? "해결됨 (목록에서 숨김)" : "미해결"
        print("✅ \(conversation.type.title) '\(conversation.content)' 상태: \(status)")
    }
    
    // 최근 5분 내에 추가된 항목인지 확인
    private func isRecentlyAdded(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 300 // 5분 = 300초
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
