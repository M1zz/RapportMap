//
//  PersonDetailView+Sections.swift
//  RapportMap
//
//  분할된 파일: 각 섹션 뷰들과 헬퍼 메서드, Computed Properties
//

import SwiftUI
import SwiftData
import Contacts
import EventKit

// MARK: - View Sections
extension PersonDetailView {
    
    // MARK: - Badge Section (Deprecated - 사용하지 않음)
    @ViewBuilder
    var badgesSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    // 크리티컬 액션 배지
                    if person.criticalActionsCount > 0 {
                        BadgeCard(
                            count: person.criticalActionsCount,
                            title: "긴급 액션",
                            color: .red,
                            icon: "exclamationmark.circle.fill"
                        ) {
                            selectedTab = 0 // 활동 탭으로 이동
                        }
                    }

                    // 미완료 액션 배지
                    if person.incompleteActionsCount > 0 {
                        BadgeCard(
                            count: person.incompleteActionsCount,
                            title: "미완료 액션",
                            color: .blue,
                            icon: "checkmark.circle"
                        ) {
                            selectedTab = 0 // 활동 탭으로 이동
                        }
                    }

                    // 중요 항목 배지
                    if person.importantItemsCount > 0 {
                        BadgeCard(
                            count: person.importantItemsCount,
                            title: "중요 항목",
                            color: .yellow,
                            icon: "star.fill"
                        ) {
                            selectedTab = 1 // 타임라인 탭으로 이동
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        } header: {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.red)
                Text("주의가 필요한 항목")
                    .font(.headline)
            }
        }
    }

    // MARK: - Notification-based Badge Section
    @ViewBuilder
    var notificationBadgesSection: some View {
        Section {
            VStack(spacing: 12) {
                ForEach(personNotifications.prefix(5)) { notification in
                    NotificationBadgeRow(notification: notification) {
                        selectedNotification = notification
                    }
                }

                if personNotifications.count > 5 {
                    Text("외 \(personNotifications.count - 5)개 더...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            HStack {
                Image(systemName: "bell.badge.fill")
                    .foregroundStyle(.red)
                Text("주의가 필요한 항목")
                    .font(.headline)
                Spacer()
                Text("\(personNotifications.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.red.opacity(0.2)))
            }
        }
        .sheet(item: $selectedNotification) { notification in
            NotificationDetailSheet(notification: notification)
        }
    }
    
    @ViewBuilder
    var recentInteractionsSection: some View {
        Section("상호작용") {
            RecentInteractionsView(person: person)
        }
    }

    @ViewBuilder
    var calendarEventsSection: some View {
        Section {
            // 일정 추가 버튼
            Button {
                showingAddEvent = true
            } label: {
                HStack {
                    Image(systemName: "calendar.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("일정 추가")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("캘린더에 미팅 일정 추가")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // 다가오는 일정
            if !upcomingEvents.isEmpty {
                ForEach(upcomingEvents, id: \.eventIdentifier) { event in
                    UpcomingEventRow(event: event)
                }
            }
        } header: {
            Text("일정")
        }
        .onAppear {
            calendarManager.checkAuthorizationStatus()
            loadUpcomingEvents()
        }
    }

    func loadUpcomingEvents() {
        upcomingEvents = calendarManager.fetchUpcomingEvents(for: person, days: 30)
    }

    @ViewBuilder
    var recordingSection: some View {
        Section("녹음") {
            voiceRecorderButton
            recordingHistoryList
        }
    }
    
    @ViewBuilder
    var voiceRecorderButton: some View {
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
    var recordingHistoryList: some View {
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
    var actionChecklistSection: some View {
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
    var criticalActionsSection: some View {
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
    var addCriticalActionButton: some View {
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
    var emptyCriticalActionsMessage: some View {
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
    var knowledgeSection: some View {
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
    
    // MARK: - Tags Section
    @ViewBuilder
    var tagsSection: some View {
        Section {
            // 현재 태그들 표시
            if person.tags.isEmpty {
                Button {
                    showingTagSelection = true
                } label: {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundStyle(.secondary)
                        Text("태그 추가하기")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            } else {
                // 태그들을 FlowLayout으로 표시
                Button {
                    showingTagSelection = true
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        TagsFlowView(tags: person.tags, isCompact: false)
                        
                        HStack {
                            Spacer()
                            Text("탭하여 편집")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text("🏷️ 태그")
                Spacer()
                if !person.tags.isEmpty {
                    Text("\(person.tags.count)개")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    @ViewBuilder
    var basicInfoSection: some View {
        Section("기본 정보") {
            // 프로필 사진
            HStack {
                Spacer()
                
                Button {
                    showingImageSourceOptions = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        if let imageData = person.profileImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 2))
                        } else {
                            // 기본 프로필 이미지
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 80, height: 80)
                                    .foregroundStyle(.gray)
                            }
                        }
                        
                        // 편집 버튼
                        ZStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 36, height: 36)
                            
                            Image(systemName: "camera.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                        }
                        .offset(x: -5, y: -5)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
            }
            .padding(.vertical, 8)
            
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
                        contactSearchFailedMessage = nil // 이전 메시지 초기화
                        
                        if let foundContact = await contactsManager.updatePersonContactFromContacts(person),
                           !foundContact.isEmpty,
                           foundContact != "010-0000-0000" {
                            // 성공: 유효한 연락처를 찾음
                            await MainActor.run {
                                person.contact = foundContact
                                try? context.save()
                                isLoadingContact = false
                                contactSearchFailedMessage = nil
                            }
                            // 연락처를 찾았으므로 동기화 상태 재확인
                            await checkContactSyncStatus()
                        } else {
                            // 실패: nil, 빈 문자열, 또는 010-0000-0000
                            await MainActor.run {
                                isLoadingContact = false
                                // 실패 메시지 설정
                                contactSearchFailedMessage = "'\(person.name)' 이름과 일치하는 연락처를 찾을 수 없습니다"
                            }
                            
                            // 3초 후 메시지 자동 제거
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                withAnimation {
                                    contactSearchFailedMessage = nil
                                }
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
                
                // 검색 실패 메시지
                if let failMessage = contactSearchFailedMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        
                        Text(failMessage)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
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
    var conversationStateSection: some View {
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
}

// MARK: - Helper Methods
extension PersonDetailView {
    
    func recordQuickInteraction(type: InteractionType) {
        // 새로운 InteractionRecord 생성
        person.addInteractionRecord(type: type, date: Date())
        try? context.save()

        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // 편집 시트는 열지 않고 바로 저장
        print("✅ \(type.title) 빠른 기록 완료")
    }
}

// MARK: - Computed Properties
extension PersonDetailView {

    func calculateCompletionRate() -> Double? {
        guard !person.actions.isEmpty else { return nil }
        let completed = person.actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(person.actions.count)
    }
    
    func getCompletedTrackingActions() -> [PersonAction] {
        person.actions
            .filter {
                $0.isCompleted &&
                !$0.context.isEmpty &&
                $0.action?.type == .tracking
            }
            .sorted { ($0.action?.order ?? 0) < ($1.action?.order ?? 0) }
    }
    
    func getCriticalActions() -> [PersonAction] {
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
    func extractContactInfo(from contact: CNContact) -> String {
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
    func checkContactSyncStatus() async {
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
    func syncContactInfo(from contact: CNContact) async {
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
    func addToPhoneContacts() async {
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
