//
//  FilterOptions.swift
//  RapportMap
//
//  Created by hyunho lee on 11/7/25.
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
