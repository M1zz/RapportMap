//
//  FilterOptions.swift
//  RapportMap
//
//  필터 옵션 모델 - 검색/필터/정렬 통합 관리
//

import SwiftUI
import Foundation
import Combine

// MARK: - Sort Option

enum SortOption: String, CaseIterable, Codable {
    case name = "이름순"
    case lastContact = "최근 접촉순"
    case incompleteActions = "미완료 액션순"
    case criticalActions = "긴급 액션순"
    case relationshipStart = "관계 시작일순"

    var systemImage: String {
        switch self {
        case .name: return "textformat"
        case .lastContact: return "clock"
        case .incompleteActions: return "checklist"
        case .criticalActions: return "exclamationmark.triangle"
        case .relationshipStart: return "calendar"
        }
    }
}

// MARK: - Search Scope

enum SearchScope: String, CaseIterable, Codable {
    case all = "전체"
    case name = "이름"
    case contact = "연락처"
    case memo = "메모"
    case conversation = "대화기록"
    
    var systemImage: String {
        switch self {
        case .all: return "magnifyingglass"
        case .name: return "person"
        case .contact: return "phone"
        case .memo: return "note.text"
        case .conversation: return "bubble.left.and.bubble.right"
        }
    }
}

// MARK: - Date Range Filter

enum DateRangeFilter: String, CaseIterable, Codable {
    case all = "전체 기간"
    case today = "오늘"
    case week = "최근 1주일"
    case twoWeeks = "최근 2주일"
    case month = "최근 1개월"
    case threeMonths = "최근 3개월"
    case custom = "직접 설정"
    
    var days: Int? {
        switch self {
        case .all: return nil
        case .today: return 0
        case .week: return 7
        case .twoWeeks: return 14
        case .month: return 30
        case .threeMonths: return 90
        case .custom: return nil
        }
    }
}

// MARK: - 연락 안 한 기간 필터

enum NoContactFilter: String, CaseIterable, Codable {
    case all = "전체"
    case oneWeek = "1주 이상"
    case twoWeeks = "2주 이상"
    case threeWeeks = "3주 이상"
    case oneMonth = "1달 이상"
    case twoMonths = "2달 이상"
    
    var days: Int? {
        switch self {
        case .all: return nil
        case .oneWeek: return 7
        case .twoWeeks: return 14
        case .threeWeeks: return 21
        case .oneMonth: return 30
        case .twoMonths: return 60
        }
    }
    
    var icon: String {
        switch self {
        case .all: return "person.3"
        case .oneWeek: return "clock"
        case .twoWeeks: return "clock.badge.exclamationmark"
        case .threeWeeks: return "exclamationmark.triangle"
        case .oneMonth: return "exclamationmark.triangle.fill"
        case .twoMonths: return "xmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return .primary
        case .oneWeek: return .green
        case .twoWeeks: return .yellow
        case .threeWeeks: return .orange
        case .oneMonth: return .red
        case .twoMonths: return .purple
        }
    }
}

// MARK: - Filter Options

struct FilterOptions: Codable, Equatable {
    // 기존 필터
    var showNeglectedOnly: Bool = false
    var showWithIncompleteActionsOnly: Bool = false
    var showWithCriticalActionsOnly: Bool = false
    var lastContactDays: Int? = nil
    var includeNeverContacted: Bool = true
    var sortOption: SortOption = .name
    var sortAscending: Bool = false
    
    // 태그 필터
    var selectedTagIDs: [UUID] = []
    var tagFilterMode: TagFilterMode = .any
    
    // 🆕 검색 범위
    var searchScope: SearchScope = .all
    
    // 🆕 날짜 범위 필터
    var dateRangeFilter: DateRangeFilter = .all
    var customDateFrom: Date? = nil
    var customDateTo: Date? = nil
    
    // 🆕 상호작용 기간 필터 (최근 상담한 사람)
    var recentInteractionDays: Int? = nil
    
    // 🆕 대화 타입 필터
    var conversationTypeFilter: [String] = []  // ConversationType rawValues
    
    // 🆕 연락 안 한 기간 필터 (N일 이상 연락 안 한 사람만)
    var noContactFilter: NoContactFilter = .all

    var hasActiveFilters: Bool {
        showNeglectedOnly ||
        showWithIncompleteActionsOnly ||
        showWithCriticalActionsOnly ||
        lastContactDays != nil ||
        !selectedTagIDs.isEmpty ||
        dateRangeFilter != .all ||
        recentInteractionDays != nil ||
        !conversationTypeFilter.isEmpty ||
        noContactFilter != .all
    }
    
    /// 활성화된 필터 개수
    var activeFilterCount: Int {
        var count = 0
        if showNeglectedOnly { count += 1 }
        if showWithIncompleteActionsOnly { count += 1 }
        if showWithCriticalActionsOnly { count += 1 }
        if lastContactDays != nil { count += 1 }
        if !selectedTagIDs.isEmpty { count += 1 }
        if dateRangeFilter != .all { count += 1 }
        if recentInteractionDays != nil { count += 1 }
        if !conversationTypeFilter.isEmpty { count += 1 }
        if noContactFilter != .all { count += 1 }
        return count
    }
    
