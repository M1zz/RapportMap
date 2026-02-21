//
//  MacRelationshipGraphTab.swift
//  mac
//
//  macOS용 관계도 - 멘토와 멘티 사이의 이벤트 타임라인
//

import SwiftUI
import SwiftData
import Foundation

struct MacRelationshipGraphTab: View {
    @Environment(\.modelContext) private var context
    @Query private var allPeople: [Person]
    let person: Person
    
    @State private var viewMode: ViewMode = .graph
    @State private var filterEventType: ContactType? = nil
    @State private var selectedRecord: Record?
    @State private var showingAddParticipants = false
    
    enum ViewMode: String, CaseIterable {
        case graph = "시각화"
        case timeline = "타임라인"
    }
    
    /// 이 사람과 관련된 모든 이벤트 (Record)
    private var events: [Record] {
        var allRecords = person.records.filter { $0.contactType != nil }
        
        // 필터 적용
        if let filter = filterEventType {
            allRecords = allRecords.filter { $0.contactType == filter }
        }
        
        return allRecords.sorted { $0.date > $1.date }
    }
    
    /// 이벤트 통계
    private var eventStats: [ContactType: Int] {
        var stats: [ContactType: Int] = [:]
        for record in person.records {
            if let type = record.contactType {
                stats[type, default: 0] += 1
            }
        }
        return stats
    }
    
    /// 함께한 사람들 (참석자로 등록된 사람들)
    private var connectedPeople: [Person] {
        var participantIdSet = Set<UUID>()
        
        for record in person.records {
            for id in record.participantUUIDs {
                participantIdSet.insert(id)
            }
        }
        
        return allPeople
            .filter { participantIdSet.contains($0.id) }
            .sorted { p1, p2 in
                sharedEventCount(with: p1) > sharedEventCount(with: p2)
            }
    }
    
    /// 특정 사람과 공유한 이벤트 수
    private func sharedEventCount(with other: Person) -> Int {
        person.records.filter { $0.hasParticipant(other.id) }.count
    }
    
