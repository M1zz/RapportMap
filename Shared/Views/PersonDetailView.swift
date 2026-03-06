//
//  PersonDetailView.swift
//  RapportMap
//
//  사람 상세 뷰 - 지도 + 타임라인 + 정보
//

import SwiftUI
import SwiftData

struct PersonDetailView: View {
    @Bindable var person: Person
    
    @State private var selectedTab: DetailTab = .map
    
    var body: some View {
        VStack(spacing: 0) {
            // 탭 선택
            tabPicker

            // 탭 콘텐츠
            #if os(macOS)
            Group {
                switch selectedTab {
                case .map: PersonMapView(person: person)
                case .timeline: DiscoveryTimelineView(person: person)
                case .info: PersonInfoView(person: person)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            TabView(selection: $selectedTab) {
                PersonMapView(person: person)
                    .tag(DetailTab.map)
                DiscoveryTimelineView(person: person)
                    .tag(DetailTab.timeline)
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
    }
    
    private var tabPicker: some View {
        Picker("탭", selection: $selectedTab) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Label(tab.title, systemImage: tab.icon)
                    .tag(tab)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding()
    }
}

// MARK: - 탭

enum DetailTab: String, CaseIterable {
    case map
    case timeline
    case info
    
    var title: String {
        switch self {
        case .map: return "지도"
        case .timeline: return "발견들"
        case .info: return "정보"
        }
    }
    
    var icon: String {
        switch self {
        case .map: return "map"
        case .timeline: return "clock"
        case .info: return "info.circle"
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

            if person.discoveries.isEmpty {
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
    @Bindable var person: Person
    
    @State private var isEditingMemo = false
    @State private var showingDepthSheet = false
    
    var body: some View {
        Form {
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
        }
        #if os(macOS)
        .formStyle(.grouped)
        #endif
        .sheet(isPresented: $showingDepthSheet) {
            DepthSettingSheet(person: person)
        }
    }
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
