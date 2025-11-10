//
//  EditInteractionRecordSheet.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// MARK: - EditInteractionRecordSheet
struct EditInteractionRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var record: InteractionRecord
    let person: Person  // 👈 person을 직접 전달받음
    @State private var tempDate: Date
    @State private var tempNotes: String
    @State private var tempLocation: String
    @State private var tempDuration: TimeInterval?
    @State private var hasDuration: Bool
    @State private var showingRecordPicker = false
    @State private var showingImagePicker = false
    @State private var showingImageOptions = false
    @State private var showingCamera = false
    @State private var selectedImage: UIImage?
    @State private var selectedPhotoIndex: Int? = nil // 선택된 사진의 인덱스
    
    // 상호작용 타입에 맞는 미팅 기록들 (날짜 역순)
    private var availableMeetingRecords: [MeetingRecord] {
        let matchingMeetingType: MeetingType
        switch record.type {
        case .mentoring:
            matchingMeetingType = .mentoring
        case .meal:
            matchingMeetingType = .meal
        case .contact, .call, .message:
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
    
    init(record: InteractionRecord, person: Person) {
        self.record = record
        self.person = person
        self._tempDate = State(initialValue: record.date)
        self._tempNotes = State(initialValue: record.notes ?? "")
        self._tempLocation = State(initialValue: record.location ?? "")
        self._tempDuration = State(initialValue: record.duration)
        self._hasDuration = State(initialValue: record.duration != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    HStack {
                        Text(record.type.emoji)
                            .font(.largeTitle)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(record.type.title)
                                .font(.headline)
                            Text("상호작용 기록을 편집해주세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("날짜 및 시간") {
                    DatePicker("날짜와 시간", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                }
                
                Section("장소") {
                    TextField("어디서 만났나요?", text: $tempLocation)
                }
                
                Section("지속 시간") {
                    Toggle("지속 시간 기록", isOn: $hasDuration)
                    
                    if hasDuration {
                        HStack {
                            Text("시간:")
                            Spacer()
                            HStack {
                                TextField("시간", value: Binding(
                                    get: { Int((tempDuration ?? 0) / 3600) },
                                    set: { newValue in
                                        let hours = TimeInterval(newValue)
                                        let minutes = (tempDuration ?? 0).truncatingRemainder(dividingBy: 3600) / 60
                                        tempDuration = hours * 3600 + minutes * 60
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                
                                Text("시간")
                                
                                TextField("분", value: Binding(
                                    get: { Int(((tempDuration ?? 0).truncatingRemainder(dividingBy: 3600)) / 60) },
                                    set: { newValue in
                                        let hours = (tempDuration ?? 0) / 3600
                                        let minutes = TimeInterval(newValue)
                                        tempDuration = hours * 3600 + minutes * 60
                                    }
                                ), format: .number)
                                .textFieldStyle(.roundedBorder)
                                .keyboardType(.numberPad)
                                .frame(width: 60)
                                
                                Text("분")
                            }
                        }
                    }
                }
                
                Section("메모") {
                    TextField("이번 \(record.type.title)에서 어떤 이야기를 나눴나요?", text: $tempNotes, axis: .vertical)
                        .lineLimit(3...8)
                        .autocorrectionDisabled(false)
                }
                
                // 사진 섹션 - 여러 장 지원
                Section {
                    VStack(spacing: 12) {
                        // 기존 사진들 표시
                        let allPhotos = record.allPhotosData
                        if !allPhotos.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(allPhotos.indices, id: \.self) { index in
                                        if let uiImage = UIImage(data: allPhotos[index]) {
                                            VStack(spacing: 8) {
                                                Image(uiImage: uiImage)
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
                                                        deletePhoto(at: index)
                                                    }
                                                } label: {
                                                    Label("삭제", systemImage: "trash")
                                                        .font(.caption)
                                                }
                                                .buttonStyle(.bordered)
                                                .controlSize(.small)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        
                        // 사진 추가 버튼
                        Button {
                            selectedPhotoIndex = nil // 새 사진 추가
                            showingImageOptions = true
                        } label: {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                    .font(.title3)
                                    .foregroundStyle(.blue)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(allPhotos.isEmpty ? "사진 추가" : "사진 더 추가")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text("\(record.type.title) 순간을 사진으로 남겨보세요")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                            .padding(.vertical, 8)
                        }
                        
                        // 모든 사진 삭제 버튼 (사진이 있을 때만)
                        if !allPhotos.isEmpty {
                            Button(role: .destructive) {
                                withAnimation {
                                    record.removeAllPhotos()
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
                    }
                } header: {
                    HStack {
                        Text("사진")
                        Spacer()
                        if !record.allPhotosData.isEmpty {
                            Text("\(record.allPhotosData.count)장")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 모든 상호작용 타입에 대해 녹음 파일 연결 섹션 추가
                Section("녹음 파일 연결") {
                    if let relatedRecord = record.relatedMeetingRecord {
                        // 이미 연결된 녹음이 있는 경우
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
                                    Text(relatedRecord.meetingType.emoji)
                                        .font(.headline)
                                    Text(relatedRecord.meetingType.rawValue)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Spacer()
                                }
                                
                                Text(relatedRecord.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                
                                HStack {
                                    Text("길이: \(relatedRecord.formattedDuration)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    if relatedRecord.hasAudio {
                                        Image(systemName: "speaker.wave.2")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                        Text("오디오")
                                            .font(.caption2)
                                            .foregroundStyle(.green)
                                    }
                                }
                                
                                if !relatedRecord.summary.isEmpty {
                                    Text(relatedRecord.summary)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .padding(.top, 2)
                                }
                            }
                            
                            Button("연결 해제") {
                                record.relatedMeetingRecord = nil
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(8)
                    } else {
                        // 연결된 녹음이 없는 경우
                        if availableMeetingRecords.isEmpty {
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
                        } else {
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
                    }
                }
                
                Section("미리보기") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(record.type.emoji)
                                .font(.title2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(record.type.title)
                                    .font(.headline)
                                    .foregroundStyle(record.type.color)
                                
                                Text(tempDate.formatted(date: .long, time: .shortened))
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if !tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(tempLocation)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if hasDuration, let duration = tempDuration, duration > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                let minutes = Int(duration) / 60
                                let hours = minutes / 60
                                let remainingMinutes = minutes % 60
                                if hours > 0 {
                                    Text("\(hours)시간 \(remainingMinutes)분")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(minutes)분")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
                    .background(record.type.color.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .navigationTitle("상호작용 편집")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveChanges()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingRecordPicker) {
                RecordPickerView(
                    interactionType: record.type,
                    availableRecords: availableMeetingRecords,
                    onRecordSelected: { meetingRecord in
                        record.relatedMeetingRecord = meetingRecord
                        
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
                        // 새 사진 추가
                        record.addPhoto(imageData)
                    }
                    selectedImage = nil // 다음 추가를 위해 초기화
                }
            }
        }
        .onDisappear {
            if !hasDuration {
                tempDuration = nil
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 특정 인덱스의 사진 삭제
    private func deletePhoto(at index: Int) {
        let allPhotos = record.allPhotosData
        guard index >= 0 && index < allPhotos.count else { return }
        
        // 레거시 photoData인지 확인
        if index == 0 && record.photoData != nil {
            record.photoData = nil
        } else {
            // photosData 배열에서 삭제 (레거시 photoData가 있으면 인덱스 조정)
            let adjustedIndex = record.photoData != nil ? index - 1 : index
            if adjustedIndex >= 0 && adjustedIndex < record.photosData.count {
                record.photosData.remove(at: adjustedIndex)
            }
        }
    }
    
    private func saveChanges() {
        record.date = tempDate
        record.notes = tempNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        record.location = tempLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : tempLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        record.duration = hasDuration ? tempDuration : nil
        
        // 기존 lastXXX 필드도 업데이트 (최신 기록인 경우에만)
        let sameTypeRecords = person.getInteractionRecords(ofType: record.type)
        if sameTypeRecords.first?.id == record.id {
            // 이것이 해당 타입의 가장 최근 기록이면 lastXXX 업데이트
            switch record.type {
            case .mentoring:
                person.lastMentoring = record.date
                person.mentoringNotes = record.notes
            case .meal:
                person.lastMeal = record.date
                person.mealNotes = record.notes
            case .contact, .call, .message:
                person.lastContact = record.date
                person.contactNotes = record.notes
            case .meeting:
                break
            }
        }
        
        // 관계 상태 업데이트
        person.updateRelationshipState()
        
        do {
            try context.save()
            print("✅ 상호작용 기록 수정 완료")
            
            // 햅틱 피드백
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        } catch {
            print("❌ 상호작용 기록 수정 실패: \(error)")
        }
    }
    
    // 상호작용 타입에 따른 녹음 타입 설명
    private func getRecordTypeDescription() -> String {
        switch record.type {
        case .mentoring:
            return "멘토링"
        case .meal:
            return "식사"
        case .contact, .call, .message:
            return "대화"
        case .meeting:
            return "만남"
        }
    }
}

// MARK: - RecordPickerView (모든 상호작용 타입 지원)
struct RecordPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let interactionType: InteractionType
    let availableRecords: [MeetingRecord]
    let onRecordSelected: (MeetingRecord?) -> Void
    
    private var titleText: String {
        switch interactionType {
        case .mentoring:
            return "멘토링 녹음 연결"
        case .meal:
            return "식사 녹음 연결"
        case .contact, .call, .message:
            return "대화 녹음 연결"
        case .meeting:
            return "만남 녹음 연결"
        }
    }
    
    private var descriptionText: String {
        switch interactionType {
        case .mentoring:
            return "이 멘토링과 연관된 녹음 파일을 선택하세요"
        case .meal:
            return "이 식사와 연관된 녹음 파일을 선택하세요"
        case .contact, .call, .message:
            return "이 연락/대화와 연관된 녹음 파일을 선택하세요"
        case .meeting:
            return "이 만남과 연관된 녹음 파일을 선택하세요"
        }
    }
    
    private var emptyStateText: String {
        switch interactionType {
        case .mentoring:
            return "멘토링 녹음 파일이 없습니다"
        case .meal:
            return "식사 관련 녹음 파일이 없습니다"
        case .contact, .call, .message:
            return "대화 관련 녹음 파일이 없습니다"
        case .meeting:
            return "만남 관련 녹음 파일이 없습니다"
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // 헤더
                VStack(spacing: 12) {
                    Text(interactionType.emoji)
                        .font(.system(size: 60))
                    
                    Text(titleText)
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(descriptionText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                if availableRecords.isEmpty {
                    // 녹음 파일이 없는 경우
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.slash")
                            .font(.system(size: 40))
                            .foregroundStyle(.secondary)
                        
                        Text(emptyStateText)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("녹음 파일 없이 기록을 유지하시겠습니까?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("녹음 없이 유지") {
                            onRecordSelected(nil)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                } else {
                    // 녹음 파일 목록
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(availableRecords, id: \.id) { record in
                                UniversalRecordCard(record: record) {
                                    onRecordSelected(record)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 하단 버튼들
                    VStack(spacing: 12) {
                        Button("녹음 파일과 연결하지 않음") {
                            onRecordSelected(nil)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.bottom)
                }
                
                Spacer()
            }
            .navigationTitle("녹음 파일 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - UniversalRecordCard (모든 미팅 타입 지원)
struct UniversalRecordCard: View {
    let record: MeetingRecord
    let onTap: () -> Void
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: record.date, relativeTo: Date())
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // 헤더 - 미팅 타입, 날짜와 시간
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(record.meetingType.emoji)
                                .font(.title3)
                            Text(record.meetingType.rawValue)
                                .font(.headline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        
                        Text(relativeDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text(record.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    
                    Spacer()
                    
                    // 녹음 길이와 오디오 아이콘
                    VStack(alignment: .trailing, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "waveform")
                                .font(.caption)
                            Text(record.formattedDuration)
                                .font(.caption)
                        }
                        .foregroundStyle(.blue)
                        
                        if record.hasAudio {
                            HStack(spacing: 2) {
                                Image(systemName: "speaker.wave.2")
                                    .font(.caption2)
                                Text("오디오")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.green)
                        }
                    }
                }
                
                // 내용 - 요약 또는 전사 텍스트
                VStack(alignment: .leading, spacing: 8) {
                    if !record.summary.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("요약")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.blue)
                            
                            Text(record.summary)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(3)
                        }
                    }
                    
                    if !record.transcribedText.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("전사 내용")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            
                            Text(record.transcribedText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    
                    if record.summary.isEmpty && record.transcribedText.isEmpty {
                        Text("내용이 없습니다")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .italic()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(getMeetingTypeColor().opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // 미팅 타입별 색상
    private func getMeetingTypeColor() -> Color {
        switch record.meetingType {
        case .mentoring:
            return .blue
        case .meal:
            return .green
        case .coffee:
            return .orange
        case .general:
            return .purple
        case .presentation:
            return .red
        case .oneOnOne:
            return .pink
        }
    }
}
