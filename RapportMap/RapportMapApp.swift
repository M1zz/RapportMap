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
        .modelContainer(for: [
            Person.self, 
            RapportEvent.self, 
            RapportAction.self, 
            PersonAction.self, 
            MeetingRecord.self,
            PersonContext.self,  // 추가!
            InteractionRecord.self,  // 혹시 빠졌다면 추가
            ConversationRecord.self  // 대화 기록 모델 추가
        ])
    }
}

// 앱의 루트 뷰 상태 정의
enum AppRootState {
    case loading
    case restoringSession(Person)  // 이전 세션 복원
    case showingPeopleList        // 사람 목록 화면 표시
}

// 앱의 루트 뷰 - 상태 복원 로직 담당
struct AppRootView: View {
    @Environment(\.modelContext) private var context
    @State private var appStateManager = AppStateManager.shared
    @State private var isLoading = true
    @State private var selectedTab = 0  // 선택된 탭 상태 관리
    
    private var currentState: AppRootState {
        if isLoading {
            return .loading
        } else if appStateManager.shouldShowPersonDetail,
                  let selectedPerson = appStateManager.selectedPerson {
            return .restoringSession(selectedPerson)
        } else {
            return .showingPeopleList
        }
    }
    
    var body: some View {
        Group {
            switch currentState {
            case .loading:
                // 로딩 화면
                VStack {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("앱을 준비하는 중...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                
            case .restoringSession(let selectedPerson):
                // PersonDetailView를 직접 표시
                NavigationStack {
                    PersonDetailView(person: selectedPerson, selectedTab: $selectedTab)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button("목록으로") {
                                    appStateManager.clearSelection()
                                }
                            }
                            
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Picker("보기 모드", selection: $selectedTab) {
                                    Text("활동").tag(0)
                                    Text("관계").tag(1)
                                    Text("정보").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 180)
                            }
                        }
                }
                
            case .showingPeopleList:
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
            // 1. ActionType 마이그레이션 수행 (한번만)
            DataSeeder.migrateKoreanActionTypes(context: context)
            
            // 2. 기본 액션이 없으면 생성
            DataSeeder.seedDefaultActionsIfNeeded(context: context)
            
            // 3. PersonContext 마이그레이션 (한번만) - 새로 추가!
            DataSeeder.migratePersonStringFieldsToContexts(context: context)
            
            // 4. 선택된 Person이 있는지 확인하고 찾기
            if let person = appStateManager.findSelectedPerson(in: context) {
                print("✅ 이전 상태 복원: \(person.name)님의 PersonDetailView")
            } else {
                print("📱 새로운 시작: PeopleListView")
            }
            
            isLoading = false
        }
    }
}

