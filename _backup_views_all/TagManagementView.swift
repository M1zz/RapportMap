//
//  TagManagementView.swift
//  RapportMap
//
//  Created by hyunho lee on 2/19/26.
//
//  태그 관리 화면 - 태그 목록, 추가, 수정, 삭제
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PersonTag.order) private var tags: [PersonTag]
    
    @State private var showingAddTag = false
    @State private var editingTag: PersonTag? = nil
    @State private var selectedCategory: TagCategory? = nil
    
    // 카테고리별로 그룹화된 태그들
    private var groupedTags: [TagCategory: [PersonTag]] {
        Dictionary(grouping: filteredTags, by: { $0.category })
    }
    
    private var filteredTags: [PersonTag] {
        if let category = selectedCategory {
            return tags.filter { $0.category == category }
        }
        return tags
    }
    
    var body: some View {
        NavigationStack {
            List {
                // 카테고리 필터
                categoryFilterSection
                
                // 태그 목록
                if selectedCategory != nil {
                    // 선택된 카테고리의 태그만 표시
                    tagsSection(for: filteredTags, title: selectedCategory?.rawValue ?? "태그")
                } else {
                    // 카테고리별로 그룹화하여 표시
                    ForEach(TagCategory.allCases) { category in
                        if let categoryTags = groupedTags[category], !categoryTags.isEmpty {
                            tagsSection(for: categoryTags, title: "\(category.emoji) \(category.rawValue)")
                        }
                    }
                }
            }
            .navigationTitle("태그 관리")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddTag = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddTag) {
                TagEditSheet(tag: nil)
            }
            .sheet(item: $editingTag) { tag in
                TagEditSheet(tag: tag)
            }
            .onAppear {
                // 기본 태그가 없으면 생성
                DataSeeder.seedDefaultTagsIfNeeded(context: context)
            }
        }
    }
    
    // MARK: - View Components
    
    private var categoryFilterSection: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // 전체 보기 버튼
                    Button {
                        selectedCategory = nil
                    } label: {
                        Text("전체")
                            .font(.subheadline)
                            .fontWeight(selectedCategory == nil ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == nil ? Color.blue : Color.secondary.opacity(0.2))
                            )
                            .foregroundStyle(selectedCategory == nil ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(TagCategory.allCases) { category in
                        let count = tags.filter { $0.category == category }.count
                        Button {
                            selectedCategory = category
                        } label: {
                            HStack(spacing: 4) {
                                Text(category.emoji)
                                Text(category.rawValue)
                                if count > 0 {
                                    Text("(\(count))")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(selectedCategory == category ? .semibold : .regular)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(selectedCategory == category ? Color.blue : Color.secondary.opacity(0.2))
                            )
                            .foregroundStyle(selectedCategory == category ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
    }
    
    private func tagsSection(for tagsList: [PersonTag], title: String) -> some View {
        Section(header: Text(title)) {
            ForEach(tagsList.sorted { $0.order < $1.order }) { tag in
                tagRow(for: tag)
            }
            .onDelete { indexSet in
                deleteTag(at: indexSet, from: tagsList)
            }
        }
    }
    
    private func tagRow(for tag: PersonTag) -> some View {
        Button {
            editingTag = tag
        } label: {
            HStack(spacing: 12) {
                // 태그 색상 표시
                Circle()
                    .fill(tag.swiftUIColor)
                    .frame(width: 24, height: 24)
                    .overlay {
                        if let icon = tag.icon {
                            Image(systemName: icon)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(tag.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text("\(tag.people.count)명")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 카테고리 뱃지
                Text(tag.category.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                    )
                    .foregroundStyle(.secondary)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Actions
    
    private func deleteTag(at offsets: IndexSet, from tagsList: [PersonTag]) {
        let sortedTags = tagsList.sorted { $0.order < $1.order }
        for index in offsets {
            let tag = sortedTags[index]
            context.delete(tag)
        }
        
        do {
            try context.save()
            print("✅ 태그 삭제 완료")
        } catch {
            print("❌ 태그 삭제 실패: \(error)")
        }
    }
}

// MARK: - Tag Edit Sheet

struct TagEditSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    let tag: PersonTag?
    
    @State private var name: String = ""
    @State private var selectedColor: String = "#007AFF"
    @State private var selectedIcon: String? = nil
    @State private var selectedCategory: TagCategory = .custom
    
    private var isEditing: Bool { tag != nil }
    
    var body: some View {
        NavigationStack {
            Form {
                // 이름 입력
                Section("태그 이름") {
                    TextField("태그 이름", text: $name)
                }
                
                // 카테고리 선택
                Section("카테고리") {
                    Picker("카테고리", selection: $selectedCategory) {
                        ForEach(TagCategory.allCases) { category in
                            HStack {
                                Text(category.emoji)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text(selectedCategory.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 색상 선택
                Section("색상") {
                    colorPicker
                }
                
                // 아이콘 선택
                Section("아이콘 (선택사항)") {
                    iconPicker
                }
                
                // 미리보기
                Section("미리보기") {
                    HStack {
                        Spacer()
                        previewBadge
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle(isEditing ? "태그 수정" : "새 태그")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "저장" : "추가") {
                        saveTag()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let tag = tag {
                    name = tag.name
                    selectedColor = tag.color
                    selectedIcon = tag.icon
                    selectedCategory = tag.category
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var colorPicker: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(PersonTag.presetColors, id: \.hex) { preset in
                Button {
                    selectedColor = preset.hex
                } label: {
                    Circle()
                        .fill(Color(hex: preset.hex) ?? .blue)
                        .frame(width: 36, height: 36)
                        .overlay {
                            if selectedColor == preset.hex {
                                Image(systemName: "checkmark")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 아이콘 없음 옵션
            Button {
                selectedIcon = nil
            } label: {
                HStack {
                    Text("아이콘 없음")
                    Spacer()
                    if selectedIcon == nil {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Divider()
            
            // 아이콘 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                ForEach(PersonTag.presetIcons, id: \.self) { icon in
                    Button {
                        selectedIcon = icon
                    } label: {
                        Image(systemName: icon)
                            .font(.title3)
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIcon == icon ? Color.blue.opacity(0.2) : Color.secondary.opacity(0.1))
                            )
                            .foregroundStyle(selectedIcon == icon ? .blue : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var previewBadge: some View {
        HStack(spacing: 6) {
            if let icon = selectedIcon {
                Image(systemName: icon)
                    .font(.caption)
            }
            Text(name.isEmpty ? "태그 이름" : name)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill((Color(hex: selectedColor) ?? .blue).opacity(0.2))
        )
        .overlay(
            Capsule()
                .strokeBorder((Color(hex: selectedColor) ?? .blue).opacity(0.5), lineWidth: 1)
        )
        .foregroundStyle(Color(hex: selectedColor) ?? .blue)
    }
    
    // MARK: - Actions
    
    private func saveTag() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        
        if let existingTag = tag {
            // 기존 태그 수정
            existingTag.name = trimmedName
            existingTag.color = selectedColor
            existingTag.icon = selectedIcon
            existingTag.category = selectedCategory
        } else {
            // 새 태그 생성
            let maxOrder = (try? context.fetch(FetchDescriptor<PersonTag>()))?.map { $0.order }.max() ?? 0
            let newTag = PersonTag(
                name: trimmedName,
                color: selectedColor,
                icon: selectedIcon,
                order: maxOrder + 1,
                category: selectedCategory
            )
            context.insert(newTag)
        }
        
        do {
            try context.save()
            print("✅ 태그 저장 완료: \(trimmedName)")
            dismiss()
        } catch {
            print("❌ 태그 저장 실패: \(error)")
        }
    }
}

// MARK: - Person Tag Selection View

/// PersonDetailView에서 사용할 태그 선택 뷰
struct PersonTagSelectionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \PersonTag.order) private var allTags: [PersonTag]
    
    @Bindable var person: Person
    @State private var selectedTagIDs: Set<UUID> = []
    
    // 카테고리별로 그룹화된 태그들
    private var groupedTags: [TagCategory: [PersonTag]] {
        Dictionary(grouping: allTags, by: { $0.category })
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(TagCategory.allCases) { category in
                    if let categoryTags = groupedTags[category], !categoryTags.isEmpty {
                        Section("\(category.emoji) \(category.rawValue)") {
                            ForEach(categoryTags.sorted { $0.order < $1.order }) { tag in
                                tagSelectionRow(for: tag)
                            }
                        }
                    }
                }
            }
            .navigationTitle("태그 선택")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("취소") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        saveSelection()
                    }
                }
            }
            .onAppear {
                // 기존 선택된 태그들 로드
                selectedTagIDs = Set(person.tags.map { $0.id })
                
                // 기본 태그가 없으면 생성
                DataSeeder.seedDefaultTagsIfNeeded(context: context)
            }
        }
    }
    
    private func tagSelectionRow(for tag: PersonTag) -> some View {
        Button {
            toggleTag(tag)
        } label: {
            HStack(spacing: 12) {
                // 태그 색상 및 아이콘
                Circle()
                    .fill(tag.swiftUIColor)
                    .frame(width: 28, height: 28)
                    .overlay {
                        if let icon = tag.icon {
                            Image(systemName: icon)
                                .font(.caption2)
                                .foregroundStyle(.white)
                        }
                    }
                
                Text(tag.name)
                    .foregroundStyle(.primary)
                
                Spacer()
                
                // 선택 상태
                if selectedTagIDs.contains(tag.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func toggleTag(_ tag: PersonTag) {
        if selectedTagIDs.contains(tag.id) {
            selectedTagIDs.remove(tag.id)
        } else {
            selectedTagIDs.insert(tag.id)
        }
    }
    
    private func saveSelection() {
        // 선택된 태그들로 업데이트
        let selectedTags = allTags.filter { selectedTagIDs.contains($0.id) }
        person.tags = selectedTags
        
        do {
            try context.save()
            print("✅ \(person.name)님의 태그 업데이트 완료: \(selectedTags.map { $0.name })")
            dismiss()
        } catch {
            print("❌ 태그 저장 실패: \(error)")
        }
    }
}

// MARK: - Preview

#Preview {
    TagManagementView()
}
