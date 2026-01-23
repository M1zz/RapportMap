//
//  RecentInteractionsView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// MARK: - Sheet Type
enum RecentInteractionsSheet: Identifiable {
    case interactionHistory
    case memoArchive
    case editInteraction
    case createInteraction
    case recordDetail(InteractionRecord)

    var id: String {
        switch self {
        case .interactionHistory: return "interactionHistory"
        case .memoArchive: return "memoArchive"
        case .editInteraction: return "editInteraction"
        case .createInteraction: return "createInteraction"
        case .recordDetail(let record): return "recordDetail-\(record.id)"
        }
    }
}

// MARK: - RecentInteractionsView
struct RecentInteractionsView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @State private var activeSheet: RecentInteractionsSheet?
    @State private var interactionToEdit: InteractionType?
    @State private var recordToEdit: InteractionRecord? // 실제 편집할 기록을 저장
    @State private var newInteractionType: InteractionType? // 새로 생성할 상호작용 타입
    
    // 기본 상호작용 타입들 (호환성을 위해)
    private let basicTypes: [InteractionType] = [.mentoring, .meal, .contact]
    
    // 최근 상호작용들을 날짜순으로 정렬 (새로운 InteractionRecord 기반)
    private var sortedInteractions: [InteractionRecord] {
        return person.getAllInteractionRecordsSorted().prefix(6).map { $0 }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            quickMemoSection
            actionButtonsSection
            recentInteractionsSection
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .interactionHistory:
                InteractionHistoryView(person: person)
                    .onAppear {
                        print("✅ InteractionHistoryView 표시됨")
                    }

            case .memoArchive:
                QuickMemoArchiveView(person: person)
                    .onAppear {
                        print("✅ QuickMemoArchiveView 표시됨")
                    }

            case .editInteraction:
                if let recordToEdit = recordToEdit, let person = recordToEdit.person {
                    EditInteractionRecordSheet(record: recordToEdit, person: person)
                } else {
                    // 만약 recordToEdit이 없다면 에러 화면 표시
                    NavigationStack {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundStyle(.orange)

                            Text("편집할 기록을 찾을 수 없어요")
                                .font(.headline)

                            Text("기록이 삭제되었거나 문제가 발생했습니다.\n다시 시도해주세요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("닫기") {
                                activeSheet = nil
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .navigationTitle("오류")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                }

            case .createInteraction:
                if let newInteractionType = newInteractionType {
                    CreateInteractionRecordSheet(
                        person: person,
                        interactionType: newInteractionType,
                        onSave: { date, notes, location, duration, relatedMeetingRecord, photosData in
                            // 저장 버튼을 눌렀을 때만 실제 데이터 생성
                            let newRecord = person.addInteractionRecord(
                                type: newInteractionType,
                                date: date,
                                notes: notes,
                                duration: duration,
                                location: location,
                                relatedMeetingRecord: relatedMeetingRecord
                            )

                            // 사진들 추가
                            photosData.forEach { photoData in
                                newRecord.addPhoto(photoData)
                            }

                            do {
                                try context.save()
                                print("✅ 새 상호작용 기록 생성: \(newRecord.id)")

                                // 햅틱 피드백
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            } catch {
                                print("❌ 상호작용 기록 생성 실패: \(error)")
                            }
                        }
                    )
                    .onAppear {
                        print("✅ CreateInteractionRecordSheet 표시됨 - 타입: \(newInteractionType.title)")
                    }
                } else {
                    // newInteractionType이 nil일 때 안내 화면
                    NavigationStack {
                        VStack(spacing: 20) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 60))
                                .foregroundStyle(.orange)

                            Text("상호작용 타입을 선택해주세요")
                                .font(.headline)

                            Text("기록하려는 상호작용 타입이 설정되지 않았습니다.\n다시 시도해주세요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("닫기") {
                                activeSheet = nil
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding()
                        .navigationTitle("오류")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .onAppear {
                        print("⚠️ newInteractionType이 nil - 안내 화면 표시됨")
                    }
                }

            case .recordDetail(let record):
                InteractionRecordDetailView(record: record, person: person) {
                    // 편집 버튼을 눌렀을 때
                    // 1. 먼저 편집할 기록 설정
                    recordToEdit = record

                    // 2. 상세 sheet 닫기
                    activeSheet = nil

                    // 3. 애니메이션 완료 후 편집 sheet 열기
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        activeSheet = .editInteraction
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var recentInteractionsSection: some View {
        if !sortedInteractions.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(sortedInteractions, id: \.id) { record in
                        InteractionRecordCard(
                            record: record,
                            onTap: { handleCardTap(for: record) }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .scrollTargetBehavior(.viewAligned)
        } else {
            emptyStateView
        }
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
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
    
    @ViewBuilder
    private var actionButtonsSection: some View {
        HStack(spacing: 12) {
            // 기록하기 메뉴 버튼
            Menu {
                ForEach(InteractionType.allCases, id: \.self) { type in
                    Button {
                        print("📝 상호작용 타입 선택: \(type.title)")
                        newInteractionType = type
                        activeSheet = .createInteraction
                    } label: {
                        Label(type.title, systemImage: type.systemImage)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                    Text("기록하기")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }

            // 전체 기록 보기 버튼
            Button {
                print("🔵 전체 기록 버튼 클릭 - InteractionHistory 열기")
                guard activeSheet == nil else {
                    print("⚠️ 이미 sheet가 열려있음, 무시")
                    return
                }
                activeSheet = .interactionHistory
            } label: {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                    Text("전체 기록")
                        .font(.headline)
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var quickMemoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("빠른 메모")
                        .font(.headline)
                    Text("대화 내용을 자유롭게 메모하세요. 저장하면 아카이브에 보관됩니다.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                // 아카이브 보기 버튼
                if !person.archivedMemos.isEmpty {
                    Button {
                        print("📦 아카이브 버튼 클릭 - MemoArchive 열기")
                        guard activeSheet == nil else {
                            print("⚠️ 이미 sheet가 열려있음, 무시")
                            return
                        }
                        activeSheet = .memoArchive
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox")
                                .font(.caption)
                            Text("\(person.archivedMemos.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            TextEditor(text: $person.quickMemo)
                .frame(minHeight: 120)
                .padding(8)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .topLeading) {
                    if person.quickMemo.isEmpty {
                        Text("예: 오늘 만나서 프로젝트 이야기를 나눴어요. 다음주에 결과물 보여주기로 약속했고, 최근에 ○○○에 관심이 생겼다고 하네요...")
                            .font(.body)
                            .foregroundStyle(.secondary.opacity(0.5))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }

            // 저장 버튼
            Button {
                saveQuickMemo()
            } label: {
                HStack {
                    Image(systemName: "archivebox.fill")
                        .font(.body)
                    Text("저장하고 초기화")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color.gray : Color.green)
                .cornerRadius(10)
            }
            .disabled(person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    @ViewBuilder
    private var editInteractionSheet: some View {
        if let recordToEdit = recordToEdit, let person = recordToEdit.person {
            EditInteractionRecordSheet(record: recordToEdit, person: person)
        }
    }

    
    // MARK: - Actions

    private func handleCardTap(for record: InteractionRecord) {
        activeSheet = .recordDetail(record)
    }

    private func handleQuickAction(for type: InteractionType) {
        // 임시로 타입만 저장하고 생성 시트 열기
        newInteractionType = type
        activeSheet = .createInteraction
    }

    private func saveQuickMemo() {
        let trimmedMemo = person.quickMemo.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedMemo.isEmpty else { return }

        // 새 아카이브 메모 생성
        let archive = QuickMemoArchive(content: trimmedMemo, createdDate: Date())
        archive.person = person

        // context에 삽입
        context.insert(archive)

        // person의 archivedMemos에 추가 (relationship이 자동으로 처리하지만 명시적으로)
        person.archivedMemos.append(archive)

        // 저장
        do {
            try context.save()
            print("✅ 빠른 메모 저장 완료: \(trimmedMemo.prefix(50))...")

            // quickMemo 초기화
            person.quickMemo = ""

            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ 빠른 메모 저장 실패: \(error)")
        }
    }
}

// MARK: - InteractionRecordDetailView
struct InteractionRecordDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: InteractionRecord
    let person: Person
    let onEdit: () -> Void
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: record.date, relativeTo: Date())
    }
    
    // 기록에 내용이 있는지 확인
    private var hasDetailContent: Bool {
        return record.relatedMeetingRecord != nil ||
               (record.location != nil && !record.location!.isEmpty) ||
               (record.notes != nil && !record.notes!.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 헤더 섹션
                    VStack(spacing: 16) {
                        // 이모지와 타입
                        VStack(spacing: 8) {
                            Text(record.type.emoji)
                                .font(.system(size: 60))
                            
                            Text(record.type.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(record.type.color)
                        }
                        
                        // 날짜와 시간 정보
                        VStack(spacing: 4) {
                            Text(record.date.formatted(date: .complete, time: .omitted))
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            HStack(spacing: 4) {
                                Text(record.date.formatted(date: .omitted, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                if record.isRecent {
                                    Text("• 최근")
                                        .font(.subheadline)
                                        .foregroundStyle(.green)
                                        .fontWeight(.semibold)
                                }
                            }
                            
                            Text(relativeDate)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(record.type.color.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(record.type.color.opacity(0.3), lineWidth: 1)
                            )
                    )
                    
                    // 내용이 없을 때 안내 메시지
                    if !hasDetailContent {
                        VStack(spacing: 20) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 50))
                                .foregroundStyle(.secondary)
                            
                            Text("상세 정보가 없어요")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            Text("이 \(record.type.title) 기록에 대한 추가 정보를 입력해보세요.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                onEdit()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "pencil")
                                    Text("상세 정보 추가하기")
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(record.type.color)
                                .cornerRadius(12)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "lightbulb.fill")
                                        .foregroundStyle(.yellow)
                                    Text("추가할 수 있는 정보")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    SuggestionRow(icon: "location", text: "만난 장소")
                                    SuggestionRow(icon: "note.text", text: "대화 내용 메모")
                                    SuggestionRow(icon: "waveform", text: "음성 녹음 연결")
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .padding()
                    } else {
                        // 상세 정보 섹션들
                        VStack(spacing: 16) {
                            // 연결된 녹음 파일 정보 (모든 상호작용 타입)
                            if let meetingRecord = record.relatedMeetingRecord {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "waveform")
                                            .foregroundStyle(.blue)
                                        Text("연결된 녹음 파일")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                        Spacer()
                                    }
                                    
                                    VStack(spacing: 8) {
                                        HStack {
                                            HStack(spacing: 4) {
                                                Text(meetingRecord.meetingType.emoji)
                                                    .font(.headline)
                                                Text(meetingRecord.meetingType.rawValue)
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
                                            }
                                            Spacer()
                                            Text(meetingRecord.date.formatted(date: .abbreviated, time: .shortened))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        
                                        HStack {
                                            Text("녹음 시간:")
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Text(meetingRecord.formattedDuration)
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                        }
                                        
                                        if !meetingRecord.summary.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                HStack {
                                                    Text("요약:")
                                                        .font(.subheadline)
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                }
                                                Text(meetingRecord.summary)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.primary)
                                            }
                                        }
                                        
                                        if meetingRecord.hasAudio {
                                            HStack {
                                                Image(systemName: "speaker.wave.2")
                                                    .font(.caption)
                                                    .foregroundStyle(.green)
                                                Text("오디오 파일 있음")
                                                    .font(.caption)
                                                    .foregroundStyle(.green)
                                                Spacer()
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .background(Color.blue.opacity(0.05))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                                )
                            }
                            
                            // 위치 정보
                            if let location = record.location, !location.isEmpty {
                                DetailInfoCard(
                                    title: "위치",
                                    icon: "location",
                                    content: location,
                                    color: .orange
                                )
                            }
                            
                            // 메모
                            if let notes = record.notes, !notes.isEmpty {
                                DetailInfoCard(
                                    title: "메모",
                                    icon: "note.text",
                                    content: notes,
                                    color: .blue
                                )
                            }
                            
                            // 연락 상세 (연락 타입인 경우)
                            if [.contact, .call, .message].contains(record.type) {
                                DetailInfoCard(
                                    title: "연락 방식",
                                    icon: record.type.systemImage,
                                    content: record.type.title,
                                    color: record.type.color
                                )
                            }
                        }
                        
                        // 통계 정보 (해당 타입의 총 횟수)
                        let sameTypeRecords = person.getInteractionRecords(ofType: record.type)
                        if sameTypeRecords.count > 1 {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("통계")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                HStack(spacing: 20) {
                                    StatCard(
                                        title: "총 \(record.type.title) 횟수",
                                        value: "\(sameTypeRecords.count)회",
                                        color: record.type.color
                                    )
                                    
                                    if let firstRecord = sameTypeRecords.last {
                                        StatCard(
                                            title: "첫 번째",
                                            value: firstRecord.date.formatted(date: .abbreviated, time: .omitted),
                                            color: .secondary
                                        )
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("상호작용 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("편집") {
                        onEdit()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - SuggestionRow
struct SuggestionRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 20)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
        }
    }
}

// MARK: - DetailInfoCard
struct DetailInfoCard: View {
    let title: String
    let icon: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            
            Text(content)
                .font(.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - StatCard
struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
                
                // 내용 표시 (연결된 녹음, 메모, 위치 순서로)
                if let meetingRecord = record.relatedMeetingRecord {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                        Text("녹음 연결됨")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(4)
                } else if let notes = record.notes, !notes.isEmpty {
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
    
    private func relativeDate(for record: InteractionRecord) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: record.date, relativeTo: Date())
    }
    
    // 필터링 옵션
    enum FilterOption: String, CaseIterable {
        case all = "전체"
        case mentoring = "멘토링"
        case meal = "식사"
        case contact = "스몰토크"
        
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
                    Picker("", selection: $selectedFilter) {
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
                                    Text(relativeDate(for: mostRecentRecord))
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
                                Section(header: ListHeaderView(type: interactionType)) {
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
                                    ListHeaderView(type: filterType)
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

// MARK: - SectionHeaderView
struct ListHeaderView: View {
    let type: InteractionType
    
    var body: some View {
        HStack(spacing: 8) {
            Text(type.emoji)
                .font(.title3)
            Text(type.title)
                .font(.headline)
                .fontWeight(.semibold)
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - CreateInteractionRecordSheet
struct CreateInteractionRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let interactionType: InteractionType
    let onSave: (Date, String?, String?, TimeInterval?, MeetingRecord?, [Data]) -> Void // 사진 데이터 배열 추가
    
    @State private var tempDate: Date = Date()
    @State private var tempNotes: String = ""
    @State private var tempLocation: String = ""
    @State private var tempDuration: TimeInterval? = nil
    @State private var hasDuration: Bool = false
    @State private var showingRecordPicker = false
    @State private var selectedMeetingRecord: MeetingRecord? = nil
    @State private var showingImagePicker = false
    @State private var showingImageOptions = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var photosData: [Data] = [] // 추가된 사진들
    
    // 상호작용 타입에 맞는 미팅 기록들 (날짜 역순)
    private var availableMeetingRecords: [MeetingRecord] {
        let matchingMeetingType: MeetingType
        switch interactionType {
        case .mentoring:
            matchingMeetingType = .mentoring
        case .meal:
            matchingMeetingType = .meal
        case .contact, .call, .message, .quickNote:
            // 스몰토크는 일반 대화나 커피 미팅과 연결
            return person.meetingRecords
                .filter { [.general, .coffee].contains($0.meetingType) }
                .sorted { $0.date > $1.date }
        case .meeting:
            // 만남은 모든 타입과 연결 가능
            return person.meetingRecords.sorted { $0.date > $1.date }
        }

        return person.meetingRecords
            .filter { $0.meetingType == matchingMeetingType }
            .sorted { $0.date > $1.date }
    }

    // 지속 시간 표시를 위한 computed property
    private var formattedDurationPreview: String {
        guard let duration = tempDuration, duration > 0 else { return "" }
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        if hours > 0 {
            return "\(hours)시간 \(remainingMinutes)분"
        } else {
            return "\(minutes)분"
        }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                basicInfoSection
                dateTimeSection
                locationSection
                durationSection
                notesSection
                photosSection
                recordingSection
                previewSection
            }
            .navigationTitle("새 \(interactionType.title) 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveRecord()
                    }
                }
            }
            .sheet(isPresented: $showingRecordPicker) {
                RecordPickerView(
                    interactionType: interactionType,
                    availableRecords: availableMeetingRecords,
                    onRecordSelected: { meetingRecord in
                        selectedMeetingRecord = meetingRecord

                        // 녹음 파일의 정보를 활용하여 상호작용 정보 자동 설정
                        if let meetingRecord = meetingRecord {
                            tempDate = meetingRecord.date
                            tempDuration = meetingRecord.duration
                            hasDuration = true

                            // 녹음의 요약이나 전사 내용을 메모로 추가 (기존 메모가 비어있을 때만)
                            if tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                if !meetingRecord.summary.isEmpty {
                                    tempNotes = "녹음 요약: \(meetingRecord.summary)"
                                } else if !meetingRecord.transcribedText.isEmpty && meetingRecord.transcribedText.count <= 100 {
                                    tempNotes = "녹음 내용: \(meetingRecord.transcribedText)"
                                }
                            }
                        }

                        showingRecordPicker = false
                    }
                )
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .sheet(isPresented: $showingCamera) {
                CameraPicker(image: $selectedImage)
            }
            .confirmationDialog("사진 선택", isPresented: $showingImageOptions) {
                Button("카메라로 촬영") {
                    showingCamera = true
                }
                Button("앨범에서 선택") {
                    showingImagePicker = true
                }
                Button("취소", role: .cancel) { }
            }
            .onChange(of: selectedImage) { oldValue, newValue in
                if let image = newValue {
                    if let imageData = image.jpegData(compressionQuality: 0.8) {
                        photosData.append(imageData)
                    }
                    selectedImage = nil // 다음 추가를 위해 초기화
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var basicInfoSection: some View {
        Section("기본 정보") {
            HStack {
                Text(interactionType.emoji)
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(interactionType.title)
                        .font(.headline)
                    Text("새로운 \(interactionType.title) 기록을 추가하세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var dateTimeSection: some View {
        Section("날짜 및 시간") {
            DatePicker("날짜와 시간", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)
        }
    }

    @ViewBuilder
    private var locationSection: some View {
        Section("장소") {
            TextField("어디서 만났나요?", text: $tempLocation)
        }
    }

    @ViewBuilder
    private var durationSection: some View {
        Section("지속 시간") {
            Toggle("지속 시간 기록", isOn: $hasDuration)

            if hasDuration {
                durationInputFields
            }
        }
    }

    @ViewBuilder
    private var durationInputFields: some View {
        HStack {
            Text("시간:")
            Spacer()
            HStack {
                TextField("시간", value: hoursBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 60)

                Text("시간")

                TextField("분", value: minutesBinding, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .frame(width: 60)

                Text("분")
            }
        }
    }

    private var hoursBinding: Binding<Int> {
        Binding(
            get: { Int((tempDuration ?? 0) / 3600) },
            set: { newValue in
                let hours = TimeInterval(newValue)
                let minutes = (tempDuration ?? 0).truncatingRemainder(dividingBy: 3600) / 60
                tempDuration = hours * 3600 + minutes * 60
            }
        )
    }

    private var minutesBinding: Binding<Int> {
        Binding(
            get: { Int(((tempDuration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
            set: { newValue in
                let hours = (tempDuration ?? 0) / 3600
                let minutes = TimeInterval(newValue)
                tempDuration = hours * 3600 + minutes * 60
            }
        )
    }

    @ViewBuilder
    private var notesSection: some View {
        Section("메모") {
            TextField("이번 \(interactionType.title)에서 어떤 이야기를 나눴나요?", text: $tempNotes, axis: .vertical)
                .lineLimit(3...8)
                .autocorrectionDisabled(false)
        }
    }

    @ViewBuilder
    private var photosSection: some View {
        Section {
            VStack(spacing: 12) {
                if !photosData.isEmpty {
                    photoScrollView
                }
                addPhotoButton
                if !photosData.isEmpty {
                    deleteAllPhotosButton
                }
            }
        } header: {
            HStack {
                Text("사진")
                Spacer()
                if !photosData.isEmpty {
                    Text("\(photosData.count)장")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var photoScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(photosData.indices, id: \.self) { index in
                    if let uiImage = UIImage(data: photosData[index]) {
                        photoThumbnailView(image: uiImage, at: index)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func photoThumbnailView(image: UIImage, at index: Int) -> some View {
        VStack(spacing: 8) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 150, height: 150)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )

            Button(role: .destructive) {
                withAnimation {
                    _ = photosData.remove(at: index)
                }
            } label: {
                Label("삭제", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    @ViewBuilder
    private var addPhotoButton: some View {
        Button {
            showingImageOptions = true
        } label: {
            HStack {
                Image(systemName: "photo.badge.plus")
                    .font(.title3)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(photosData.isEmpty ? "사진 추가" : "사진 더 추가")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(interactionType.title) 순간을 사진으로 남겨보세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.blue)
            }
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var deleteAllPhotosButton: some View {
        Button(role: .destructive) {
            withAnimation {
                photosData.removeAll()
            }
        } label: {
            HStack {
                Image(systemName: "trash")
                Text("모든 사진 삭제")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    @ViewBuilder
    private var recordingSection: some View {
        Section("녹음 파일 연결") {
            if let relatedRecord = selectedMeetingRecord {
                connectedRecordingView(relatedRecord)
            } else {
                if availableMeetingRecords.isEmpty {
                    noRecordingsView
                } else {
                    connectRecordingButton
                }
            }
        }
    }

    @ViewBuilder
    private func connectedRecordingView(_ record: MeetingRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform")
                    .foregroundStyle(.blue)
                Text("연결된 녹음")
                    .font(.headline)
                    .foregroundStyle(.blue)
                Spacer()
                Button("변경") {
                    showingRecordPicker = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.meetingType.emoji)
                        .font(.headline)
                    Text(record.meetingType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }

                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Text("길이: \(record.formattedDuration)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if record.hasAudio {
                        Image(systemName: "speaker.wave.2")
                            .font(.caption2)
                            .foregroundStyle(.green)
                        Text("오디오")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                if !record.summary.isEmpty {
                    Text(record.summary)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .padding(.top, 2)
                }
            }

            Button("연결 해제") {
                selectedMeetingRecord = nil
            }
            .font(.caption)
            .foregroundStyle(.red)
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(8)
    }

    @ViewBuilder
    private var noRecordingsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.slash")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("연결할 수 있는 \(getRecordTypeDescription()) 녹음이 없습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    @ViewBuilder
    private var connectRecordingButton: some View {
        Button {
            showingRecordPicker = true
        } label: {
            HStack {
                Image(systemName: "waveform.badge.plus")
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("녹음 파일과 연결하기")
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Text("\(availableMeetingRecords.count)개의 \(getRecordTypeDescription()) 녹음이 있습니다")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewSection: some View {
        Section("미리보기") {
            VStack(alignment: .leading, spacing: 8) {
                previewHeader

                if !tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    previewLocationRow
                }

                if hasDuration, !formattedDurationPreview.isEmpty {
                    previewDurationRow
                }

                if !tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Divider()
                    Text(tempNotes)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .padding(.top, 2)
                }
            }
            .padding()
            .background(interactionType.color.opacity(0.1))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var previewHeader: some View {
        HStack {
            Text(interactionType.emoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(interactionType.title)
                    .font(.headline)
                    .foregroundStyle(interactionType.color)

                Text(tempDate.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var previewLocationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "location")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(tempLocation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var previewDurationRow: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(formattedDurationPreview)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func saveRecord() {
        let finalNotes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalLocation = tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalDuration = hasDuration ? tempDuration : nil
        
        onSave(tempDate, finalNotes, finalLocation, finalDuration, selectedMeetingRecord, photosData)
        dismiss()
    }
    
    // 상호작용 타입에 따른 녹음 타입 설명
    private func getRecordTypeDescription() -> String {
        switch interactionType {
        case .mentoring:
            return "멘토링"
        case .meal:
            return "식사"
        case .contact, .call, .message, .quickNote:
            return "대화"
        case .meeting:
            return "만남"
        }
    }
}

// MARK: - QuickMemoArchiveView
struct QuickMemoArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    let person: Person

    // 최신순으로 정렬된 아카이브 메모들
    private var sortedMemos: [QuickMemoArchive] {
        person.archivedMemos.sorted { $0.createdDate > $1.createdDate }
    }

    var body: some View {
        NavigationStack {
            List {
                if sortedMemos.isEmpty {
                    emptyStateView
                } else {
                    ForEach(sortedMemos, id: \.id) { memo in
                        MemoArchiveRow(memo: memo)
                    }
                    .onDelete(perform: deleteMemos)
                }
            }
            .navigationTitle("메모 아카이브")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }

                if !sortedMemos.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("저장된 메모가 없어요")
                .font(.headline)
                .foregroundStyle(.primary)

            Text("빠른 메모를 작성하고 저장하면 여기에 보관됩니다.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }

    private func deleteMemos(at offsets: IndexSet) {
        for index in offsets {
            let memo = sortedMemos[index]
            context.delete(memo)
        }

        do {
            try context.save()
            print("✅ 메모 삭제 완료")
        } catch {
            print("❌ 메모 삭제 실패: \(error)")
        }
    }
}

// MARK: - MemoArchiveRow
struct MemoArchiveRow: View {
    let memo: QuickMemoArchive
    @State private var showingCopiedAlert = false

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: memo.createdDate, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 날짜와 상대 시간
            HStack {
                Text(memo.createdDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("•")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(relativeDate)
                    .font(.caption)
                    .foregroundStyle(.blue)

                Spacer()

                // 복사 버튼
                Button {
                    copyToClipboard()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showingCopiedAlert ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        if showingCopiedAlert {
                            Text("복사됨")
                                .font(.caption2)
                        }
                    }
                    .foregroundStyle(showingCopiedAlert ? .green : .blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(showingCopiedAlert ? Color.green.opacity(0.1) : Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            // 메모 내용
            Text(memo.content)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(nil)
        }
        .padding(.vertical, 4)
    }

    private func copyToClipboard() {
        UIPasteboard.general.string = memo.content

        // 복사 완료 표시
        withAnimation {
            showingCopiedAlert = true
        }

        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()

        // 2초 후 원래대로
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showingCopiedAlert = false
            }
        }

        print("📋 메모 복사됨: \(memo.content.prefix(50))...")
    }
}
