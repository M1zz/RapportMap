//
//  RapportMapApp.swift
//  RapportMap
//
//  Created by hyunho lee on 11/2/25.
//

import SwiftUI
import SwiftData
import AppIntents

@main
struct RapportMapApp: App {
    var body: some Scene {
        WindowGroup {
            AppRootView()
        }
        .modelContainer(for: [Person.self, RapportEvent.self, RapportAction.self, PersonAction.self, MeetingRecord.self])
    }
}

// 앱의 루트 뷰 - 상태 복원 로직 담당
struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @State private var appStateManager = AppStateManager.shared
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if isLoading {
                // 로딩 화면
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("앱을 준비하는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
            } else if appStateManager.shouldShowPersonDetail,
                      let selectedPerson = appStateManager.selectedPerson {
                // PersonDetailView를 직접 표시
                NavigationStack {
                    PersonDetailView(person: selectedPerson)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("목록으로") {
                                    appStateManager.clearSelection()
                                }
                            }
                        }
                        .onDisappear {
                            // PersonDetailView가 사라질 때는 상태 유지 (다른 뷰로 이동한 경우)
                            // 실제 앱 종료나 홈으로 갔을 때만 상태가 복원됨
                        }
                }
            } else {
                // 기본 PeopleListView
                PeopleListView()
            }
        }
        .onAppear {
            loadAppState()
        }
    }
    
    private func loadAppState() {
        Task { @MainActor in
            // ActionType 마이그레이션 수행 (한번만)
            DataSeeder.migrateKoreanActionTypes(context: context)
            
            // 기본 액션이 없으면 생성
            DataSeeder.seedDefaultActionsIfNeeded(context: context)
            
            // 선택된 Person이 있는지 확인하고 찾기
            if let person = appStateManager.findSelectedPerson(in: context) {
                print("✅ 이전 상태 복원: \(person.name)님의 PersonDetailView")
            } else {
                print("📱 새로운 시작: PeopleListView")
            }
            
            isLoading = false
        }
    }
}