    /// 특정 사람과 공유한 이벤트 통계
    private func sharedEventStats(with other: Person) -> [ContactType: Int] {
        var stats: [ContactType: Int] = [:]
        for record in person.records {
            if record.hasParticipant(other.id), let type = record.contactType {
                stats[type, default: 0] += 1
            }
        }
        return stats
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 상단 요약 + 모드 선택
            summaryHeader
            
            Divider()
            
            // 필터 바
            filterBar
                .padding(.horizontal)
                .padding(.vertical, 8)
            
            Divider()
            
            // 뷰 모드에 따라 표시
            switch viewMode {
            case .graph:
                if connectedPeople.isEmpty && events.isEmpty {
                    emptyStateView
                } else {
                    graphView
                }
            case .timeline:
                if events.isEmpty {
                    emptyStateView
                } else {
                    eventTimeline
                }
            }
        }
        .sheet(isPresented: $showingAddParticipants) {
            if let record = selectedRecord {
                AddParticipantsSheet(record: record, currentPersonId: person.id)
            }
        }
    }
    
    // MARK: - Summary Header
    
    private var summaryHeader: some View {
        HStack(spacing: 24) {
            // 멘티 정보
            HStack(spacing: 12) {
                Group {
                    if let imageData = person.profileImageData,
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.blue)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(person.name)
                        .font(.headline)
                    
                    if let lastDate = person.mostRecentInteractionDate {
                        Text("마지막 만남: \(lastDate.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // 모드 선택
            Picker("보기", selection: $viewMode) {
                ForEach(ViewMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
            
            Spacer()
            
            // 이벤트 통계 카드들
            HStack(spacing: 12) {
                ForEach(ContactType.allCases, id: \.self) { type in
                    eventStatCard(type: type, count: eventStats[type] ?? 0)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private func eventStatCard(type: ContactType, count: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: type.systemImage)
                .font(.title2)
                .foregroundStyle(type.color)
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.bold)
            
            Text(type.title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(width: 60)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(type.color.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(filterEventType == type ? type.color : Color.clear, lineWidth: 2)
        )
        .onTapGesture {
            withAnimation {
                if filterEventType == type {
                    filterEventType = nil
                } else {
                    filterEventType = type
                }
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack {
            Text("이벤트 기록")
                .font(.headline)
            
            Spacer()
            
            if filterEventType != nil {
                Button {
                    withAnimation { filterEventType = nil }
                } label: {
                    Label("필터 해제", systemImage: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            
            Text("\(events.count)개")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            
            Text("아직 기록된 이벤트가 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text("미팅, 식사, 통화 등을 기록해보세요")
                .font(.caption)
                .foregroundStyle(.tertiary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Graph View (시각화)
    
    private var graphView: some View {
        GeometryReader { geometry in
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                // 연결선 (이벤트 기반)
                ForEach(Array(connectedPeople.enumerated()), id: \.element.id) { index, connected in
                    let position = positionForPerson(at: index, total: connectedPeople.count, in: geometry.size)
                    
                    eventConnectionLine(
                        from: geometry.size.center,
                        to: position,
                        person: connected
                    )
                }
                
                // 이벤트 노드들 (연결선 위에)
                ForEach(Array(connectedPeople.enumerated()), id: \.element.id) { index, connected in
                    let position = positionForPerson(at: index, total: connectedPeople.count, in: geometry.size)
                    let midPoint = CGPoint(
                        x: (geometry.size.center.x + position.x) / 2,
                        y: (geometry.size.center.y + position.y) / 2
                    )
                    
                    eventNodeOnLine(for: connected)
                        .position(midPoint)
                }
                
                // 연결된 사람들
                ForEach(Array(connectedPeople.enumerated()), id: \.element.id) { index, connected in
                    connectedPersonNode(
                        person: connected,
                        position: positionForPerson(at: index, total: connectedPeople.count, in: geometry.size)
                    )
                }
                
                // 중앙 - 현재 멘티
                centralNode(in: geometry.size)
                
                // 범례
                graphLegend
                    .position(x: 100, y: geometry.size.height - 80)
                
                // 연결된 사람 없을 때
                if connectedPeople.isEmpty {
                    VStack(spacing: 8) {
                        Text("함께한 사람이 없습니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text("이벤트에 참석자를 추가해보세요")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2 + 80)
                }
            }
        }
    }
    
    // MARK: - Central Node
    
    private func centralNode(in size: CGSize) -> some View {
        ZStack {
            // 이벤트 위성 원들
            eventSatellites(radius: 100, iconSize: 40)
            
            // 프로필
            VStack(spacing: 8) {
                Group {
                    if let imageData = person.profileImageData,
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.blue)
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.blue, lineWidth: 3)
                )
                .shadow(color: .blue.opacity(0.4), radius: 10)
                
                Text(person.name)
                    .font(.title3)
                    .fontWeight(.semibold)
            }
        }
        .position(size.center)
    }
    
    /// 이벤트 위성 원들 (주변에 원으로 배치)
    private func eventSatellites(radius: CGFloat, iconSize: CGFloat) -> some View {
        let sortedTypes = eventStats.keys.sorted { (eventStats[$0] ?? 0) > (eventStats[$1] ?? 0) }
        let total = sortedTypes.count
        
        return ZStack {
            ForEach(Array(sortedTypes.enumerated()), id: \.element) { index, type in
                let count = eventStats[type] ?? 0
                let angle = (2.0 * Double.pi * Double(index) / Double(max(total, 1))) - Double.pi / 2.0
                let x = CGFloat(radius * Darwin.cos(angle))
                let y = CGFloat(radius * Darwin.sin(angle))
                
                // 이벤트 원
                eventSatellite(type: type, count: count, size: iconSize)
                    .offset(x: x, y: y)
            }
        }
    }
    
    /// 개별 이벤트 위성
    private func eventSatellite(type: ContactType, count: Int, size: CGFloat) -> some View {
        ZStack {
            // 바깥 원 (그림자 효과)
            Circle()
                .fill(type.color.opacity(0.2))
                .frame(width: size + 16, height: size + 16)
            
            // 메인 원
            Circle()
                .fill(type.color)
                .frame(width: size + 8, height: size + 8)
                .shadow(color: type.color.opacity(0.5), radius: 4)
            
            // 아이콘
            Image(systemName: type.systemImage)
                .font(.system(size: size * 0.5, weight: .bold))
                .foregroundStyle(.white)
            
            // 카운트 뱃지
            if count > 0 {
                Text("\(count)")
                    .font(.system(size: size * 0.35, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .offset(x: size * 0.6, y: -size * 0.5)
            }
        }
    }
    
    // MARK: - Connected Person Node
    
    private func connectedPersonNode(person: Person, position: CGPoint) -> some View {
        let stats = sharedEventStats(with: person)
        
        return ZStack {
            // 이벤트 위성들
            connectedPersonEventSatellites(stats: stats, radius: 60, iconSize: 32)
            
            // 프로필
            VStack(spacing: 6) {
                Group {
                    if let imageData = person.profileImageData,
                       let nsImage = NSImage(data: imageData) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.gray.opacity(0.5), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.1), radius: 4)
                
                Text(person.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
            }
        }
        .position(position)
    }
    
    /// 연결된 사람 주변 이벤트 위성들
    private func connectedPersonEventSatellites(stats: [ContactType: Int], radius: CGFloat, iconSize: CGFloat) -> some View {
        let sortedTypes = stats.keys.sorted { (stats[$0] ?? 0) > (stats[$1] ?? 0) }
        let total = sortedTypes.count
        
        return ZStack {
            ForEach(Array(sortedTypes.enumerated()), id: \.element) { index, type in
                let count = stats[type] ?? 0
                let angle = (2.0 * Double.pi * Double(index) / Double(max(total, 1))) - Double.pi / 2.0
                let x = CGFloat(radius * Darwin.cos(angle))
                let y = CGFloat(radius * Darwin.sin(angle))
                
                eventSatellite(type: type, count: count, size: iconSize)
                    .offset(x: x, y: y)
            }
        }
    }
    
    // MARK: - Event Connection Line
    
    private func eventConnectionLine(from start: CGPoint, to end: CGPoint, person: Person) -> some View {
        let sharedCount = sharedEventCount(with: person)
        let lineWidth = min(2 + CGFloat(sharedCount), 8)
        let stats = sharedEventStats(with: person)
        let dominantType = stats.max(by: { $0.value < $1.value })?.key
        
        return Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            LinearGradient(
                colors: [.blue.opacity(0.4), (dominantType?.color ?? .gray).opacity(0.6)],
                startPoint: .leading,
                endPoint: .trailing
            ),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
        )
    }
    
    // MARK: - Event Node on Line
    
    private func eventNodeOnLine(for person: Person) -> some View {
        let stats = sharedEventStats(with: person)
        
        return HStack(spacing: 2) {
            ForEach(stats.keys.sorted(by: { stats[$0]! > stats[$1]! }).prefix(3), id: \.self) { type in
                Image(systemName: type.systemImage)
                    .font(.system(size: 10))
                    .foregroundStyle(type.color)
            }
        }
        .padding(6)
        .background(
            Capsule()
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(radius: 2)
        )
    }
    
    // MARK: - Graph Legend
    
    private var graphLegend: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("이벤트 타입")
                .font(.caption)
                .fontWeight(.semibold)
            
            HStack(spacing: 12) {
                ForEach(ContactType.allCases, id: \.self) { type in
                    HStack(spacing: 4) {
                        Image(systemName: type.systemImage)
                            .font(.caption2)
                            .foregroundStyle(type.color)
                        Text(type.title)
                            .font(.caption2)
                    }
                }
            }
            
            Text("선 굵기 = 함께한 이벤트 수")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.95))
        )
    }
    
    // MARK: - Position Helper
    
    private func positionForPerson(at index: Int, total: Int, in size: CGSize) -> CGPoint {
        let radius = min(size.width, size.height) * 0.40
        let angle = (2.0 * Double.pi * Double(index) / Double(max(total, 1))) - Double.pi / 2.0
        
        return CGPoint(
            x: size.width / 2 + CGFloat(radius * Darwin.cos(angle)),
            y: size.height / 2 + CGFloat(radius * Darwin.sin(angle))
        )
    }
    
    // MARK: - Event Timeline
    
    private var eventTimeline: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(events) { record in
                    eventRow(record: record)
                    
                    if record.id != events.last?.id {
                        timelineConnector
                    }
                }
            }
            .padding()
        }
    }
    
    private func eventRow(record: Record) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // 타임라인 노드
            VStack(spacing: 4) {
                Circle()
                    .fill(record.contactType?.color ?? .gray)
                    .frame(width: 12, height: 12)
                
                if record.participantCount > 0 {
                    Text("+\(record.participantCount)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Circle().fill(Color.blue))
                }
            }
            .frame(width: 30)
            
            // 이벤트 카드
            VStack(alignment: .leading, spacing: 8) {
                // 헤더
                HStack {
                    // 이벤트 타입
                    Label {
                        Text(record.contactType?.title ?? "메모")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    } icon: {
                        Image(systemName: record.contactType?.systemImage ?? "note.text")
                            .foregroundStyle(record.contactType?.color ?? .gray)
                    }
                    
                    Spacer()
                    
                    // 날짜
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 내용
                Text(record.content)
                    .font(.body)
                    .lineLimit(3)
                
                // 부가 정보
                HStack(spacing: 12) {
                    if let duration = record.formattedDuration {
                        Label(duration, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let location = record.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                }
                
                // 참석자
                if record.participantCount > 0 {
                    participantsView(for: record)
                }
                
                // 참석자 추가 버튼
                Button {
                    selectedRecord = record
                    showingAddParticipants = true
                } label: {
                    Label("참석자 관리", systemImage: "person.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(record.contactType?.color.opacity(0.3) ?? Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .padding(.vertical, 4)
    }
    
    private var timelineConnector: some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 2, height: 20)
                .padding(.leading, 14)
            Spacer()
        }
    }
    
    // MARK: - Participants View
    
    private func participantsView(for record: Record) -> some View {
        let participantUUIDs = record.participantUUIDs
        let participants = allPeople.filter { participantUUIDs.contains($0.id) }
        
        return VStack(alignment: .leading, spacing: 4) {
            Text("함께한 사람")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(participants) { participant in
                    HStack(spacing: 4) {
                        Group {
                            if let imageData = participant.profileImageData,
                               let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.gray)
                            }
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                        
                        Text(participant.name)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.1))
                    )
                }
            }
        }
    }
}

// MARK: - Add Participants Sheet

struct AddParticipantsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var allPeople: [Person]
    
    let record: Record
    let currentPersonId: UUID
    
    @State private var searchText = ""
    
    private var filteredPeople: [Person] {
        let others = allPeople.filter { $0.id != currentPersonId }
        
        if searchText.isEmpty {
            return others
        }
        return others.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("참석자 관리")
                    .font(.headline)
                Spacer()
                Button("완료") {
                    dismiss()
                }
            }
            .padding()
            
            Divider()
            
            // 검색
            TextField("이름 검색", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding()
            
            // 사람 목록
            List {
                ForEach(filteredPeople) { person in
                    HStack {
                        Group {
                            if let imageData = person.profileImageData,
                               let nsImage = NSImage(data: imageData) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .scaledToFill()
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .resizable()
                                    .foregroundStyle(.gray)
                            }
                        }
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                        
                        Text(person.name)
                        
                        Spacer()
                        
                        if record.hasParticipant(person.id) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.blue)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        record.toggleParticipant(person.id)
                        try? context.save()
                    }
                }
            }
        }
        .frame(width: 350, height: 450)
    }
}

// MARK: - Extensions

extension CGSize {
    var center: CGPoint {
        CGPoint(x: width / 2, y: height / 2)
    }
}

// Color init(hex:) is defined in macOS/Views/MacPersonDashboardTab.swift

#Preview {
    MacRelationshipGraphTab(person: Person(name: "홍길동"))
        .modelContainer(for: [Person.self, PersonTag.self])
        .frame(width: 800, height: 600)
}
