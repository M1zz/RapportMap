//
//  QuickVoiceMemoView.swift
//  RapportMap
//
//  빠른 음성 메모 기능 - 앱 어디서든 빠르게 음성으로 메모
//

import SwiftUI
import SwiftData
import AVFoundation
import Speech

#if os(iOS)

// MARK: - Quick Voice Memo View
struct QuickVoiceMemoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Query(sort: \Person.name) private var allPeople: [Person]
    
    @StateObject private var recorder = VoiceRecorder()
    @State private var selectedPerson: Person?
    @State private var detectedPersons: [Person] = []
    @State private var showingPersonPicker = false
    @State private var isSaved = false
    @State private var saveType: SaveType = .quickMemo
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""
    
    // 최근 상호작용 기준 추천
    private var recentlyInteractedPeople: [Person] {
        allPeople
            .filter { $0.mostRecentInteractionDate != nil }
            .sorted { 
                ($0.mostRecentInteractionDate ?? Date.distantPast) > 
                ($1.mostRecentInteractionDate ?? Date.distantPast) 
            }
            .prefix(5)
            .map { $0 }
    }
    
    enum SaveType: String, CaseIterable {
        case quickMemo = "빠른 메모"
        case interaction = "상호작용 기록"
        case conversation = "대화 기록"
        
        var icon: String {
            switch self {
            case .quickMemo: return "note.text"
            case .interaction: return "person.2"
            case .conversation: return "bubble.left.and.bubble.right"
            }
        }
        
        var color: Color {
            switch self {
            case .quickMemo: return .yellow
            case .interaction: return .blue
            case .conversation: return .purple
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 배경
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // 상단: 사람 선택
                    personSelectionSection
                    
                    // 중앙: 녹음 상태 및 전사 텍스트
                    recordingSection
                    
                    Spacer()
                    
                    // 하단: 저장 옵션 및 컨트롤
                    if recorder.audioFileURL != nil && !recorder.isRecording {
                        saveOptionsSection
                    }
                    
                    controlSection
                }
                .padding()
            }
            .navigationTitle("빠른 음성 메모")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        if recorder.isRecording {
                            recorder.stopRecording()
                        }
                        dismiss()
                    }
                }
            }
            .onAppear {
                checkPermissions()
            }
            .onChange(of: recorder.finalTranscription) { _, newTranscription in
                detectPersonsInText(newTranscription)
            }
            .alert("권한 필요", isPresented: $showingPermissionAlert) {
                Button("설정으로 이동") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("취소", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text(permissionMessage)
            }
            .sheet(isPresented: $showingPersonPicker) {
                PersonPickerSheet(
                    people: allPeople,
                    selectedPerson: $selectedPerson,
                    recentPeople: recentlyInteractedPeople
                )
            }
        }
    }
    
    // MARK: - View Sections
    
    private var personSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("누구에 대한 메모인가요?")
                .font(.headline)
            
            // 선택된 사람 또는 선택 버튼
            Button {
                showingPersonPicker = true
            } label: {
                HStack {
                    if let person = selectedPerson {
                        // 프로필 이미지
                        if let imageData = person.profileImageData,
                           let uiImage = UIImage(data: imageData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(person.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            
                            if let lastDate = person.mostRecentInteractionDate {
                                Text("마지막 만남: \(lastDate.relative())")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } else {
                        Image(systemName: "person.circle.badge.plus")
                            .font(.system(size: 36))
                            .foregroundStyle(.blue)
                        
                        Text("사람 선택하기")
                            .font(.headline)
                            .foregroundStyle(.blue)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemGroupedBackground))
                )
            }
            
            // 텍스트에서 감지된 사람들
            if !detectedPersons.isEmpty && selectedPerson == nil {
                VStack(alignment: .leading, spacing: 8) {
                    Text("💡 텍스트에서 감지됨")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(detectedPersons) { person in
                                Button {
                                    selectedPerson = person
                                } label: {
                                    HStack(spacing: 6) {
                                        if let imageData = person.profileImageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 24, height: 24)
                                                .clipShape(Circle())
                                        }
                                        Text(person.name)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue.opacity(0.1))
                                    )
                                    .foregroundStyle(.blue)
                                }
                            }
                        }
                    }
                }
            }
            
            // 최근 만난 사람 추천 (선택된 사람이 없을 때)
            if selectedPerson == nil && detectedPersons.isEmpty && !recentlyInteractedPeople.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("최근 만난 사람")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentlyInteractedPeople) { person in
                                Button {
                                    selectedPerson = person
                                } label: {
                                    HStack(spacing: 6) {
                                        if let imageData = person.profileImageData,
                                           let uiImage = UIImage(data: imageData) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 24, height: 24)
                                                .clipShape(Circle())
                                        }
                                        Text(person.name)
                                            .font(.subheadline)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(Color(.tertiarySystemGroupedBackground))
                                    )
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var recordingSection: some View {
        VStack(spacing: 16) {
            // 녹음 상태 표시
            if recorder.isRecording {
                // 녹음 중 파형
                WaveformView(
                    audioLevels: recorder.audioLevels,
                    currentLevel: recorder.currentAudioLevel,
                    isRecording: recorder.isRecording
                )
                .frame(height: 80)
                
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .scaleEffect(recorder.isRecording ? 1.0 : 0.8)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: recorder.isRecording)
                    
                    Text("녹음 중")
                        .font(.headline)
                        .foregroundStyle(.red)
                    
                    Text(formatDuration(recorder.recordingDuration))
                        .font(.system(.headline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            } else if isSaved {
                // 저장 완료
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.green.gradient)
                            .frame(width: 80, height: 80)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Text("저장 완료!")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let person = selectedPerson {
                        Text("\(person.name)님에게 저장됨")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .onAppear {
                    // 2초 후 자동 닫기
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        dismiss()
                    }
                }
            } else if recorder.audioFileURL != nil {
                // 녹음 완료, 저장 대기
                VStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue)
                    
                    Text("녹음 완료")
                        .font(.headline)
                    
                    Text(formatDuration(recorder.recordingDuration))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                // 녹음 준비
                VStack(spacing: 8) {
                    Image(systemName: "mic.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.gray)
                    
                    Text("버튼을 눌러 녹음을 시작하세요")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 실시간 전사 텍스트
            if !recorder.finalTranscription.isEmpty || recorder.isTranscribing {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("인식된 텍스트")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        if recorder.isTranscribing {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                    
                    ScrollView {
                        Text(recorder.finalTranscription.isEmpty ? "음성을 인식하는 중..." : recorder.finalTranscription)
                            .font(.body)
                            .foregroundStyle(recorder.finalTranscription.isEmpty ? .secondary : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 120)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.secondarySystemGroupedBackground))
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.secondarySystemGroupedBackground))
        )
    }
    
    private var saveOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("저장 방식")
                .font(.headline)
            
            HStack(spacing: 12) {
                ForEach(SaveType.allCases, id: \.self) { type in
                    Button {
                        saveType = type
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: type.icon)
                                .font(.title2)
                                .foregroundStyle(saveType == type ? type.color : .gray)
                            
                            Text(type.rawValue)
                                .font(.caption)
                                .foregroundStyle(saveType == type ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(saveType == type ? type.color.opacity(0.1) : Color(.tertiarySystemGroupedBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(saveType == type ? type.color : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
        }
    }
    
    private var controlSection: some View {
        VStack(spacing: 16) {
            if recorder.isRecording {
                // 녹음 중 - 중지 버튼
                Button {
                    recorder.stopRecording()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "stop.circle.fill")
                            .font(.title2)
                        Text("녹음 완료")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            } else if recorder.audioFileURL != nil && !isSaved {
                // 녹음 완료 - 저장 버튼
                VStack(spacing: 12) {
                    Button {
                        saveRecording()
                    } label: {
                        HStack(spacing: 12) {
                            if recorder.isTranscribing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "square.and.arrow.down.fill")
                                    .font(.title2)
                            }
                            Text(recorder.isTranscribing ? "처리 중..." : "저장하기")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedPerson == nil ? Color.gray : Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(selectedPerson == nil || recorder.isTranscribing)
                    
                    if selectedPerson == nil {
                        Text("저장하려면 사람을 선택해주세요")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    
                    // 다시 녹음 버튼
                    Button {
                        recorder.reset()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("다시 녹음")
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                }
            } else if !isSaved {
                // 녹음 시작 버튼
                Button {
                    recorder.startRecording()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "mic.fill")
                            .font(.title2)
                        Text("녹음 시작")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.red)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func checkPermissions() {
        // 마이크 권한 확인
        switch AVAudioSession.sharedInstance().recordPermission {
        case .undetermined:
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                if !granted {
                    DispatchQueue.main.async {
                        permissionMessage = "음성 메모를 녹음하려면 마이크 권한이 필요합니다."
                        showingPermissionAlert = true
                    }
                }
            }
        case .denied:
            permissionMessage = "음성 메모를 녹음하려면 마이크 권한이 필요합니다."
            showingPermissionAlert = true
        case .granted:
            break
        @unknown default:
            break
        }
        
        // 음성 인식 권한 확인
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async {
                    permissionMessage = "음성을 텍스트로 변환하려면 음성 인식 권한이 필요합니다."
                    showingPermissionAlert = true
                }
            }
        }
    }
    
    private func detectPersonsInText(_ text: String) {
        guard !text.isEmpty else {
            detectedPersons = []
            return
        }
        
        // 텍스트에서 사람 이름 찾기
        let matches = allPeople.filter { person in
            text.localizedCaseInsensitiveContains(person.name)
        }
        
        detectedPersons = matches
        
        // 자동으로 첫 번째 감지된 사람 선택 (선택된 사람이 없을 때만)
        if selectedPerson == nil && !matches.isEmpty {
            selectedPerson = matches.first
        }
    }
    
    private func saveRecording() {
        guard let person = selectedPerson else { return }
        
        let transcription = recorder.finalTranscription
        
        switch saveType {
        case .quickMemo:
            saveAsQuickMemo(person: person, text: transcription)
            
        case .interaction:
            saveAsInteraction(person: person, text: transcription)
            
        case .conversation:
            saveAsConversation(person: person, text: transcription)
        }
    }
    
    private func saveAsQuickMemo(person: Person, text: String) {
        let memo = QuickMemoArchive(
            content: text.isEmpty ? "음성 메모 (\(formatDuration(recorder.recordingDuration)))" : text,
            createdDate: Date()
        )
        memo.person = person
        
        context.insert(memo)
        
        do {
            try context.save()
            print("✅ Quick memo saved for \(person.name)")
            isSaved = true
        } catch {
            print("❌ Failed to save quick memo: \(error)")
        }
    }
    
    private func saveAsInteraction(person: Person, text: String) {
        let interaction = InteractionRecord(
            date: Date(),
            type: .quickNote,
            notes: text.isEmpty ? "음성 메모 (\(formatDuration(recorder.recordingDuration)))" : text,
            duration: recorder.recordingDuration
        )
        interaction.person = person
        
        context.insert(interaction)
        
        // lastContact 업데이트
        person.lastContact = Date()
        
        do {
            try context.save()
            print("✅ Interaction record saved for \(person.name)")
            isSaved = true
        } catch {
            print("❌ Failed to save interaction: \(error)")
        }
    }
    
    private func saveAsConversation(person: Person, text: String) {
        // 텍스트 분석으로 대화 유형 감지
        let conversationType = detectConversationType(from: text)
        
        let _ = person.addConversationRecord(
            type: conversationType,
            content: text.isEmpty ? "음성 메모 (\(formatDuration(recorder.recordingDuration)))" : text,
            notes: "음성 녹음에서 생성됨",
            priority: .normal,
            date: Date()
        )
        
        do {
            try context.save()
            print("✅ Conversation record saved for \(person.name)")
            isSaved = true
        } catch {
            print("❌ Failed to save conversation: \(error)")
        }
    }
    
    private func detectConversationType(from text: String) -> ConversationType {
        let lowercasedText = text.lowercased()
        
        // 약속 키워드
        let promiseKeywords = ["약속", "해줄게", "해드릴게", "보내줄게", "알려줄게", "연락할게", "다음에", "나중에"]
        if promiseKeywords.contains(where: { lowercasedText.contains($0) }) {
            return .promise
        }
        
        // 질문 키워드
        let questionKeywords = ["?", "뭐야", "어때", "할까", "있어", "없어", "언제", "어디", "왜", "어떻게"]
        if questionKeywords.contains(where: { lowercasedText.contains($0) }) {
            return .question
        }
        
        // 고민 키워드
        let concernKeywords = ["고민", "걱정", "힘들", "어려", "스트레스", "문제"]
        if concernKeywords.contains(where: { lowercasedText.contains($0) }) {
            return .concern
        }
        
        // 성취/좋은 소식 키워드
        let achievementKeywords = ["성공", "합격", "좋은 소식", "잘됐", "축하", "이뤘"]
        if achievementKeywords.contains(where: { lowercasedText.contains($0) }) {
            return .achievement
        }
        
        // 기본값: 근황 업데이트
        return .update
    }
}

// MARK: - Person Picker Sheet
struct PersonPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    let people: [Person]
    @Binding var selectedPerson: Person?
    let recentPeople: [Person]
    
    @State private var searchText = ""
    
    private var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 최근 만난 사람 섹션
                if searchText.isEmpty && !recentPeople.isEmpty {
                    Section("최근 만난 사람") {
                        ForEach(recentPeople) { person in
                            personRow(person)
                        }
                    }
                }
                
                // 전체 목록
                Section(searchText.isEmpty ? "전체" : "검색 결과") {
                    ForEach(filteredPeople) { person in
                        if !recentPeople.contains(where: { $0.id == person.id }) || !searchText.isEmpty {
                            personRow(person)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "이름으로 검색")
            .navigationTitle("사람 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func personRow(_ person: Person) -> some View {
        Button {
            selectedPerson = person
            dismiss()
        } label: {
            HStack(spacing: 12) {
                // 프로필 이미지
                if let imageData = person.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 44, height: 44)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.gray)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    if let lastDate = person.mostRecentInteractionDate {
                        Text("마지막: \(lastDate.relative())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                if selectedPerson?.id == person.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                }
            }
        }
    }
}

// MARK: - Floating Mic Button
struct FloatingMicButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.red, Color.red.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .shadow(color: .red.opacity(0.3), radius: 8, x: 0, y: 4)
                
                Image(systemName: "mic.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.white)
            }
        }
    }
}

#endif
