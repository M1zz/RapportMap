//
//  MacPeopleFilterView.swift
//  mac
//
//  macOS용 필터 화면
//

import SwiftUI

struct MacPeopleFilterView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var filterOptions: FilterOptions
    let peopleCount: Int
    let filteredCount: Int

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("필터")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("완료") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 메인 컨텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 결과 카운트
                    GroupBox {
                        Text("전체 \(peopleCount)명 중 \(filteredCount)명 표시")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    // 정렬 옵션
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
                        }
                        .padding()
                    }

                    // 특별 상태 필터
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

                    // 마지막 접촉 필터
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

                    // 초기화 버튼
                    Button {
                        filterOptions = FilterOptions()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("필터 초기화")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!filterOptions.hasActiveFilters)
                    .padding(.top, 8)
                }
                .padding()
            }
        }
        .frame(width: 400, height: 600)
    }
}

#Preview {
    MacPeopleFilterView(
        filterOptions: .constant(FilterOptions()),
        peopleCount: 10,
        filteredCount: 5
    )
}
