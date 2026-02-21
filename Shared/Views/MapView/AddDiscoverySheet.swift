//
//  AddDiscoverySheet.swift
//  RapportMap
//
//  발견 추가 시트
//

import SwiftUI
import SwiftData

struct AddDiscoverySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let person: Person
    let territory: Territory
    var onSuccess: (() -> Void)?
    
    @State private var content = ""
    @State private var contextText = ""
    @State private var selectedEmotion: DiscoveryEmotion?
    @State private var isSignificant = false
    @State private var date = Date()
    
    @FocusState private var isContentFocused: Bool
    
    init(person: Person, territory: Territory, onSuccess: (() -> Void)? = nil) {
        self.person = person
        self.territory = territory
        self.onSuccess = onSuccess
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 헤더
                    headerSection
                    
                    // 내용 입력
                    contentSection
                    
                    // 맥락 (선택)
                    contextSection
                    
                    // 감정 선택
                    emotionSection
                    
                    // 옵션
                    optionsSection
                }
                .padding()
            }
            .navigationTitle("새로운 발견")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveDiscovery()
                    }
                    .disabled(content.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            isContentFocused = true
        }
        #if os(macOS)
        .frame(width: 450, height: 550)
        #endif
    }
    
    // MARK: - 헤더
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // 영역 아이콘
            ZStack {
                Circle()
                    .fill(territory.depth.color.opacity(0.15))
                    .frame(width: 60, height: 60)
                
                Text(territory.emoji)
                    .font(.system(size: 28))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(territory.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(territory.prompt)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(territory.depth.color.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - 내용
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("뭘 알게 됐나요?", systemImage: "lightbulb")
                .font(.headline)
            
            TextEditor(text: $content)
                .focused($isContentFocused)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color.secondaryBackground)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - 맥락
    
    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("어떤 상황에서? (선택)", systemImage: "bubble.left")
                .font(.headline)
            
            TextField("예: 저녁 먹으면서 이야기하다가...", text: $contextText, axis: .vertical)
                .lineLimit(2...4)
                .padding(12)
                .background(Color.secondaryBackground)
                .cornerRadius(12)
        }
    }
    
    // MARK: - 감정
    
    private var emotionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("그때 느낌은?", systemImage: "heart")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 80), spacing: 8)
            ], spacing: 8) {
                ForEach(DiscoveryEmotion.allCases) { emotion in
                    EmotionChip(
                        emotion: emotion,
                        isSelected: selectedEmotion == emotion
                    ) {
                        if selectedEmotion == emotion {
                            selectedEmotion = nil
                        } else {
                            selectedEmotion = emotion
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - 옵션
    
    private var optionsSection: some View {
        VStack(spacing: 12) {
            // 날짜
            HStack {
                Label("날짜", systemImage: "calendar")
                Spacer()
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
            }
            
            Divider()
            
            // 중요 표시
            Toggle(isOn: $isSignificant) {
                Label("특별한 발견", systemImage: "star")
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 저장
    
    private func saveDiscovery() {
        let discovery = Discovery(
            date: date,
            territory: territory,
            content: content,
            context: contextText.isEmpty ? nil : contextText,
            emotion: selectedEmotion,
            isSignificant: isSignificant
        )
        
        discovery.person = person
        context.insert(discovery)
        
        do {
            try context.save()
            dismiss()
            onSuccess?()
        } catch {
            print("❌ 발견 저장 실패: \(error)")
        }
    }
}

// MARK: - 감정 칩

struct EmotionChip: View {
    let emotion: DiscoveryEmotion
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(emotion.emoji)
                    .font(.title2)
                Text(emotion.title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.15) : Color.tertiaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)
    
    let person = Person(name: "김철수")
    container.mainContext.insert(person)
    
    return AddDiscoverySheet(person: person, territory: .nickname)
        .modelContainer(container)
}
