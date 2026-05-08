//
//  PersonDetailView.swift
//  RapportMap
//
//  사람 상세 뷰 - 지도 + 타임라인 + 정보
//

import SwiftUI
import SwiftData
#if os(iOS)
import PhotosUI
#else
import UniformTypeIdentifiers
#endif

struct PersonDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person

    @State private var selectedTab: DetailTab = .map
    @State private var showingMeetingSheet = false
    @State private var showingDeleteAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 탭 선택 — zIndex(1)로 콘텐츠 위에 항상 렌더링
            tabPicker
                .zIndex(1)

            // 탭 콘텐츠 — ZStack으로 유지해야 탭 전환 시 재생성 없이 즉시 반응
            // clipped()로 콘텐츠가 탭바 영역을 침범하지 않도록 차단
            ZStack(alignment: .top) {
                PersonMapView(person: person)
                    .opacity(selectedTab == .map ? 1 : 0)
                    .allowsHitTesting(selectedTab == .map)
                DiscoveryTimelineView(person: person)
                    .opacity(selectedTab == .timeline ? 1 : 0)
                    .allowsHitTesting(selectedTab == .timeline)
                ActivityRecordsView(person: person)
                    .opacity(selectedTab == .records ? 1 : 0)
                    .allowsHitTesting(selectedTab == .records)
                PersonInfoView(person: person)
                    .opacity(selectedTab == .info ? 1 : 0)
                    .allowsHitTesting(selectedTab == .info)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .clipped()
            .animation(.easeInOut(duration: 0.15), value: selectedTab)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle(person.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingMeetingSheet = true
                } label: {
                    Label("만남 시작", systemImage: "person.2.wave.2")
                }
            }
        }
        .sheet(isPresented: $showingMeetingSheet) {
            MeetingSessionSheet(person: person)
        }
    }
    
    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 17))
                        Text(tab.title)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                    .frame(maxWidth: .infinity, minHeight: 62)
                    .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                    .contentShape(Rectangle())
                    .animation(.easeInOut(duration: 0.12), value: selectedTab)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.secondaryBackground)
    }
}

// MARK: - 탭

enum DetailTab: String, CaseIterable {
    case map
    case timeline
    case records
    case info

    var title: String {
        switch self {
        case .map:      return "지도"
        case .timeline: return "발견들"
        case .records:  return "기록"
        case .info:     return "정보"
        }
    }

    var icon: String {
        switch self {
        case .map:      return "map"
        case .timeline: return "clock"
        case .records:  return "list.bullet.clipboard"
        case .info:     return "info.circle"
        }
    }
}

// MARK: - 타임라인 뷰

struct DiscoveryTimelineView: View {
    let person: Person
    
    @State private var selectedDepthFilter: RelationshipDepth?
    
    private var filteredDiscoveries: [Discovery] {
        let sorted = person.sortedDiscoveries
        if let filter = selectedDepthFilter {
            return sorted.filter { $0.depth == filter }
        }
        return sorted
    }
    
