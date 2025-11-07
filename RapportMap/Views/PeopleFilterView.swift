//
//  PeopleFilterView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/7/25.
//

import SwiftUI

struct PeopleFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterOptions: FilterOptions
    let peopleCount: Int
    let filteredCount: Int
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("전체 \(peopleCount)명 중 \(filteredCount)명 표시")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Section("관계 상태") {
                    ForEach(RelationshipState.allCases, id: \.self) { state in
                        Toggle(isOn: Binding(
                            get: { filterOptions.selectedStates.contains(state) },
                            set: { isOn in
                                if isOn {
                                    filterOptions.selectedStates.insert(state)
                                } else {
                                    filterOptions.selectedStates.remove(state)
                                }
                            }
                        )) {
                            HStack {
                                Circle()
                                    .fill(state.color)
                                    .frame(width: 12, height: 12)
                                Text(state.localizedName)
                            }
                        }
                    }
                }
                
                Section("특별 상태") {
                    Toggle("소홀한 관계만", isOn: $filterOptions.showNeglectedOnly)
                    Toggle("미완료 액션이 있는 사람만", isOn: $filterOptions.showWithIncompleteActionsOnly)
                    Toggle("긴급 액션이 있는 사람만", isOn: $filterOptions.showWithCriticalActionsOnly)
                }
                
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
                
                Section {
                    Button("필터 초기화") {
                        filterOptions = FilterOptions()
                    }
                    .disabled(!filterOptions.hasActiveFilters)
                }
            }
            .navigationTitle("필터")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
    }
}
