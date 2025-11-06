import SwiftUI
import SwiftData

/// 새로운 대화/상태 기록을 추가하기 위한 모달 뷰
/// 질문, 고민, 약속 등의 다양한 대화 내용을 입력할 수 있음
struct AddConversationView: View {
    // MARK: - Environment
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Properties
    let person: Person
    
    // MARK: - State
    @State private var selectedType: ConversationType = .question
    @State private var content: String = ""
    @State private var notes: String = ""
    @State private var selectedPriority: ConversationPriority = .normal
    @State private var tagsText: String = ""
    @State private var selectedDate: Date = Date()
    @State private var isResolved: Bool = false
    
    // MARK: - Computed Properties
    private var isValidContent: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var tagsArray: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - 헤더
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .foregroundColor(.blue)
                            Text("\(person.name)님과의 대화/상태")
                                .font(.title2)
                                .fontWeight(.semibold)
                        }
                        
                        Text("새로운 대화 내용이나 상태 정보를 기록하세요")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Divider()
                    
                    // MARK: - 대화 타입 선택
                    VStack(alignment: .leading, spacing: 12) {
                        Label("대화 타입", systemImage: "list.bullet.circle")
                            .font(.headline)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                            ForEach(ConversationType.allCases, id: \.self) { type in
                                ConversationTypeCard(
                                    type: type,
                                    isSelected: selectedType == type
                                ) {
                                    selectedType = type
                                }
                            }
                        }
                    }
                    
                    // MARK: - 내용 입력
                    VStack(alignment: .leading, spacing: 8) {
                        Label("내용", systemImage: "text.bubble")
                            .font(.headline)
                        
                        TextField(
                            getContentPlaceholder(),
                            text: $content,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(3...6)
                        
                        Text("\(content.count)/500자")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                    
                    // MARK: - 추가 메모
                    VStack(alignment: .leading, spacing: 8) {
                        Label("추가 메모", systemImage: "note.text")
                            .font(.headline)
                        
                        TextField(
                            "상세 내용이나 배경 정보를 입력하세요 (선택사항)",
                            text: $notes,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                    }
                    
                    // MARK: - 우선순위 및 설정
                    VStack(alignment: .leading, spacing: 12) {
                        Label("설정", systemImage: "gearshape")
                            .font(.headline)
                        
                        // 우선순위
                        VStack(alignment: .leading, spacing: 8) {
                            Text("우선순위")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 12) {
                                ForEach(ConversationPriority.allCases, id: \.self) { priority in
                                    PriorityButton(
                                        priority: priority,
                                        isSelected: selectedPriority == priority
                                    ) {
                                        selectedPriority = priority
                                    }
                                }
                            }
                        }
                        
                        // 날짜
                        HStack {
                            Text("날짜")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                        }
                        
                        // 해결 여부
                        if selectedType == .question || selectedType == .promise || selectedType == .request {
                            Toggle(isOn: $isResolved) {
                                HStack {
                                    Image(systemName: isResolved ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(isResolved ? .green : .gray)
                                    Text(getResolvedToggleText())
                                        .font(.subheadline)
                                }
                            }
                            .toggleStyle(SwitchToggleStyle())
                        }
                    }
                    
                    // MARK: - 태그
                    VStack(alignment: .leading, spacing: 8) {
                        Label("태그", systemImage: "tag")
                            .font(.headline)
                        
                        TextField(
                            "태그를 쉼표로 구분하여 입력 (예: 업무, 개인, 중요)",
                            text: $tagsText
                        )
                        .textFieldStyle(.roundedBorder)
                        
                        if !tagsArray.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tagsArray, id: \.self) { tag in
                                        Text(tag)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.blue.opacity(0.1))
                                            .foregroundColor(.blue)
                                            .cornerRadius(8)
                                            .font(.caption)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("대화/상태 기록")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("저장") {
                        saveConversation()
                    }
                    .disabled(!isValidContent)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// 선택된 타입에 따른 내용 플레이스홀더 반환
    private func getContentPlaceholder() -> String {
        switch selectedType {
        case .question:
            return "받은 질문을 입력하세요..."
        case .concern:
            return "고민이나 상담 내용을 입력하세요..."
        case .promise:
            return "약속한 내용을 입력하세요..."
        case .update:
            return "근황이나 업데이트 내용을 입력하세요..."
        case .feedback:
            return "받은 피드백을 입력하세요..."
        case .request:
            return "요청받은 내용을 입력하세요..."
        case .achievement:
            return "성취나 좋은 소식을 입력하세요..."
        case .problem:
            return "문제나 어려움을 입력하세요..."
        }
    }
    
    /// 해결 토글 텍스트 반환
    private func getResolvedToggleText() -> String {
        switch selectedType {
        case .question:
            return isResolved ? "답변 완료" : "답변 대기"
        case .promise:
            return isResolved ? "약속 이행됨" : "약속 이행 대기"
        case .request:
            return isResolved ? "요청 처리됨" : "요청 처리 대기"
        default:
            return isResolved ? "해결됨" : "진행중"
        }
    }
    
    /// 대화 기록 저장
    private func saveConversation() {
        let record = person.addConversationRecord(
            type: selectedType,
            content: content,
            notes: notes.isEmpty ? nil : notes,
            priority: selectedPriority,
            tags: tagsArray,
            date: selectedDate
        )
        
        record.isResolved = isResolved
        
        // SwiftData에 저장
        modelContext.insert(record)
        
        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ 대화 기록 저장 실패: \(error)")
        }
    }
}

// MARK: - 대화 타입 카드 뷰
struct ConversationTypeCard: View {
    let type: ConversationType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(type.emoji)
                    .font(.title2)
                
                Text(type.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .frame(height: 60)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? type.color.opacity(0.2) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? type.color : Color.clear, lineWidth: 2)
                    )
            )
            .foregroundColor(isSelected ? type.color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 우선순위 버튼 뷰
struct PriorityButton: View {
    let priority: ConversationPriority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(priority.emoji)
                Text(priority.title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? priority.color.opacity(0.2) : Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? priority.color : Color.clear, lineWidth: 1)
                    )
            )
            .foregroundColor(isSelected ? priority.color : .primary)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview
#Preview {
    AddConversationView(person: Person(name: "김철수"))
        .modelContainer(for: [Person.self, ConversationRecord.self])
}