    private var groupedDiscoveries: [(String, [Discovery])] {
        let grouped = Dictionary(grouping: filteredDiscoveries) { discovery in
            discovery.date.formatted(.dateTime.year().month())
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 필터
            filterSection

            if (person.discoveries ?? []).isEmpty {
                emptyState
            } else if filteredDiscoveries.isEmpty {
                filteredEmptyState
            } else {
                timelineList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
    
    private var filterSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChipButton(
                    title: "전체",
                    isSelected: selectedDepthFilter == nil
                ) {
                    selectedDepthFilter = nil
                }
                
                ForEach(RelationshipDepth.allCases, id: \.self) { depth in
                    FilterChipButton(
                        title: "\(depth.icon) \(depth.title)",
                        isSelected: selectedDepthFilter == depth,
                        color: depth.color
                    ) {
                        selectedDepthFilter = selectedDepthFilter == depth ? nil : depth
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 발견이 없어요", systemImage: "sparkles")
        } description: {
            Text("지도에서 영역을 탭해서 발견을 기록해보세요")
        }
    }
    
    private var filteredEmptyState: some View {
        ContentUnavailableView {
            Label("해당 깊이의 발견이 없어요", systemImage: "magnifyingglass")
        } description: {
            Text("다른 필터를 선택해보세요")
        }
    }
    
    private var timelineList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(groupedDiscoveries, id: \.0) { month, discoveries in
                    Section {
                        ForEach(discoveries) { discovery in
                            DiscoveryTimelineRow(discovery: discovery)
                        }
                    } header: {
                        Text(month)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - 타임라인 행

struct DiscoveryTimelineRow: View {
    let discovery: Discovery
    
    @State private var showingDetail = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 타임라인 도트
            VStack(spacing: 4) {
                Circle()
                    .fill(discovery.displayColor)
                    .frame(width: 12, height: 12)
                
                Rectangle()
                    .fill(discovery.displayColor.opacity(0.3))
                    .frame(width: 2)
            }
            
            // 카드
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(discovery.displayEmoji)
                    Text(discovery.territory.title)
                        .font(.body)
                        .fontWeight(.medium)

                    Spacer()

                    Text(discovery.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.body)
                        .foregroundStyle(.secondary)

                    if discovery.isSignificant {
                        Image(systemName: "star.fill")
                            .font(.body)
                            .foregroundStyle(.yellow)
                    }
                }

                Text(discovery.content)
                    .font(.body)
                    .lineLimit(3)

                if let emotion = discovery.emotion {
                    HStack(spacing: 4) {
                        Text(emotion.emoji)
                        Text(emotion.title)
                    }
                    .font(.body)
                    .foregroundStyle(.secondary)
                }
            }
            .padding()
            .background(Color.secondaryBackground)
            .cornerRadius(12)
            .onTapGesture {
                showingDetail = true
            }
        }
        .sheet(isPresented: $showingDetail) {
            DiscoveryDetailSheet(discovery: discovery)
        }
    }
}

// MARK: - 정보 뷰

struct PersonInfoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person

    @State private var isEditingMemo = false
    @State private var showingDepthSheet = false
    @State private var showingFullScreenPhoto = false
    @State private var showingDeleteAlert = false

    #if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem?
    #endif

    var body: some View {
        Form {
            // 프로필 사진 섹션
            Section {
                HStack {
                    Spacer()
                    ZStack(alignment: .bottomTrailing) {
                        avatarView
                            .frame(width: 80, height: 80)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(person.depth.color.opacity(0.5), lineWidth: 2))
                            .onTapGesture {
                                if person.profileImageData != nil { showingFullScreenPhoto = true }
                            }
                        photoBadge
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }
            #if os(iOS)
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    if let data = try? await item?.loadTransferable(type: Data.self) {
                        person.profileImageData = data
                        try? context.save()
                    }
                }
            }
            #endif

            // 기본 정보
            Section("기본 정보") {
                LabeledContent("이름", value: person.name)
                
                if !person.contact.isEmpty {
                    LabeledContent("연락처", value: person.contact)
                }
                
                LabeledContent("관계 시작", value: person.relationshipStartDate.formatted(date: .long, time: .omitted))
                
                LabeledContent("함께한 기간", value: person.relationshipDuration)
            }
            
            // 탐험 현황
            Section("탐험 현황") {
                HStack {
                    Text("현재 깊이")
                    Spacer()
                    Text("\(person.depth.icon) \(person.depth.title)")
                        .foregroundStyle(person.depth.color)
                }
                .onTapGesture {
                    showingDepthSheet = true
                }
                
                HStack {
                    Text("탐험률")
                    Spacer()
                    Text("\(Int(person.totalExplorationProgress * 100))%")
                    ProgressView(value: person.totalExplorationProgress)
                        .frame(width: 60)
                }
                
                LabeledContent("탐험한 영역", value: "\(person.exploredTerritories.count)개")
                LabeledContent("미탐험 영역", value: "\(person.unexploredTerritories.count)개")
                
                if person.canAdvanceDepth {
                    Button {
                        withAnimation {
                            person.advanceDepth()
                            try? context.save()
                        }
                    } label: {
                        Label("다음 깊이로 진행", systemImage: "arrow.up.circle")
                    }
                }
            }
            
            // 통계
            Section("발견 통계") {
                let stats = person.discoveryStats
                LabeledContent("총 발견", value: "\(stats.total)개")
                LabeledContent("표면적", value: "\(stats.surfaceCount)개")
                LabeledContent("개인적", value: "\(stats.personalCount)개")
                LabeledContent("깊은", value: "\(stats.deepCount)개")
                LabeledContent("내밀한", value: "\(stats.intimateCount)개")
            }
            
            // 메모
            Section("메모") {
                if isEditingMemo {
                    TextEditor(text: Binding(
                        get: { person.memo ?? "" },
                        set: { person.memo = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(minHeight: 80)
                    
                    Button("완료") {
                        isEditingMemo = false
                        try? context.save()
                    }
                } else {
                    Text(person.memo ?? "메모 없음")
                        .foregroundStyle(person.memo == nil ? .secondary : .primary)
                        .onTapGesture {
                            isEditingMemo = true
                        }
                }
            }

            // 삭제
            Section {
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Label("\(person.name) 삭제", systemImage: "trash")
                            .foregroundStyle(.red)
                        Spacer()
                    }
                }
            }
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .sheet(isPresented: $showingDepthSheet) {
            DepthSettingSheet(person: person)
        }
        .sheet(isPresented: $showingFullScreenPhoto) {
            FullScreenPhotoView(imageData: person.profileImageData, isPresented: $showingFullScreenPhoto)
        }
        .alert("\(person.name)을(를) 삭제할까요?", isPresented: $showingDeleteAlert) {
            Button("삭제", role: .destructive) {
                context.delete(person)
                try? context.save()
                dismiss()
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 사람의 모든 발견, 메모, 기록이 함께 삭제됩니다.")
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let data = person.profileImageData {
            #if os(iOS)
            if let img = UIImage(data: data) { Image(uiImage: img).resizable().scaledToFill() }
            else { defaultAvatar }
            #else
            if let img = NSImage(data: data) { Image(nsImage: img).resizable().scaledToFill() }
            else { defaultAvatar }
            #endif
        } else { defaultAvatar }
    }

    private var defaultAvatar: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "d4a82a"), Color(hex: "8a6010")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(person.progressMoonPhase).font(.system(size: 34))
        }
    }

    @ViewBuilder
    private var photoBadge: some View {
        #if os(iOS)
        PhotosPicker(selection: $selectedPhoto, matching: .images) { badgeCircle }
            .buttonStyle(.plain)
        #else
        Button { pickPhotoMac() } label: { badgeCircle }.buttonStyle(.plain)
        #endif
    }

    private var badgeCircle: some View {
        Circle().fill(person.depth.color)
            .frame(width: 24, height: 24)
            .overlay(Image(systemName: "camera.fill").font(.system(size: 11)).foregroundStyle(.white))
    }

    #if os(macOS)
    private func pickPhotoMac() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url) {
            person.profileImageData = data
            try? context.save()
        }
    }
    #endif
}

