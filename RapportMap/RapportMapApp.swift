//
//  RapportMapApp.swift
//  RapportMap
//
//  탐험과 발견 - 관계 지도 앱
//

import SwiftUI
import SwiftData

@main
struct RapportMapApp: App {
    
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
            print("✅ [App] ModelContainer 생성 성공")

            if let url = container.configurations.first?.url {
                print("📁 [App] 데이터베이스 경로: \(url.path)")
            }

            return container
        } catch {
            print("❌ [App] ModelContainer 생성 실패: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(RapportMapApp.sharedModelContainer)
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - 메인 콘텐츠 뷰

struct ContentView: View {
    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            iPadMainView()
        } else {
            PeopleListView()
        }
        #else
        MacMainView()
        #endif
    }
}

// MARK: - iPad 메인 뷰

struct iPadMainView: View {
    @State private var selectedPerson: Person?
    
    var body: some View {
        NavigationSplitView {
            PeopleListSidebar(selectedPerson: $selectedPerson)
        } detail: {
            if let person = selectedPerson {
                PersonDetailView(person: person)
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

// MARK: - iPad 사이드바

struct PeopleListSidebar: View {
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
                PersonRow(person: person)
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
            AddPersonSheet()
        }
    }
    
    private func deletePeople(at offsets: IndexSet) {
        for index in offsets {
            context.delete(filteredPeople[index])
        }
        try? context.save()
    }
}

// MARK: - macOS 메인 뷰

#if os(macOS)
struct MacMainView: View {
    @State private var selectedPerson: Person?
    
    var body: some View {
        NavigationSplitView {
            PeopleListSidebar(selectedPerson: $selectedPerson)
                .frame(minWidth: 250)
        } detail: {
            if let person = selectedPerson {
                PersonDetailView(person: person)
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

struct SettingsView: View {
    var body: some View {
        Form {
            Text("RapportMap 설정")
        }
        .padding()
        .frame(width: 400, height: 200)
    }
}
#endif
