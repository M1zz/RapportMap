//
//  FilterOptions.swift
//  mac
//
//  필터 옵션 모델
//

import SwiftUI

enum SortOption: String, CaseIterable, Codable {
    case name = "이름순"
    case lastContact = "최근 접촉순"
    case incompleteActions = "미완료 액션순"

    var systemImage: String {
        switch self {
        case .name: return "textformat"
        case .lastContact: return "clock"
        case .incompleteActions: return "checklist"
        }
    }
}

struct FilterOptions: Codable, Equatable {
    var showNeglectedOnly: Bool = false
    var showWithIncompleteActionsOnly: Bool = false
    var showWithCriticalActionsOnly: Bool = false
    var lastContactDays: Int? = nil
    var includeNeverContacted: Bool = true
    var sortOption: SortOption = .name

    var hasActiveFilters: Bool {
        showNeglectedOnly ||
        showWithIncompleteActionsOnly ||
        showWithCriticalActionsOnly ||
        lastContactDays != nil
    }

    // MARK: - UserDefaults 저장/로드

    private static let userDefaultsKey = "MacFilterOptions"

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
