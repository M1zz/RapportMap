//
//  PeopleFilterView.swift
//  RapportMap
//
//  검색 및 필터 뷰 - 프리셋, 태그, 기간 필터 지원
//

import SwiftUI
import SwiftData

struct PeopleFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \PersonTag.order) private var allTags: [PersonTag]
    @Binding var filterOptions: FilterOptions
    let peopleCount: Int
    let filteredCount: Int
    
    @State private var showingTagManagement = false
    @State private var showingAddPreset = false
    @State private var newPresetName = ""
    @StateObject private var presetsManager = FilterPresetsManager()
    
    // 카테고리별로 그룹화된 태그들
    private var groupedTags: [TagCategory: [PersonTag]] {
        Dictionary(grouping: allTags, by: { $0.category })
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // 현재 필터 상태 요약
                currentFilterSection
                
                // 빠른 필터 프리셋
                presetSection
                
                // 검색 범위 설정
                searchScopeSection
                
                // 정렬 섹션
                sortSection
                
                // 태그 필터 섹션
                tagFilterSection
                
                // 기간 필터 섹션
                dateFilterSection

                // 특별 상태 섹션
                specialStatusSection
                
                // 마지막 접촉 섹션
                lastContactSection
                
                // 초기화 섹션
                resetSection
            }
            .navigationTitle("검색 & 필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        filterOptions.save()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingTagManagement) {
                TagManagementView()
            }
            .alert("프리셋 저장", isPresented: $showingAddPreset) {
                TextField("프리셋 이름", text: $newPresetName)
                Button("취소", role: .cancel) {
                    newPresetName = ""
                }
                Button("저장") {
                    saveCurrentAsPreset()
                }
            } message: {
                Text("현재 필터 설정을 프리셋으로 저장합니다.")
            }
            .onAppear {
                DataSeeder.seedDefaultTagsIfNeeded(context: context)
            }
        }
    }
    
    // MARK: - Current Filter Section
    
    @ViewBuilder
    private var currentFilterSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("전체 \(peopleCount)명 중 \(filteredCount)명 표시")
                        .font(.headline)
                    
                    if filterOptions.hasActiveFilters {
                        Text(filterOptions.filterSummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if filterOptions.hasActiveFilters {
                    Text("\(filterOptions.activeFilterCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.blue))
                }
            }
            
            // 활성화된 필터 칩들
            if filterOptions.hasActiveFilters {
                activeFilterChips
            }
        }
    }
    
    @ViewBuilder
    private var activeFilterChips: some View {
        FlowLayout(spacing: 6) {
            if filterOptions.showNeglectedOnly {
                ActiveFilterChip(label: "소홀함", color: .red) {
                    filterOptions.showNeglectedOnly = false
                }
            }
            
            if filterOptions.showWithIncompleteActionsOnly {
                ActiveFilterChip(label: "미완료 액션", color: .orange) {
                    filterOptions.showWithIncompleteActionsOnly = false
                }
            }
            
            if filterOptions.showWithCriticalActionsOnly {
                ActiveFilterChip(label: "긴급 액션", color: .red) {
                    filterOptions.showWithCriticalActionsOnly = false
                }
            }
            
            if !filterOptions.selectedTagIDs.isEmpty {
                ActiveFilterChip(label: "태그 \(filterOptions.selectedTagIDs.count)개", color: .purple) {
                    filterOptions.clearTagFilter()
                }
            }
            
            if filterOptions.dateRangeFilter != .all {
                ActiveFilterChip(label: filterOptions.dateRangeFilter.rawValue, color: .blue) {
                    filterOptions.dateRangeFilter = .all
                }
            }
            
            if let days = filterOptions.recentInteractionDays {
                ActiveFilterChip(label: "최근 \(days)일 상담", color: .green) {
                    filterOptions.recentInteractionDays = nil
                }
            }
            
            if let days = filterOptions.lastContactDays {
                ActiveFilterChip(label: "\(days)일 이내 접촉", color: .teal) {
                    filterOptions.lastContactDays = nil
                }
            }
        }
    }
    
    // MARK: - Preset Section
    
    @ViewBuilder
    private var presetSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presetsManager.presets) { preset in
                        PresetButton(preset: preset) {
                            applyPreset(preset)
                        }
                    }
                    
                    // 현재 필터를 프리셋으로 저장
                    if filterOptions.hasActiveFilters {
                        Button {
                            showingAddPreset = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("저장")
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                            .foregroundStyle(.blue)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        } header: {
            Text("⚡️ 빠른 필터")
        }
    }
    
    // MARK: - Search Scope Section
    
    @ViewBuilder
    private var searchScopeSection: some View {
        Section {
            Picker("검색 범위", selection: $filterOptions.searchScope) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    HStack {
                        Image(systemName: scope.systemImage)
                        Text(scope.rawValue)
                    }
                    .tag(scope)
                }
            }
            
            Text("검색창에서 입력 시 선택한 범위 내에서만 검색합니다.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("🔍 검색 범위")
        }
    }
    
    // MARK: - Sort Section
    
    @ViewBuilder
    private var sortSection: some View {
        Section("정렬") {
            Picker("정렬 기준", selection: $filterOptions.sortOption) {
                ForEach(SortOption.allCases, id: \.self) { option in
                    HStack {
                        Image(systemName: option.systemImage)
                        Text(option.rawValue)
                    }
                    .tag(option)
                }
            }

            Toggle(isOn: $filterOptions.sortAscending) {
                HStack {
                    Image(systemName: filterOptions.sortAscending ? "arrow.up" : "arrow.down")
                    Text(filterOptions.sortAscending ? "오름차순" : "내림차순")
                }
            }
        }
    }
    
    // MARK: - Date Filter Section
    
    @ViewBuilder
    private var dateFilterSection: some View {
        Section {
            Picker("기간", selection: $filterOptions.dateRangeFilter) {
                ForEach(DateRangeFilter.allCases, id: \.self) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            
            // 직접 설정 시 날짜 선택
            if filterOptions.dateRangeFilter == .custom {
                DatePicker("시작일", selection: Binding(
                    get: { filterOptions.customDateFrom ?? Date() },
                    set: { filterOptions.customDateFrom = $0 }
                ), displayedComponents: .date)
                
                DatePicker("종료일", selection: Binding(
                    get: { filterOptions.customDateTo ?? Date() },
                    set: { filterOptions.customDateTo = $0 }
                ), displayedComponents: .date)
            }
            
            // 최근 상담 필터
            Picker("최근 상담", selection: $filterOptions.recentInteractionDays) {
                Text("전체").tag(nil as Int?)
                Text("오늘").tag(0 as Int?)
                Text("최근 3일").tag(3 as Int?)
                Text("최근 1주일").tag(7 as Int?)
                Text("최근 2주일").tag(14 as Int?)
                Text("최근 1개월").tag(30 as Int?)
            }
        } header: {
            Text("📅 기간 필터")
        } footer: {
            Text("\"최근 상담\"은 해당 기간 내에 상호작용이 있는 사람만 표시합니다.")
        }
    }
    
    // MARK: - Tag Filter Section
    
    @ViewBuilder
    private var tagFilterSection: some View {
        Section {
            // 태그 필터 모드 선택
            if !filterOptions.selectedTagIDs.isEmpty {
                Picker("필터 조건", selection: $filterOptions.tagFilterMode) {
                    ForEach(TagFilterMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                
                Text(filterOptions.tagFilterMode.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // 태그 선택
            ForEach(TagCategory.allCases) { category in
                if let categoryTags = groupedTags[category], !categoryTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(category.emoji) \(category.rawValue)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(categoryTags.sorted { $0.order < $1.order }) { tag in
                                tagToggleButton(for: tag)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 태그 관리 버튼
            Button {
                showingTagManagement = true
            } label: {
                HStack {
                    Image(systemName: "tag.fill")
                    Text("태그 관리")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 선택된 태그 초기화
            if !filterOptions.selectedTagIDs.isEmpty {
                Button("태그 필터 초기화") {
                    filterOptions.clearTagFilter()
                }
                .foregroundStyle(.red)
            }
        } header: {
            HStack {
                Text("🏷️ 태그 필터")
                if !filterOptions.selectedTagIDs.isEmpty {
                    Text("(\(filterOptions.selectedTagIDs.count)개 선택)")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
    }
    
    private func tagToggleButton(for tag: PersonTag) -> some View {
        let isSelected = filterOptions.selectedTagIDs.contains(tag.id)
        
        return Button {
            if isSelected {
                filterOptions.selectedTagIDs.removeAll { $0 == tag.id }
            } else {
                filterOptions.selectedTagIDs.append(tag.id)
            }
        } label: {
            HStack(spacing: 4) {
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(tag.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(isSelected ? tag.swiftUIColor : tag.swiftUIColor.opacity(0.15))
            )
            .overlay(
                Capsule()
                    .strokeBorder(tag.swiftUIColor, lineWidth: 1)
            )
            .foregroundStyle(isSelected ? .white : tag.swiftUIColor)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Special Status Section
    
    @ViewBuilder
    private var specialStatusSection: some View {
        Section("특별 상태") {
            Toggle("소홀한 관계만", isOn: $filterOptions.showNeglectedOnly)
            Toggle("미완료 액션이 있는 사람만", isOn: $filterOptions.showWithIncompleteActionsOnly)
            Toggle("긴급 액션이 있는 사람만", isOn: $filterOptions.showWithCriticalActionsOnly)
        }
    }
    
    // MARK: - Last Contact Section
    
    @ViewBuilder
    private var lastContactSection: some View {
        Section("마지막 접촉") {
            Picker("최근 접촉 기준", selection: $filterOptions.lastContactDays) {
                Text("전체").tag(nil as Int?)
                Text("1주일 이내").tag(7 as Int?)
                Text("2주일 이내").tag(14 as Int?)
                Text("1개월 이내").tag(30 as Int?)
                Text("3개월 이내").tag(90 as Int?)
            }
            
            if filterOptions.lastContactDays != nil {
                Toggle("접촉 기록 없는 사람 포함", isOn: $filterOptions.includeNeverContacted)
            }
        }
    }
    
    // MARK: - Reset Section
    
    @ViewBuilder
    private var resetSection: some View {
        Section {
            Button(role: .destructive) {
                filterOptions.clearAllFilters()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("모든 필터 초기화")
                }
            }
            .disabled(!filterOptions.hasActiveFilters)
        }
    }
    
    // MARK: - Helper Methods
    
    private func applyPreset(_ preset: FilterPreset) {
        filterOptions = preset.filterOptions
    }
    
    private func saveCurrentAsPreset() {
        guard !newPresetName.isEmpty else { return }
        
        let preset = FilterPreset(
            name: newPresetName,
            icon: "slider.horizontal.3",
            filterOptions: filterOptions
        )
        presetsManager.addPreset(preset)
        newPresetName = ""
    }
}

// MARK: - Active Filter Chip (필터 뷰 전용)

struct ActiveFilterChip: View {
    let label: String
    let color: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundStyle(color)
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let preset: FilterPreset
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: preset.icon)
                    .font(.caption)
                Text(preset.name)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
            )
            .foregroundStyle(.blue)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PeopleFilterView(
        filterOptions: .constant(FilterOptions()),
        peopleCount: 50,
        filteredCount: 30
    )
}