// MARK: - 깊이 설정 시트

struct DepthSettingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var person: Person
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(RelationshipDepth.allCases, id: \.self) { depth in
                    Button {
                        person.setDepth(depth)
                        try? context.save()
                        dismiss()
                    } label: {
                        HStack {
                            Text(depth.icon)
                                .font(.title2)
                            
                            VStack(alignment: .leading) {
                                Text(depth.title)
                                    .font(.headline)
                                Text("\(Territory.territories(for: depth).count)개 영역")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if person.depth == depth {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("관계 깊이")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 350, height: 300)
        #endif
    }
}

// MARK: - 필터 칩

struct FilterChipButton: View {
    let title: String
    let isSelected: Bool
    var color: Color = .blue
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.body)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? color.opacity(0.2) : Color.tertiaryBackground)
                .foregroundStyle(isSelected ? color : .secondary)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 기록 타임라인 아이템

fileprivate enum RecordTimelineItem: Identifiable {
    case activity(ActivityRecord)
    case groupEvent(GroupEvent)
    case mentoring(MentoringSession, sessionNumber: Int)

    var id: String {
        switch self {
        case .activity(let r): "a-\(r.id)"
        case .groupEvent(let e): "g-\(e.id)"
        case .mentoring(let m, _): "m-\(m.id)"
        }
    }

    var date: Date {
        switch self {
        case .activity(let r): r.date
        case .groupEvent(let e): e.date
        case .mentoring(let m, _): m.date
        }
    }
}

// MARK: - 기록 뷰 (통합 타임라인)

struct ActivityRecordsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var showingAddActivity = false
    @State private var showingAddMentoring = false
    @State private var editingSession: MentoringSession? = nil
    @State private var showingNumbersInput = false
    @State private var numbersURLInput = ""

    private var sessionsByDate: [MentoringSession] {
        (person.mentoringSessions ?? []).sorted { $0.date < $1.date }
    }

    private var timelineItems: [RecordTimelineItem] {
        var items: [RecordTimelineItem] = []
        items += (person.activities ?? []).map { .activity($0) }
        items += (person.groupEvents ?? []).map { .groupEvent($0) }
        let sessions = sessionsByDate
        items += sessions.enumerated().map { .mentoring($1, sessionNumber: $0 + 1) }
        return items.sorted { $0.date > $1.date }
    }

    private var groupedByMonth: [(String, [RecordTimelineItem])] {
        let grouped = Dictionary(grouping: timelineItems) { $0.date.formatted(.dateTime.year().month()) }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        VStack(spacing: 0) {
            addBar
            Divider()
            if timelineItems.isEmpty && (person.numbersSharedURL ?? "").isEmpty {
                emptyState
            } else {
                timelineScroll
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingAddActivity) { ActivityEventSheet(person: person) }
        .sheet(isPresented: $showingAddMentoring) { MentoringSessionAddSheet(person: person) }
        .sheet(item: $editingSession) { MentoringSessionEditSheet(session: $0) }
        .sheet(isPresented: $showingNumbersInput) {
            NumbersLinkInputSheet(urlInput: $numbersURLInput) { url in
                person.numbersSharedURL = url
                try? context.save()
            }
        }
    }

    private var addBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                RecordAddChip(label: "활동", icon: "calendar.badge.plus", color: .blue) { showingAddActivity = true }
                RecordAddChip(label: "멘토링", icon: "waveform.and.mic", color: .purple) { showingAddMentoring = true }
                if (person.numbersSharedURL ?? "").isEmpty {
                    RecordAddChip(label: "Numbers", icon: "tablecells", color: .green) {
                        numbersURLInput = ""
                        showingNumbersInput = true
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("기록이 없어요", systemImage: "clock")
        } description: {
            Text("위 버튼으로 첫 번째 기록을 추가해보세요")
        }
    }

    private var timelineScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let url = person.numbersSharedURL, !url.isEmpty {
                    numbersLinkCard(url: url)
                        .padding(.horizontal)
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                }

                ForEach(groupedByMonth, id: \.0) { month, items in
                    Text(month)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 8)

                    ForEach(items) { item in
                        RecordTimelineItemRow(
                            item: item,
                            onEdit: { editingSession = $0 },
                            onDelete: { deleteItem(item) }
                        )
                        .padding(.horizontal)
                        .padding(.bottom, 10)
                    }
                }
                Color.clear.frame(height: 20)
            }
        }
    }

    private func numbersLinkCard(url: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "tablecells.fill")
                .font(.title3)
                .foregroundStyle(.green)
            if let link = URL(string: url) {
                Link(destination: link) {
                    Text(url)
                        .font(.body)
                        .foregroundStyle(.green)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                person.numbersSharedURL = nil
                try? context.save()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Color.green.opacity(0.08))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.green.opacity(0.2), lineWidth: 1))
    }

    private func deleteItem(_ item: RecordTimelineItem) {
        switch item {
        case .activity(let r): context.delete(r)
        case .groupEvent(let e): context.delete(e)
        case .mentoring(let m, _): context.delete(m)
        }
        try? context.save()
    }
}

