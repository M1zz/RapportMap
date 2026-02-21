//
//  PersonDetailView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//
//  이 파일은 PersonDetailView의 메인 구조를 담당합니다.
//  탭 콘텐츠, 섹션, 컴포넌트는 extension으로 분리되어 있습니다:
//  - PersonDetailView+Tabs.swift: 탭 콘텐츠 뷰들
//  - PersonDetailView+Sections.swift: 각 섹션과 헬퍼/computed properties
//  - PersonDetailView+Components.swift: 재사용 가능한 컴포넌트들
//

import SwiftUI
import SwiftData
import Contacts
import EventKit

// MARK: - PersonDetailTab enum
enum PersonDetailTab: Int, CaseIterable {
    case dashboard = 0     // 🆕 대시보드 (첫 번째)
    case records = 1       // 기록
    case timeline = 2      // 타임라인
    case relationships = 3 // 🆕 관계도
    case info = 4          // 정보

    var title: String {
        switch self {
        case .dashboard: return "대시보드"
        case .records: return "기록"
        case .timeline: return "타임라인"
        case .relationships: return "관계"
        case .info: return "정보"
        }
    }
    
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .records: return "book"
        case .timeline: return "clock.arrow.circlepath"
        case .relationships: return "person.3"
        case .info: return "info.circle"
        }
    }
}

// MARK: - ContactSyncStatus enum
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

// MARK: - PersonDetailView
struct PersonDetailView: View {
    // MARK: - Environment
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) var context
    @Query private var allNotifications: [NotificationHistory]
    
    // MARK: - State
    @State var showingVoiceRecorder = false
    @State var showingAddCriticalAction = false
    @State var showingInteractionEdit = false
    @State var selectedInteractionType: InteractionType?
    @State var isMeetingRecordsExpanded = false
    @State var showingQuickRecord = false
    @State var showingContactPicker = false
    @State var isLoadingContact = false
    @State var refreshTrigger = 0
    @State var isSyncingContact = false
    @State var contactSyncStatus: ContactSyncStatus = .unknown
    @State var syncSuccessMessage: String? = nil
    @State var showingSyncSuccess = false
    @State var contactSearchFailedMessage: String? = nil
    @State var showingImagePicker = false
    @State var showingImageSourceOptions = false
    @State var showingTagSelection = false
    @StateObject var contactsManager = ContactsManager.shared
    @StateObject var calendarManager = CalendarManager.shared
    @State var showingAddEvent = false
    @State var upcomingEvents: [EKEvent] = []
    @State var selectedNotification: NotificationHistory? = nil
    @Binding var selectedTab: Int

    @Bindable var person: Person

    // MARK: - Computed Properties
    var personNotifications: [NotificationHistory] {
        allNotifications.filter { $0.personID == person.id && !$0.isRead }
    }
    
    var currentTab: PersonDetailTab {
        PersonDetailTab(rawValue: selectedTab) ?? .dashboard
    }

    // MARK: - Init
    init(person: Person, selectedTab: Binding<Int> = .constant(0)) {
        self._person = Bindable(person)
        self._selectedTab = selectedTab
    }
    
    // MARK: - Body
    var body: some View {
        Group {
            // 선택된 탭에 따라 다른 내용 표시
            switch currentTab {
            case .dashboard:
                PersonDashboardTab(person: person)
            case .records:
                Form {
                    recordsTabContent
                }
            case .timeline:
                Form {
                    timelineTabContent
                }
            case .relationships:
                RelationshipGraphView(person: person)
            case .info:
                Form {
                    infoTabContent
                }
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // 탭이 5개이므로 항상 Menu 사용
                Menu {
                    ForEach(PersonDetailTab.allCases, id: \.rawValue) { tab in
                        Button {
                            selectedTab = tab.rawValue
                        } label: {
                            Label(tab.title, systemImage: tab.icon)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: currentTab.icon)
                            .font(.subheadline)
                        Text(currentTab.title)
                            .font(.subheadline)
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
            }
        }
        .id(refreshTrigger)
        .onReceive(NotificationCenter.default.publisher(for: .importantRecordingAdded)) { notification in
            if let notificationPerson = notification.object as? Person,
               notificationPerson.id == person.id {
                withAnimation(.easeInOut(duration: 0.3)) {
                    refreshTrigger += 1
                }
                print("🔄 PersonDetailView refreshed for important recording")
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .criticalActionAdded)) { notification in
            if let notificationPerson = notification.object as? Person,
               notificationPerson.id == person.id {
                print("🔄 PersonDetailView received criticalActionAdded notification")
                print("🔍 Person actions count: \(person.actions.count)")
                
                withAnimation(.easeInOut(duration: 0.5)) {
                    refreshTrigger += 1
                }
                
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
                EditInteractionRecordSheet(record: latestRecord, person: person)
            }
        }
        .sheet(isPresented: $showingQuickRecord) {
            QuickRecordSheet(person: person)
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(isPresented: $showingContactPicker) { contact in
                let contactInfo = extractContactInfo(from: contact)
                if !contactInfo.isEmpty {
                    person.contact = contactInfo
                    try? context.save()
                    print("✅ \(person.name)의 연락처 정보 업데이트됨: \(contactInfo)")
                }
                
                contactSyncStatus = .synced(contact)
                contactsManager.lastError = nil
                
                Task {
                    await checkContactSyncStatus()
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            PhotoPicker(imageData: $person.profileImageData) {
                try? context.save()
            }
        }
        .confirmationDialog("프로필 사진 변경", isPresented: $showingImageSourceOptions, titleVisibility: .visible) {
            Button("사진 찍기") {
                showingImagePicker = true
            }
            Button("앨범에서 선택") {
                showingImagePicker = true
            }
            if person.profileImageData != nil {
                Button("사진 삭제", role: .destructive) {
                    person.profileImageData = nil
                    try? context.save()
                }
            }
            Button("취소", role: .cancel) { }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventSheet(person: person) { _ in
                loadUpcomingEvents()
            }
        }
        .sheet(isPresented: $showingTagSelection) {
            PersonTagSelectionView(person: person)
        }
    }
}
