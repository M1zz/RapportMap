//
//  DiscoveryDetailSheet.swift
//  RapportMap
//
//  발견 상세 시트
//

import SwiftUI
import SwiftData

struct DiscoveryDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @Bindable var discovery: Discovery
    
    @State private var isEditing = false
    @State private var editedContent = ""
    @State private var editedContext = ""
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 헤더
                    headerSection
                    
                    // 내용
                    contentSection
                    
                    // 맥락
                    if let context = discovery.context, !context.isEmpty {
                        contextSection(context)
                    }
                    
                    // 감정
                    if let emotion = discovery.emotion {
                        emotionSection(emotion)
                    }
                    
                    // 메타 정보
                    metaSection
                }
                .padding()
            }
            .navigationTitle("발견")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            startEditing()
                        } label: {
                            Label("수정", systemImage: "pencil")
                        }
                        
                        Button {
                            discovery.isSignificant.toggle()
                            try? context.save()
                        } label: {
                            Label(
                                discovery.isSignificant ? "중요 해제" : "중요 표시",
                                systemImage: discovery.isSignificant ? "star.slash" : "star"
                            )
                        }
                        
                        Divider()
                        
                        Button(role: .destructive) {
                            showingDeleteAlert = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $isEditing) {
                EditDiscoverySheet(
                    discovery: discovery,
                    content: $editedContent,
                    contextText: $editedContext
                )
            }
            .alert("발견 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) {}
                Button("삭제", role: .destructive) {
                    deleteDiscovery()
                }
            } message: {
                Text("이 발견을 삭제할까요?")
            }
        }
        #if os(macOS)
        .frame(width: 450, height: 500)
        #endif
    }
    
    // MARK: - 헤더
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // 영역 아이콘
            ZStack {
                Circle()
                    .fill(discovery.displayColor.opacity(0.15))
                    .frame(width: 70, height: 70)
                
                Text(discovery.displayEmoji)
                    .font(.system(size: 32))
                
                // 중요 표시
                if discovery.isSignificant {
                    Image(systemName: "star.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                        .offset(x: 25, y: -25)
                }
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(discovery.territory.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                HStack(spacing: 8) {
                    Text(discovery.depth.icon)
                    Text(discovery.depth.title)
                        .foregroundStyle(discovery.displayColor)
                }
                .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .background(discovery.displayColor.opacity(0.05))
        .cornerRadius(16)
    }
    
    // MARK: - 내용
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("알게 된 것", systemImage: "lightbulb.fill")
                .font(.headline)
                .foregroundStyle(discovery.displayColor)
            
            Text(discovery.content)
                .font(.body)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondaryBackground)
                .cornerRadius(12)
        }
    }
    
    // MARK: - 맥락
    
    private func contextSection(_ context: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("상황", systemImage: "bubble.left")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Text(context)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.secondaryBackground)
                .cornerRadius(12)
        }
    }
    
    // MARK: - 감정
    
    private func emotionSection(_ emotion: DiscoveryEmotion) -> some View {
        HStack(spacing: 12) {
            Text(emotion.emoji)
                .font(.title)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("그때 느낌")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(emotion.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 메타
    
    private var metaSection: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(.secondary)
                Text(discovery.date.formatted(date: .long, time: .omitted))
                Spacer()
                Text(discovery.relativeDate)
                    .foregroundStyle(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
    
    // MARK: - 액션
    
    private func startEditing() {
        editedContent = discovery.content
        editedContext = discovery.context ?? ""
        isEditing = true
    }
    
    private func deleteDiscovery() {
        context.delete(discovery)
        try? context.save()
        dismiss()
    }
}

// MARK: - 수정 시트

struct EditDiscoverySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let discovery: Discovery
    @Binding var content: String
    @Binding var contextText: String
    
    var body: some View {
        NavigationStack {
            Form {
                Section("내용") {
                    TextEditor(text: $content)
                        .frame(minHeight: 100)
                }
                
                Section("상황") {
                    TextField("어떤 상황에서 알게 됐나요?", text: $contextText, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("수정")
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
                        saveChanges()
                    }
                    .disabled(content.isEmpty)
                }
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 350)
        #endif
    }
    
    private func saveChanges() {
        discovery.content = content
        discovery.context = contextText.isEmpty ? nil : contextText
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)
    
    let person = Person(name: "김철수")
    container.mainContext.insert(person)
    
    let discovery = Discovery(
        territory: .nickname,
        content: "달빛이라는 닉네임은 밤에 산책하는 걸 좋아해서 붙인 거래요.",
        context: "첫 번째 저녁 식사에서 물어봤어요",
        emotion: .closer,
        isSignificant: true
    )
    discovery.person = person
    container.mainContext.insert(discovery)
    
    return DiscoveryDetailSheet(discovery: discovery)
        .modelContainer(container)
}
