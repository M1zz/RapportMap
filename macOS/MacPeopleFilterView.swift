//
//  MacPeopleFilterView.swift
//  mac
//
//  macOS용 필터 화면 - 프리셋, 태그, 기간 필터 지원
//

import SwiftUI
import SwiftData

struct MacPeopleFilterView: View {
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
        VStack(spacing: 0) {
            // 헤더
            headerView
            
            Divider()

            // 메인 컨텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 현재 필터 상태
                    currentFilterStatus
                    
                    // 빠른 필터 프리셋
                    presetSection
                    
                    // 검색 범위 설정
                    searchScopeSection
                    
                    // 정렬 옵션
                    sortSection

                    // 태그 필터
                    tagFilterSection
                    
                    // 기간 필터
                    dateFilterSection

                    // 특별 상태 필터
                    specialStatusSection

                    // 마지막 접촉 필터
                    lastContactSection

                    // 초기화 버튼
                    resetSection
                }
                .padding()
            }
        }
        .frame(width: 450, height: 700)
        .sheet(isPresented: $showingTagManagement) {
            MacTagManagementView()
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
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("검색 & 필터")
                .font(.title2)
                .fontWeight(.bold)
            Spacer()
            Button("완료") {
                filterOptions.save()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Current Filter Status
    
    @ViewBuilder
    private var currentFilterStatus: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("전체 \(peopleCount)명 중 \(filteredCount)명 표시")
                        .font(.headline)
                    
                    Spacer()
                    
                    if filterOptions.hasActiveFilters {
                        Text("\(filterOptions.activeFilterCount)개 필터 적용")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.blue))
                            .foregroundStyle(.white)
                    }
                }
                
                if filterOptions.hasActiveFilters {
                    Text(filterOptions.filterSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    // 활성화된 필터 칩들
                    activeFilterChips
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var activeFilterChips: some View {
        FlowLayout(spacing: 6) {
            if filterOptions.showNeglectedOnly {
                MacFilterChip(label: "소홀함", color: .red) {
                    filterOptions.showNeglectedOnly = false
                }
            }
            
            if filterOptions.showWithIncompleteActionsOnly {
                MacFilterChip(label: "미완료 액션", color: .orange) {
                    filterOptions.showWithIncompleteActionsOnly = false
                }
            }
            
            if filterOptions.showWithCriticalActionsOnly {
                MacFilterChip(label: "긴급 액션", color: .red) {
                    filterOptions.showWithCriticalActionsOnly = false
                }
            }
            
            if !filterOptions.selectedTagIDs.isEmpty {
                MacFilterChip(label: "태그 \(filterOptions.selectedTagIDs.count)개", color: .purple) {
                    filterOptions.clearTagFilter()
                }
            }
            
            if filterOptions.dateRangeFilter != .all {
                MacFilterChip(label: filterOptions.dateRangeFilter.rawValue, color: .blue) {
                    filterOptions.dateRangeFilter = .all
                }
            }
            
            if let days = filterOptions.recentInteractionDays {
                MacFilterChip(label: "최근 \(days)일 상담", color: .green) {
                    filterOptions.recentInteractionDays = nil
                }
            }
        }
    }
    
    // MARK: - Preset Section
    
    @ViewBuilder
    private var presetSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("⚡️ 빠른 필터")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                FlowLayout(spacing: 8) {
                    ForEach(presetsManager.presets) { preset in
                        Button {
                            filterOptions = preset.filterOptions
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: preset.icon)
                                    .font(.caption)
                                Text(preset.name)
                                    .font(.caption)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.blue.opacity(0.1))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if filterOptions.hasActiveFilters {
                        Button {
                            showingAddPreset = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("저장")
                            }
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .strokeBorder(Color.blue, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Search Scope Section
    
    @ViewBuilder
    private var searchScopeSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("🔍 검색 범위")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Picker("검색 범위", selection: $filterOptions.searchScope) {
                    ForEach(SearchScope.allCases, id: \.self) { scope in
                        HStack {
                            Image(systemName: scope.systemImage)
                            Text(scope.rawValue)
                        }
                        .tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("검색창에서 입력 시 선택한 범위 내에서만 검색합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    // MARK: - Sort Section
    
    @ViewBuilder
    private var sortSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("정렬")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Picker("정렬 기준", selection: $filterOptions.sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        HStack {
                            Image(systemName: option.systemImage)
                            Text(option.rawValue)
                        }
                        .tag(option)
                    }
                }
                .pickerStyle(.menu)
                
                Toggle(isOn: $filterOptions.sortAscending) {
                    HStack {
                        Image(systemName: filterOptions.sortAscending ? "arrow.up" : "arrow.down")
                        Text(filterOptions.sortAscending ? "오름차순" : "내림차순")
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Tag Filter Section
    
    @ViewBuilder
    private var tagFilterSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("🏷️ 태그 필터")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    
                    if !filterOptions.selectedTagIDs.isEmpty {
                        Text("(\(filterOptions.selectedTagIDs.count)개 선택)")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    Button("태그 관리") {
                        showingTagManagement = true
                    }
                    .font(.caption)
                }
                
                if !filterOptions.selectedTagIDs.isEmpty {
                    Picker("필터 조건", selection: $filterOptions.tagFilterMode) {
                        ForEach(TagFilterMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                ForEach(TagCategory.allCases) { category in
                    if let categoryTags = groupedTags[category], !categoryTags.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(category.emoji) \(category.rawValue)")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            FlowLayout(spacing: 6) {
                                ForEach(categoryTags.sorted { $0.order < $1.order }) { tag in
                                    tagToggleButton(for: tag)
                                }
                            }
                        }
                    }
                }
                
                if !filterOptions.selectedTagIDs.isEmpty {
                    Button("태그 필터 초기화") {
                        filterOptions.clearTagFilter()
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            .padding()
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
            HStack(spacing: 3) {
                if let icon = tag.icon {
                    Image(systemName: icon)
                        .font(.caption2)
                }
                Text(tag.name)
                    .font(.caption)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(isSelected ? tag.swiftUIColor : tag.swiftUIColor.opacity(0.15))
            )
            .foregroundStyle(isSelected ? .white : tag.swiftUIColor)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Date Filter Section
    
    @ViewBuilder
    private var dateFilterSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("📅 기간 필터")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Picker("기간", selection: $filterOptions.dateRangeFilter) {
                    ForEach(DateRangeFilter.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                
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
                
                Divider()
                
                Picker("최근 상담", selection: $filterOptions.recentInteractionDays) {
                    Text("전체").tag(nil as Int?)
                    Text("오늘").tag(0 as Int?)
                    Text("최근 3일").tag(3 as Int?)
                    Text("최근 1주일").tag(7 as Int?)
                    Text("최근 2주일").tag(14 as Int?)
                    Text("최근 1개월").tag(30 as Int?)
                }
                .pickerStyle(.menu)
                
                Text("\"최근 상담\"은 해당 기간 내에 상호작용이 있는 사람만 표시합니다.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }

    // MARK: - Special Status Section
    
    @ViewBuilder
    private var specialStatusSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("특별 상태")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Toggle("소홀한 관계만", isOn: $filterOptions.showNeglectedOnly)
                Toggle("미완료 액션이 있는 사람만", isOn: $filterOptions.showWithIncompleteActionsOnly)
                Toggle("긴급 액션이 있는 사람만", isOn: $filterOptions.showWithCriticalActionsOnly)
            }
            .padding()
        }
    }

    // MARK: - Last Contact Section
    
    @ViewBuilder
    private var lastContactSection: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Text("마지막 접촉")
                    .font(.headline)
                    .foregroundStyle(.secondary)

                Picker("최근 접촉 기준", selection: $filterOptions.lastContactDays) {
                    Text("전체").tag(nil as Int?)
                    Text("1주일 이내").tag(7 as Int?)
                    Text("2주일 이내").tag(14 as Int?)
                    Text("1개월 이내").tag(30 as Int?)
                    Text("3개월 이내").tag(90 as Int?)
                }
                .pickerStyle(.menu)

                if filterOptions.lastContactDays != nil {
                    Toggle("접촉 기록 없는 사람 포함", isOn: $filterOptions.includeNeverContacted)
                }
            }
            .padding()
        }
    }

    // MARK: - Reset Section
    
    @ViewBuilder
    private var resetSection: some View {
        Button {
            filterOptions.clearAllFilters()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("모든 필터 초기화")
            }
            .frame(maxWidth: .infinity)
        }
        .disabled(!filterOptions.hasActiveFilters)
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    
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

// MARK: - Mac Filter Chip

struct MacFilterChip: View {
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
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
        .foregroundStyle(color)
    }
}

// MARK: - Mac Tag Management View Stub
// 실제 구현은 TagManagementView.swift에 있음

struct MacTagManagementView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("태그 관리")
                .font(.title2)
                .padding()
            
            Text("TagManagementView 구현 필요")
                .foregroundStyle(.secondary)
            
            Button("닫기") {
                dismiss()
            }
            .padding()
        }
        .frame(width: 400, height: 500)
    }
}

#Preview {
    MacPeopleFilterView(
        filterOptions: .constant(FilterOptions()),
        peopleCount: 10,
        filteredCount: 5
    )
}
