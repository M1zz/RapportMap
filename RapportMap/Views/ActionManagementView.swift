//
//  ActionManagementView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import SwiftUI
import SwiftData

struct ActionManagementView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RapportAction.order) private var allActions: [RapportAction]
    @State private var selectedPhase: ActionPhase = .phase1
    @State private var showingAddAction = false
    
    private var actionsForSelectedPhase: [RapportAction] {
        allActions.filter { $0.phase == selectedPhase }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Phase 선택기
                Picker("Phase", selection: $selectedPhase) {
                    ForEach(ActionPhase.allCases) { phase in
                        Text("\(phase.emoji) \(phase.rawValue)")
                            .tag(phase)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // 선택된 Phase 설명
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedPhase.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // 액션 리스트
                List {
                    ForEach(actionsForSelectedPhase) { action in
                        NavigationLink(destination: ActionDetailView(action: action)) {
                            ActionRowView(action: action)
                        }
                    }
                    .onDelete(perform: deleteActions)
                }
            }
            .navigationTitle("라포 액션 관리")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddAction = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddAction) {
                AddActionSheet(phase: selectedPhase)
            }
        }
    }
    
    private func deleteActions(at offsets: IndexSet) {
        for index in offsets {
            let action = actionsForSelectedPhase[index]
            
            // 기본 액션은 삭제 불가
            if action.isDefault {
                continue
            }
            
            context.delete(action)
        }
        
        try? context.save()
    }
}

// MARK: - ActionRowView
struct ActionRowView: View {
    @Bindable var action: RapportAction
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 활성화 토글
            Toggle("", isOn: $action.isActive)
                .labelsHidden()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(action.title)
                        .font(.headline)
                    
                    Spacer()
                    
                    // 타입 뱃지
                    Text(action.type.emoji)
                        .font(.caption2)
                }
                
                if !action.actionDescription.isEmpty {
                    Text(action.actionDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                HStack {
                    if action.isDefault {
                        Text("기본")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.blue.opacity(0.2)))
                            .foregroundStyle(.blue)
                    }
                    
                    Text(action.type.rawValue)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(action.type == .critical ? Color.orange.opacity(0.2) : Color.gray.opacity(0.2)))
                        .foregroundStyle(action.type == .critical ? .orange : .secondary)
                }
            }
        }
        .opacity(action.isActive ? 1.0 : 0.5)
    }
}

// MARK: - AddActionSheet
struct AddActionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    let phase: ActionPhase
    
    @State private var title = ""
    @State private var description = ""
    @State private var type: ActionType = .tracking
    
    var body: some View {
        NavigationStack {
            Form {
                Section("액션 정보") {
                    TextField("제목", text: $title)
                    TextField("설명 (선택)", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("설정") {
                    Picker("Phase", selection: .constant(phase)) {
                        Text("\(phase.emoji) \(phase.rawValue)")
                    }
                    .disabled(true)
                    
                    Picker("타입", selection: $type) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.emoji)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    Text(type.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("새 액션 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addAction()
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addAction() {
        // 현재 Phase의 마지막 order 찾기
        let descriptor = FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.phase == phase }
        )
        
        let existingActions = (try? context.fetch(descriptor)) ?? []
        let maxOrder = existingActions.map { $0.order }.max() ?? 0
        
        let newAction = RapportAction(
            title: title,
            actionDescription: description,
            phase: phase,
            type: type,
            order: maxOrder + 1,
            isDefault: false,
            isActive: true
        )
        
        context.insert(newAction)
        try? context.save()
    }
}

// MARK: - ActionDetailView
struct ActionDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var action: RapportAction
    
    @State private var isEditing = false
    @State private var showDeleteConfirm = false
    
    var body: some View {
        Form {
            Section("기본 정보") {
                if isEditing {
                    TextField("제목", text: $action.title)
                    TextField("설명", text: $action.actionDescription, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    LabeledContent("제목", value: action.title)
                    if !action.actionDescription.isEmpty {
                        LabeledContent("설명", value: action.actionDescription)
                    }
                }
            }
            
            Section("설정") {
                LabeledContent("Phase") {
                    Text("\(action.phase.emoji) \(action.phase.rawValue)")
                }
                
                if isEditing {
                    Picker("타입", selection: $action.type) {
                        ForEach(ActionType.allCases, id: \.self) { type in
                            HStack {
                                Text(type.emoji)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                } else {
                    LabeledContent("타입") {
                        HStack {
                            Text(action.type.emoji)
                            Text(action.type.rawValue)
                        }
                    }
                }
                
                Toggle("활성화", isOn: $action.isActive)
            }
            
            Section {
                LabeledContent("기본 액션", value: action.isDefault ? "예" : "아니오")
                LabeledContent("순서", value: String(action.order))
            } footer: {
                if action.isDefault {
                    Text("기본 액션은 삭제할 수 없습니다")
                        .foregroundStyle(.secondary)
                }
            }
            
            if !action.isDefault {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Text("액션 삭제")
                    }
                }
            }
        }
        .navigationTitle(action.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "완료" : "편집") {
                    isEditing.toggle()
                    if !isEditing {
                        try? context.save()
                    }
                }
            }
        }
        .confirmationDialog("정말 삭제할까요?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("삭제", role: .destructive) {
                context.delete(action)
                try? context.save()
                dismiss()
            }
            Button("취소", role: .cancel) {}
        }
    }
}

#Preview {
    ActionManagementView()
        .modelContainer(for: [RapportAction.self])
}
