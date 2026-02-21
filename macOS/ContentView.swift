//
//  ContentView.swift
//  mac
//
//  macOS용 메인 화면 - 관계 지도 관리
//

import SwiftUI
import SwiftData

enum SidebarSelection: Hashable {
    case dashboard
    case people
}

struct ContentView: View {
    @Environment(\.modelContext) private var context
    @State private var showingSettings = false
    @State private var selectedPerson: Person?
    @State private var sidebarSelection: SidebarSelection = .dashboard

    var body: some View {
        NavigationSplitView {
            // 사이드바 - 대시보드/목록 전환
            List(selection: $sidebarSelection) {
                Section("메뉴") {
                    Label("대시보드", systemImage: "square.grid.2x2")
                        .tag(SidebarSelection.dashboard)
                    
                    Label("관계 지도", systemImage: "person.3")
                        .tag(SidebarSelection.people)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
            .navigationTitle("RapportMap")
        } content: {
            // 중간 패널 - 선택에 따라 대시보드 또는 목록
            switch sidebarSelection {
            case .dashboard:
                MacDashboardView(selectedPerson: $selectedPerson)
                    .frame(minWidth: 400)
            case .people:
                MacPeopleListView(selectedPerson: $selectedPerson)
                    .frame(minWidth: 280)
            }
        } detail: {
            // 상세 패널 - 선택된 사람 정보
            if let person = selectedPerson {
                MacPersonDetailView(person: person)
            } else {
                emptyStateView
            }
        }
        .sheet(isPresented: $showingSettings) {
            MacSettingsView()
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    showingSettings = true
                } label: {
                    Label("설정", systemImage: "gearshape")
                }
            }
        }
        .onAppear {
            initializeApp()
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)

            Text("RapportMap for macOS")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("왼쪽 목록에서 사람을 선택하거나\n새로운 사람을 추가하세요")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func initializeApp() {
        Task { @MainActor in
            // 데이터 로드 진단
            do {
                let descriptor = FetchDescriptor<Person>()
                let people = try context.fetch(descriptor)
                print("👥 [macOS] 로드된 Person 수: \(people.count)")
            } catch {
                print("❌ [macOS] Person 로드 실패: \(error)")
            }

            // 기본 액션이 없으면 생성
            DataSeeder.seedDefaultActionsIfNeeded(context: context)
            
            // 기본 태그 생성
            DataSeeder.seedDefaultTagsIfNeeded(context: context)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self])
}
