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
            // 탭 선택
            tabPicker

            // 탭 콘텐츠
            #if os(macOS)
            Group {
                switch selectedTab {
                case .map:      PersonMapView(person: person)
                case .timeline: DiscoveryTimelineView(person: person)
                case .memo:     PersonMemoView(person: person)
                case .records:  ActivityRecordsView(person: person)
                case .info:     PersonInfoView(person: person)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            TabView(selection: $selectedTab) {
                PersonMapView(person: person)
                    .tag(DetailTab.map)
                DiscoveryTimelineView(person: person)
                    .tag(DetailTab.timeline)
                PersonMemoView(person: person)
                    .tag(DetailTab.memo)
                ActivityRecordsView(person: person)
                    .tag(DetailTab.records)
                PersonInfoView(person: person)
                    .tag(DetailTab.info)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            #endif
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
                    VStack(spacing: 3) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.title)
                            .font(.system(size: 10))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 54)
                .background(selectedTab == tab ? Color.accentColor.opacity(0.15) : Color.clear)
                .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.secondary)
                .contentShape(Rectangle())
            }

        }
        .background(Color.secondaryBackground)
    }
}

// MARK: - 탭

enum DetailTab: String, CaseIterable {
    case map
    case timeline
    case memo
    case records
    case info

    var title: String {
        switch self {
        case .map:      return "지도"
        case .timeline: return "발견들"
        case .memo:     return "메모"
        case .records:  return "기록"
        case .info:     return "정보"
        }
    }

    var icon: String {
        switch self {
        case .map:      return "map"
        case .timeline: return "clock"
        case .memo:     return "note.text"
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(discovery.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    if discovery.isSignificant {
                        Image(systemName: "star.fill")
                            .font(.caption)
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
                    .font(.caption)
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
                                    .font(.caption)
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
                .font(.caption)
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

// MARK: - 기록 뷰

struct ActivityRecordsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var showingAddActivity = false
    @State private var showingGroupEvent = false
    @State private var showingNumbersInput = false
    @State private var numbersURLInput = ""

    private var sortedActivities: [ActivityRecord] {
        (person.activities ?? []).sorted { $0.date > $1.date }
    }

    private var sortedGroupEvents: [GroupEvent] {
        (person.groupEvents ?? []).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                numbersSection
                groupEventsSection
                activitiesSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .sheet(isPresented: $showingAddActivity) {
            AddActivitySheet(person: person)
        }
        .sheet(isPresented: $showingGroupEvent) {
            GroupEventSheet(person: person)
        }
    }

    // MARK: - Numbers 공유 문서 섹션

    private var numbersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "tablecells")
                    .foregroundStyle(.green)
                Text("Numbers 공유 문서")
                    .font(.headline)
                Spacer()
            }

            if let urlString = person.numbersSharedURL, !urlString.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(urlString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    HStack(spacing: 10) {
                        if let url = URL(string: urlString) {
                            Link(destination: url) {
                                Label("Numbers에서 열기", systemImage: "arrow.up.right.square")
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.green.opacity(0.15))
                                    .foregroundStyle(.green)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }

                        Button(role: .destructive) {
                            person.numbersSharedURL = nil
                            try? context.save()
                        } label: {
                            Label("제거", systemImage: "trash")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.red.opacity(0.1))
                                .foregroundStyle(.red)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.06))
                .cornerRadius(10)
            } else {
                Button {
                    numbersURLInput = ""
                    showingNumbersInput = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("공유 링크 추가")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }
        }
        .sheet(isPresented: $showingNumbersInput) {
            NumbersLinkInputSheet(urlInput: $numbersURLInput) { url in
                person.numbersSharedURL = url
                try? context.save()
            }
        }
    }

    // MARK: - 그룹 이벤트 섹션

    private var groupEventsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundStyle(.cyan)
                Text("함께한 이벤트")
                    .font(.headline)
                Spacer()
                Button {
                    showingGroupEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)
            }

            if sortedGroupEvents.isEmpty {
                Button {
                    showingGroupEvent = true
                } label: {
                    HStack {
                        Image(systemName: "airplane")
                        Text("여행, 식사 등 함께한 이벤트 기록")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.cyan.opacity(0.08))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedGroupEvents) { event in
                        GroupEventRow(event: event) {
                            context.delete(event)
                            try? context.save()
                        }
                    }
                }
            }
        }
    }

    // MARK: - 활동 기록 섹션

    private var activitiesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "list.bullet.clipboard")
                    .foregroundStyle(.blue)
                Text("활동 기록")
                    .font(.headline)
                Spacer()
                Button {
                    showingAddActivity = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }

            // 빠른 추가 버튼
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ActivityType.allCases) { type in
                        QuickAddActivityButton(type: type) {
                            let record = ActivityRecord(type: type)
                            record.person = person
                            person.activities = (person.activities ?? []) + [record]
                            try? context.save()
                        }
                    }
                }
            }

            if sortedActivities.isEmpty {
                ContentUnavailableView {
                    Label("기록이 없어요", systemImage: "list.bullet.clipboard")
                } description: {
                    Text("위 버튼으로 빠르게 기록하거나 + 버튼으로 상세 기록을 추가해보세요")
                }
                .frame(minHeight: 200)
            } else {
                VStack(spacing: 8) {
                    ForEach(sortedActivities) { record in
                        ActivityRecordRow(record: record) {
                            context.delete(record)
                            try? context.save()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - 빠른 추가 버튼

private struct QuickAddActivityButton: View {
    let type: ActivityType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(type.emoji)
                    .font(.title2)
                Text(type.title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, height: 60)
            .background(type.color.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(type.color.opacity(0.3), lineWidth: 1)
            )
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
                    .font(.subheadline)
                    .fontWeight(.medium)
                if !record.notes.isEmpty {
                    Text(record.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Text(record.date.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(.secondary)

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}

// MARK: - 활동 추가 시트

struct AddActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let person: Person

    @State private var selectedType: ActivityType = .meeting
    @State private var notes = ""
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("활동 종류") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ActivityType.allCases) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(type.emoji)
                                            .font(.title)
                                        Text(type.title)
                                            .font(.caption)
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(selectedType == type ? type.color.opacity(0.2) : Color.secondary.opacity(0.08))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
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

                Section("메모 (선택)") {
                    TextField("무슨 일이 있었나요?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("활동 기록 추가")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        let record = ActivityRecord(date: date, type: selectedType, notes: notes)
                        record.person = person
                        person.activities = (person.activities ?? []) + [record]
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        #if os(macOS)
        .frame(width: 420, height: 480)
        #endif
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
                    .font(.caption)
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
                                            .font(.caption)
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