// MARK: - 타임라인 행

private struct RecordTimelineItemRow: View {
    let item: RecordTimelineItem
    let onEdit: (MentoringSession) -> Void
    let onDelete: () -> Void

    var body: some View {
        Group {
            switch item {
            case .activity(let record):
                ActivityRecordRow(record: record, onDelete: onDelete)
            case .groupEvent(let event):
                GroupEventRow(event: event, onDelete: onDelete)
            case .mentoring(let session, let number):
                MentoringSessionRow(
                    session: session,
                    sessionNumber: number,
                    onEdit: { onEdit(session) },
                    onDelete: onDelete
                )
            }
        }
    }
}

// MARK: - 추가 칩

private struct RecordAddChip: View {
    let label: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.body)
                Text(label).font(.body).fontWeight(.medium)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 활동 기록 행

private struct ActivityRecordRow: View {
    let record: ActivityRecord
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(record.type.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(record.type.color.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.type.title)
                    .font(.body)
                    .fontWeight(.medium)
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.body)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - 활동 / 이벤트 통합 시트

struct ActivityEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var allPeople: [Person]

    let person: Person

    enum Kind { case meeting, event }
    @State private var kind: Kind = .meeting

    // 만남
    @State private var meetType: ActivityType = .meeting
    @State private var meetDate = Date()
    @State private var meetNotes = ""