    /// 필터 요약 텍스트
    var filterSummary: String {
        var parts: [String] = []
        
        if showNeglectedOnly { parts.append("소홀함") }
        if showWithIncompleteActionsOnly { parts.append("미완료 액션") }
        if showWithCriticalActionsOnly { parts.append("긴급 액션") }
        if !selectedTagIDs.isEmpty { parts.append("태그 \(selectedTagIDs.count)개") }
        if dateRangeFilter != .all { parts.append(dateRangeFilter.rawValue) }
        if let days = recentInteractionDays { parts.append("최근 \(days)일 상담") }
        if noContactFilter != .all { parts.append("연락 \(noContactFilter.rawValue)") }
        
        return parts.isEmpty ? "필터 없음" : parts.joined(separator: ", ")
    }
    
    /// 태그 필터 초기화
    mutating func clearTagFilter() {
        selectedTagIDs = []
    }
    
    /// 모든 필터 초기화
    mutating func clearAllFilters() {
        showNeglectedOnly = false
        showWithIncompleteActionsOnly = false
        showWithCriticalActionsOnly = false
        lastContactDays = nil
        selectedTagIDs = []
        dateRangeFilter = .all
        customDateFrom = nil
        customDateTo = nil
        recentInteractionDays = nil
        conversationTypeFilter = []
        noContactFilter = .all
    }

    // MARK: - UserDefaults 저장/로드

    private static let userDefaultsKey = "MacFilterOptions"
    private static let presetsKey = "FilterPresets"

    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
            print("✅ 필터 옵션 저장됨")
        }
    }

    static func load() -> FilterOptions {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(FilterOptions.self, from: data) {
            print("✅ 필터 옵션 로드됨")
            return decoded
        }
        print("ℹ️ 저장된 필터 옵션 없음, 기본값 사용")
        return FilterOptions()
    }
}

// MARK: - Tag Filter Mode

enum TagFilterMode: String, Codable, CaseIterable {
    case any = "하나라도"    // OR: 선택된 태그 중 하나라도 가진 사람
    case all = "모두"       // AND: 선택된 모든 태그를 가진 사람
    
    var description: String {
        switch self {
        case .any: return "선택한 태그 중 하나라도 포함"
        case .all: return "선택한 태그를 모두 포함"
        }
    }
}

// MARK: - Filter Preset

struct FilterPreset: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var icon: String
    var filterOptions: FilterOptions
    var createdDate: Date = Date()
    
    static let defaultPresets: [FilterPreset] = [
        FilterPreset(
            name: "2주 이상 연락 안함",
            icon: "clock.badge.exclamationmark",
            filterOptions: {
                var options = FilterOptions()
                options.noContactFilter = .twoWeeks
                return options
            }()
        ),
        FilterPreset(
            name: "3주 이상 연락 안함",
            icon: "exclamationmark.triangle",
            filterOptions: {
                var options = FilterOptions()
                options.noContactFilter = .threeWeeks
                return options
            }()
        ),
        FilterPreset(
            name: "1달 이상 연락 안함",
            icon: "exclamationmark.triangle.fill",
            filterOptions: {
                var options = FilterOptions()
                options.noContactFilter = .oneMonth
                return options
            }()
        ),
        FilterPreset(
            name: "긴급 액션",
            icon: "bolt.fill",
            filterOptions: {
                var options = FilterOptions()
                options.showWithCriticalActionsOnly = true
                return options
            }()
        ),
        FilterPreset(
            name: "미완료 액션",
            icon: "checklist",
            filterOptions: {
                var options = FilterOptions()
                options.showWithIncompleteActionsOnly = true
                return options
            }()
        )
    ]
}

// MARK: - Filter Presets Manager

class FilterPresetsManager: ObservableObject {
    @Published var presets: [FilterPreset] = []
    
    private static let presetsKey = "FilterPresets"
    
    init() {
        loadPresets()
    }
    
    func loadPresets() {
        if let data = UserDefaults.standard.data(forKey: Self.presetsKey),
           let decoded = try? JSONDecoder().decode([FilterPreset].self, from: data) {
            presets = decoded
        } else {
            // 기본 프리셋 로드
            presets = FilterPreset.defaultPresets
            savePresets()
        }
    }
    
    func savePresets() {
        if let encoded = try? JSONEncoder().encode(presets) {
            UserDefaults.standard.set(encoded, forKey: Self.presetsKey)
        }
    }
    
    func addPreset(_ preset: FilterPreset) {
        presets.append(preset)
        savePresets()
    }
    
    func removePreset(_ preset: FilterPreset) {
        presets.removeAll { $0.id == preset.id }
        savePresets()
    }
    
    func updatePreset(_ preset: FilterPreset) {
        if let index = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[index] = preset
            savePresets()
        }
    }
}
