//
//  FilterOptions.swift
//  RapportMap
//
//  Created by hyunho lee on 11/7/25.
//

import SwiftUI

enum SortOption: String, CaseIterable {
    case name = "이름순"
    case relationshipHealth = "관계 건강도순"
    case lastContact = "최근 접촉순"
    case criticalActions = "긴급 액션순"
    case incompleteActions = "미완료 액션순"
}

struct FilterOptions {
    var selectedStates: Set<RelationshipState> = []
    var showNeglectedOnly: Bool = false
    var showWithIncompleteActionsOnly: Bool = false
    var showWithCriticalActionsOnly: Bool = false
    var lastContactDays: Int? = nil
    var includeNeverContacted: Bool = true
    var sortOption: SortOption = .name
    var sortAscending: Bool = true

    var hasActiveFilters: Bool {
        !selectedStates.isEmpty ||
        showNeglectedOnly ||
        showWithIncompleteActionsOnly ||
        showWithCriticalActionsOnly ||
        lastContactDays != nil
    }
}
