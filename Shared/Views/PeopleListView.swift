//
//  PeopleListView.swift
//  RapportMap
//
//  사람 목록 뷰 - 탐험 컨셉
//

import SwiftUI
import SwiftData

struct PeopleListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    
    @State private var searchText = ""
    @State private var showingAddPerson = false
    @State private var selectedPerson: Person?
    @State private var personToDelete: Person?
    @State private var showingDeleteConfirmation = false
    
    private var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if people.isEmpty {
                    emptyState
                } else {
                    peopleList
                }
            }
            .navigationTitle("관계 지도")
            .searchable(text: $searchText, prompt: "이름 검색")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingAddPerson = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddPerson) {
                AddPersonSheet()
            }
            .navigationDestination(item: $selectedPerson) { person in
                PersonDetailView(person: person)
            }
            .confirmationDialog(
                "\(personToDelete?.name ?? "")을(를) 삭제할까요?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("삭제", role: .destructive) {
                    if let person = personToDelete {
                        context.delete(person)
                        try? context.save()
                    }
                    personToDelete = nil
                }
                Button("취소", role: .cancel) { personToDelete = nil }
            } message: {
                Text("이 사람의 모든 발견, 메모, 기록이 함께 삭제됩니다.")
            }
        }
    }
    
    // MARK: - 빈 상태
    
    private var emptyState: some View {
        ContentUnavailableView {
            Label("아직 아무도 없어요", systemImage: "map")
        } description: {
            Text("탐험할 관계를 추가해보세요")
        } actions: {
            Button {
                showingAddPerson = true
            } label: {
                Label("첫 번째 사람 추가", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - 목록
    
    private var peopleList: some View {
        List {
            ForEach(filteredPeople) { person in
                PersonRow(person: person)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPerson = person
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            personToDelete = person
                            showingDeleteConfirmation = true
                        } label: {
                            Label("삭제", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }
}

// MARK: - 사람 행

struct PersonRow: View {
    let person: Person
    @State private var showingFullScreenPhoto = false

    var body: some View {
        HStack(spacing: 16) {
            // 프로필 + 달
            ZStack(alignment: .bottomTrailing) {
                Button {
                    if person.profileImageData != nil { showingFullScreenPhoto = true }
                } label: {
                    profileImage
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showingFullScreenPhoto) {
                    FullScreenPhotoView(imageData: person.profileImageData, isPresented: $showingFullScreenPhoto)
                }

                Text(person.progressMoonPhase)
                    .font(.system(size: 14))
                    .offset(x: 4, y: 4)
            }
            
            // 정보
            VStack(alignment: .leading, spacing: 6) {
                Text(person.name)
                    .font(.headline)
                
                // 진행률 바
                HStack(spacing: 8) {
                    ProgressView(value: person.totalExplorationProgress)
                        .tint(person.depth.color)
                        .frame(width: 100)
                    
                    Text("\(Int(person.totalExplorationProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 요약
                Text("\(person.exploredTerritories.count)개 영역 탐험 • \(person.depth.title)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 미탐험 알림
            if !person.unexploredTerritories.isEmpty {
                VStack {
                    Text("\(person.unexploredTerritories.count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(person.depth.color)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var profileImage: some View {
        Group {
            if let imageData = person.profileImageData {
                #if os(iOS)
                if let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                }
                #else
                if let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                }
                #endif
            } else {
                Image(systemName: "person.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 50, height: 50)
        .background(Color.secondaryBackground)
        .clipShape(Circle())
    }
}

// MARK: - 사람 추가 시트

struct AddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var name = ""
    @State private var contact = ""
    @State private var memo = ""
    
    @FocusState private var isNameFocused: Bool
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("이름", text: $name)
                        .focused($isNameFocused)
                    
                    TextField("연락처 (선택)", text: $contact)
                }
                
                Section("메모 (선택)") {
                    TextField("이 사람에 대한 간단한 메모", text: $memo, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("새로운 관계")
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
                    Button("추가") {
                        addPerson()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                isNameFocused = true
            }
        }
        #if os(macOS)
        .frame(width: 400, height: 300)
        #endif
    }
    
    private func addPerson() {
        let person = Person(
            name: name,
            contact: contact,
            memo: memo.isEmpty ? nil : memo
        )
        context.insert(person)
        try? context.save()
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)
    
    // 샘플 데이터
    let person1 = Person(name: "김철수")
    let person2 = Person(name: "이영희", depth: .personal)
    let person3 = Person(name: "박지훈", depth: .deep)
    
    container.mainContext.insert(person1)
    container.mainContext.insert(person2)
    container.mainContext.insert(person3)
    
    person1.addDiscovery(territory: .nickname, content: "테스트")
    person1.addDiscovery(territory: .hobby, content: "테스트")
    
    person2.addDiscovery(territory: .nickname, content: "테스트")
    person2.addDiscovery(territory: .currentConcern, content: "테스트")
    
    return PeopleListView()
        .modelContainer(container)
}
