//
//  FilterOptions.swift
//  RapportMap
//
//  Created by hyunho lee on 11/7/25.
//

import SwiftUI

enum SortOption: String, CaseIterable {
    case name = "이름순"
    case lastContact = "최근 접촉순"
    case criticalActions = "긴급 액션순"
    case incompleteActions = "미완료 액션순"
}

struct FilterOptions {
    var showNeglectedOnly: Bool = false
    var showWithIncompleteActionsOnly: Bool = false
    var showWithCriticalActionsOnly: Bool = false
    var lastContactDays: Int? = nil
    var includeNeverContacted: Bool = true
    var sortOption: SortOption = .name
    var sortAscending: Bool = true

    var hasActiveFilters: Bool {
        showNeglectedOnly ||
        showWithIncompleteActionsOnly ||
        showWithCriticalActionsOnly ||
        lastContactDays != nil
    }
}
