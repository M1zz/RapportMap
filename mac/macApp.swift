//
//  macApp.swift
//  mac
//
//  탐험과 발견 - 관계 지도 앱 (macOS)
//

import SwiftUI
import SwiftData

@main
struct macApp: App {
    
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            Discovery.self,
            PersonTag.self
        ])

        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [macOS] ModelContainer 생성 성공")

            if let url = container.configurations.first?.url {
                print("📁 [macOS] 데이터베이스 경로: \(url.path)")
            }

            return container
        } catch {
            print("❌ [macOS] ModelContainer 생성 실패: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MacContentView()
        }
        .modelContainer(macApp.sharedModelContainer)
        
        Settings {
            MacSettingsView()
        }
    }
}

// MARK: - macOS 메인 콘텐츠 뷰

struct MacContentView: View {
    @State private var selectedPerson: Person?
    
    var body: some View {
        NavigationSplitView {
            MacPeopleListSidebar(selectedPerson: $selectedPerson)
                .frame(minWidth: 250)
        } detail: {
            if let person = selectedPerson {
                MacPersonDetailView(person: person)
            } else {
                ContentUnavailableView {
                    Label("사람을 선택하세요", systemImage: "person.crop.circle")
                } description: {
                    Text("왼쪽에서 탐험할 관계를 선택해주세요")
                }
            }
        }
    }
}

// MARK: - macOS 사람 목록 사이드바

struct MacPeopleListSidebar: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var people: [Person]
    @Binding var selectedPerson: Person?
    
    @State private var searchText = ""
    @State private var showingAddPerson = false
    
    private var filteredPeople: [Person] {
        if searchText.isEmpty {
            return people
        }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        List(selection: $selectedPerson) {
            ForEach(filteredPeople) { person in
                MacPersonRow(person: person)
                    .tag(person)
            }
            .onDelete(perform: deletePeople)
        }
        .navigationTitle("관계 지도")
        .searchable(text: $searchText, prompt: "검색")
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
            MacAddPersonSheet()
        }
    }
    
    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredPeople[index])
        }
        try? context.save()
    }
}

// MARK: - macOS 사람 행

struct MacPersonRow: View {
    let person: Person
    
    var body: some View {
        HStack(spacing: 12) {
            // 달 아이콘
            Text(person.progressMoonPhase)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    ProgressView(value: person.totalExplorationProgress)
                        .frame(width: 60)
                    
                    Text("\(Int(person.totalExplorationProgress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
            
            // 미탐험 영역 수
            if !person.unexploredTerritories.isEmpty {
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
        .padding(.vertical, 4)
    }
}

// MARK: - macOS 사람 추가 시트

struct MacAddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var name = ""
    @State private var contact = ""
    @State private var memo = ""
    
    var body: some View {
        VStack(spacing: 20) {
            Text("새로운 관계")
                .font(.title2)
                .fontWeight(.bold)
            
            Form {
                TextField("이름", text: $name)
                TextField("연락처 (선택)", text: $contact)
                TextField("메모 (선택)", text: $memo, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)
            
            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                
                Spacer()
                
                Button("추가") {
                    addPerson()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 280)
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

// MARK: - macOS 사람 상세 뷰

struct MacPersonDetailView: View {
    @Bindable var person: Person
    
    @State private var selectedTab: MacDetailTab = .map
    
    var body: some View {
        VStack(spacing: 0) {
            // 탭 선택
            Picker("탭", selection: $selectedTab) {
                ForEach(MacDetailTab.allCases, id: \.self) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding()
            
            // 탭 콘텐츠
            switch selectedTab {
            case .map:
                PersonMapView(person: person)
            case .timeline:
                DiscoveryTimelineView(person: person)
            case .info:
                PersonInfoView(person: person)
            }
        }
        .navigationTitle(person.name)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                VStack(spacing: 2) {
                    Text("\(person.progressMoonPhase) \(person.depth.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

enum MacDetailTab: String, CaseIterable {
    case map
    case timeline
    case info
    
    var title: String {
        switch self {
        case .map: return "지도"
        case .timeline: return "발견들"
        case .info: return "정보"
        }
    }
}

// MARK: - macOS 설정 뷰

struct MacSettingsView: View {
    var body: some View {
        Form {
            Text("RapportMap 설정")
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