    // 이벤트
    @State private var eventTitle = ""
    @State private var eventType: ActivityType = .travel
    @State private var eventDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var eventNotes = ""
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    private var canSave: Bool {
        kind == .meeting || !eventTitle.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("", selection: $kind) {
                        Text("만남").tag(Kind.meeting)
                        Text("이벤트").tag(Kind.event)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                if kind == .meeting {
                    meetingFields
                } else {
                    eventFields
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle(kind == .meeting ? "만남 기록" : "이벤트 기록")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear {
                selectedIDs.insert(person.persistentModelID)
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 520)
        #endif
    }

    @ViewBuilder
    private var meetingFields: some View {
        Section("종류") {
            activityTypePicker(selected: $meetType)
        }
        Section("날짜") {
            DatePicker("날짜", selection: $meetDate, displayedComponents: .date).labelsHidden()
        }
        Section("메모 (선택)") {
            TextField("무슨 일이 있었나요?", text: $meetNotes, axis: .vertical).lineLimit(3...6)
        }
    }

    @ViewBuilder
    private var eventFields: some View {
        Section("이벤트 이름") {
            TextField("예: 제주도 여행, 팀 회식", text: $eventTitle)
        }
        Section("종류") {
            activityTypePicker(selected: $eventType)
        }
        Section("날짜") {
            DatePicker("날짜", selection: $eventDate, displayedComponents: .date)
            Toggle("종료일 있음", isOn: $hasEndDate)
            if hasEndDate {
                DatePicker("종료일", selection: $endDate, in: eventDate..., displayedComponents: .date)
            }
        }
        Section("함께한 사람 \(selectedIDs.isEmpty ? "" : "(\(selectedIDs.count)명)")") {
            if allPeople.isEmpty {
                Text("등록된 사람이 없습니다").foregroundStyle(.secondary)
            } else {
                ForEach(allPeople) { p in
                    ActivityPersonPickerRow(
                        person: p,
                        isSelected: selectedIDs.contains(p.persistentModelID)
                    ) {
                        if selectedIDs.contains(p.persistentModelID) {
                            selectedIDs.remove(p.persistentModelID)
                        } else {
                            selectedIDs.insert(p.persistentModelID)
                        }
                    }
                }
            }
        }
        Section("메모 (선택)") {
            TextField("어떤 시간이었나요?", text: $eventNotes, axis: .vertical).lineLimit(3...6)
        }
    }

    @ViewBuilder
    private func activityTypePicker(selected: Binding<ActivityType>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(ActivityType.allCases) { type in
                    Button { selected.wrappedValue = type } label: {
                        VStack(spacing: 4) {
                            Text(type.emoji).font(.title)
                            Text(type.title).font(.body)
                        }
                        .frame(width: 70, height: 70)
                        .background(selected.wrappedValue == type ? type.color.opacity(0.2) : Color.secondary.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected.wrappedValue == type ? type.color : Color.clear, lineWidth: 2))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
    }

    private func save() {
        if kind == .meeting {
            let record = ActivityRecord(date: meetDate, type: meetType, notes: meetNotes)
            record.person = person
            person.activities = (person.activities ?? []) + [record]
        } else {
            let event = GroupEvent(
                title: eventTitle.trimmingCharacters(in: .whitespaces),
                type: eventType,
                date: eventDate,
                endDate: hasEndDate ? endDate : nil,
                notes: eventNotes
            )
            event.participants = allPeople.filter { selectedIDs.contains($0.persistentModelID) }
            context.insert(event)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - 사람 선택 행 (ActivityEventSheet용)

private struct ActivityPersonPickerRow: View {
    let person: Person
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Group {
                    #if os(iOS)
                    if let data = person.profileImageData, let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill").resizable().foregroundStyle(.gray)
                    }
                    #else
                    if let data = person.profileImageData, let img = NSImage(data: data) {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill").resizable().foregroundStyle(.gray)
                    }
                    #endif
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                Text(person.name).foregroundStyle(.primary)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Numbers 링크 입력 시트

struct NumbersLinkInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var urlInput: String
    let onSave: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "tablecells.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)

                Text("Numbers 공유 링크를 붙여넣으세요")
                    .font(.headline)

                Text("Numbers 앱에서 공유 > 공동 작업 초대 > 링크 복사로 링크를 얻을 수 있어요")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                TextField("https://www.icloud.com/numbers/...", text: $urlInput, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(3)
                    .padding(.horizontal)
                #if os(macOS)
                    .frame(minWidth: 300)
                #endif

                Button {
                    #if os(macOS)
                    if let string = NSPasteboard.general.string(forType: .string) {
                        urlInput = string
                    }
                    #else
                    if let string = UIPasteboard.general.string {
                        urlInput = string
                    }
                    #endif
                } label: {
                    Label("클립보드에서 붙여넣기", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)

                Spacer()
            }
            .padding(.top, 24)
            .navigationTitle("공유 링크 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        if !urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            onSave(urlInput.trimmingCharacters(in: .whitespacesAndNewlines))
                        }
                        dismiss()
                    }
                    .disabled(urlInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 350)
        #endif
    }
}

// MARK: - 만남 시작 시트

struct MeetingSessionSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var person: Person

    @State private var selectedType: ActivityType = .meeting
    @State private var date: Date = Date()
    @State private var activityNotes: String = ""
    @State private var memoText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                // 어떤 만남인지
                Section("어떤 만남이었나요?") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ActivityType.allCases) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(type.emoji)
                                            .font(.title2)
                                        Text(type.title)
                                            .font(.body)
                                    }
                                    .frame(width: 64, height: 64)
                                    .background(selectedType == type ? type.color.opacity(0.2) : Color.secondary.opacity(0.08))
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(selectedType == type ? type.color : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("날짜") {
                    DatePicker("날짜", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                }

                // 오늘 있었던 일 요약
                Section("오늘 있었던 일 (선택)") {
                    TextField("어디서 만났나요? 무슨 얘기를 했나요?", text: $activityNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                // 알게 된 것들 (파편 메모)
                Section {
                    TextField("\"포항 출신\", \"커피 싫어함\", \"누나 한 명\" 처럼 짧게 적어보세요", text: $memoText, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("알게 된 것들 (선택)")
                } footer: {
                    Text("나중에 지도에서 영역별로 정리할 수 있어요")
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("\(person.name)와의 만남")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("기록하기") { save() }
                        .fontWeight(.semibold)
                        .disabled(selectedType == .meeting && activityNotes.isEmpty && memoText.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 460, height: 540)
        #endif
    }

    private func save() {
        // 활동 기록 저장
        let record = ActivityRecord(date: date, type: selectedType, notes: activityNotes)
        record.person = person
        person.activities = (person.activities ?? []) + [record]

        // 메모 저장 (입력이 있을 때만)
        let trimmedMemo = memoText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedMemo.isEmpty {
            let note = PersonNote(content: trimmedMemo, date: date)
            note.person = person
            person.notes = (person.notes ?? []) + [note]
        }

        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)
    
    let person = Person(name: "김철수", depth: .personal)
    container.mainContext.insert(person)
    
    person.addDiscovery(territory: .nickname, content: "달빛이라는 닉네임, 밤에 산책하는 걸 좋아해서", emotion: .closer)
    person.addDiscovery(territory: .hobby, content: "등산을 좋아함, 주말마다 감")
    person.addDiscovery(territory: .currentConcern, content: "이직 고민중", emotion: .understood, isSignificant: true)
    
    return NavigationStack {
        PersonDetailView(person: person)
    }
    .modelContainer(container)
}
