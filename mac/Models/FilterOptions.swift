//
//  FilterOptions.swift
//  mac
//
//  필터 옵션 모델
//

import SwiftUI

struct FilterOptions {
    var selectedStates: Set<RelationshipState> = []
    var showNeglectedOnly: Bool = false
    var showWithIncompleteActionsOnly: Bool = false
    var showWithCriticalActionsOnly: Bool = false
    var lastContactDays: Int? = nil
    var includeNeverContacted: Bool = true

    var hasActiveFilters: Bool {
        !selectedStates.isEmpty ||
        showNeglectedOnly ||
        showWithIncompleteActionsOnly ||
        showWithCriticalActionsOnly ||
        lastContactDays != nil
    }
}
