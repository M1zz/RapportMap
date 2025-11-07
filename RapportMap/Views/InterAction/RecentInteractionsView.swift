//
//  RecentInteractionsView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// MARK: - RecentInteractionsView
struct RecentInteractionsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @State private var showingEditSheet = false
    @State private var showingHistory = false
    @State private var interactionToEdit: InteractionType?
    
    // 기본 상호작용 타입들 (호환성을 위해)
    private let basicTypes: [InteractionType] = [.mentoring, .meal, .contact]
    
    // 최근 상호작용들을 날짜순으로 정렬 (새로운 InteractionRecord 기반)
    private var sortedInteractions: [InteractionRecord] {
        return person.getAllInteractionRecordsSorted().prefix(6).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 가로 스크롤 카드들 (최근 6개만)
            if !sortedInteractions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(sortedInteractions, id: \.id) { record in
                            
                            InteractionRecordCard(
                                record: record,
                                onTap: {
                                    showingEditSheet = true
                                    // 편집을 위해 record를 설정해야 함
                                    #warning("카드 눌렀을 때 데이터 나오게 해줘")
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
                .scrollTargetBehavior(.viewAligned)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("아직 상호작용 기록이 없어요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // 빠른 액션 버튼들
            VStack(spacing: 8) {
                Text("빠른 기록")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 12) {
                    ForEach(basicTypes, id: \.self) { type in
                        Button {
                            // "지금" 기록 후 편집 시트 열기
                            person.addInteractionRecord(type: type, date: Date())
                            person.updateRelationshipState()
                            try? context.save()
                            
                            // 햅틱 피드백
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                            
                            // 편집 시트 열기
                            interactionToEdit = type
                            showingEditSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                    .font(.body)
                                Text("지금")
                                    .font(.body)
                            }
                            .foregroundStyle(.blue)
                            .padding(8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Button {
                        showingHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.body)
                            Text("전체 기록 보기")
                                .font(.body)
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingEditSheet) {
            if let interactionType = interactionToEdit,
               let latestRecord = person.getInteractionRecords(ofType: interactionType).first {
                EditInteractionRecordSheet(record: latestRecord)
            }
        }
        .sheet(isPresented: $showingHistory) {
            InteractionHistoryView(person: person)
        }
    }
}

// MARK: - InteractionRecordCard
struct InteractionRecordCard: View {
    let record: InteractionRecord
    let onTap: () -> Void
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: record.date, relativeTo: .now)
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                // 이모지와 타이틀
                VStack(spacing: 4) {
                    Text(record.type.emoji)
                        .font(.largeTitle)
                    
                    Text(record.type.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundStyle(record.type.color)
                }
                
                // 상대적 시간
                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(record.isRecent ? .green : .secondary)
                    .fontWeight(record.isRecent ? .semibold : .regular)
                
                // 정확한 날짜
                Text(record.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                // 내용 표시 (있는 경우)
                if let notes = record.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .padding(.horizontal, 4)
                } else if let location = record.location, !location.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(location)
                            .font(.caption2)
                    }
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
            }
            .padding()
            .frame(width: 120, height: (record.notes?.isEmpty == false || record.location?.isEmpty == false) ? 160 : 140)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(record.isRecent ? record.type.color.opacity(0.1) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(record.isRecent ? record.type.color.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - InteractionHistoryView
struct InteractionHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person
    
    // 필터링 옵션
    enum FilterOption: String, CaseIterable {
        case all = "전체"
        case mentoring = "멘토링"
        case meal = "식사"
        case contact = "연락"
        
        var interactionType: InteractionType? {
            switch self {
            case .all: return nil
            case .mentoring: return .mentoring
            case .meal: return .meal
            case .contact: return .contact
            }
        }
        
        var systemImage: String {
            switch self {
            case .all: return "list.bullet"
            case .mentoring: return "person.badge.clock"
            case .meal: return "fork.knife"
            case .contact: return "bubble.left"
            }
        }
    }
    
    @State private var selectedFilter: FilterOption = .all
    
    // 필터링된 상호작용 기록들
    private var filteredInteractionRecords: [InteractionRecord] {
        let allRecords = person.getAllInteractionRecordsSorted()
        
        guard let filterType = selectedFilter.interactionType else {
            return allRecords
        }
        
        return allRecords.filter { record in
            // contact 필터의 경우 contact, call, message 모두 포함
            if filterType == .contact {
                return [.contact, .call, .message].contains(record.type)
            }
            return record.type == filterType
        }
    }
    
    // 타입별로 그룹화된 기록들
    private var groupedRecords: [(InteractionType, [InteractionRecord])] {
        let records = filteredInteractionRecords
        let grouped = Dictionary(grouping: records) { $0.type }
        
        // 순서를 유지하면서 반환
        return InteractionType.allCases.compactMap { type in
            guard let typeRecords = grouped[type], !typeRecords.isEmpty else { return nil }
            return (type, typeRecords)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 세그먼트 컨트롤
                VStack(spacing: 12) {
                    Picker("필터", selection: $selectedFilter) {
                        ForEach(FilterOption.allCases, id: \.self) { option in
                            Text(option.rawValue)
                                .tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // 선택된 필터의 통계 정보
                    HStack(spacing: 20) {
                        VStack(spacing: 4) {
                            Text("\(filteredInteractionRecords.count)")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                            Text("총 기록")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        if selectedFilter != .all {
                            VStack(spacing: 4) {
                                if let mostRecentRecord = filteredInteractionRecords.first {
                                    Text(mostRecentRecord.relativeDate)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.green)
                                    Text("최근 기록")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("없음")
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.secondary)
                                    Text("최근 기록")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 12)
                .background(Color(.systemGroupedBackground))
                
                // 내용 영역
                if filteredInteractionRecords.isEmpty {
                    // 빈 상태 표시
                    VStack(spacing: 20) {
                        Image(systemName: selectedFilter.systemImage)
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("\(selectedFilter.rawValue) 기록이 없어요")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text(selectedFilter == .all
                             ? "멘토링, 식사, 연락 등의 기록을 추가해보세요."
                             : "\(selectedFilter.rawValue) 기록을 추가해보세요.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("기록 추가하러 가기") {
                            dismiss()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                } else {
                    List {
                        if selectedFilter == .all {
                            // 전체 보기: 타입별로 그룹화하여 섹션으로 표시
                            ForEach(groupedRecords, id: \.0) { interactionType, records in
                                Section(header: SectionHeaderView(type: interactionType)) {
                                    ForEach(records, id: \.id) { record in
                                        InteractionRecordRow(record: record)
                                    }
                                }
                            }
                        } else {
                            // 특정 타입 보기: 날짜순으로 단순 나열
                            Section {
                                ForEach(filteredInteractionRecords, id: \.id) { record in
                                    InteractionRecordRow(record: record)
                                }
                            } header: {
                                if let filterType = selectedFilter.interactionType {
                                    SectionHeaderView(type: filterType)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("상호작용 기록")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("완료") {
                    dismiss()
                }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selectedFilter)
    }
}
