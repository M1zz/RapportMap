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
    // 하위 호환성을 위해 기존 데이터베이스 경로 유지
    private static let sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            RapportEvent.self,
            RapportAction.self,
            PersonAction.self,
            MeetingRecord.self,
            PersonContext.self,
            InteractionRecord.self,
            ConversationRecord.self,
            NotificationHistory.self,
            QuickMemoArchive.self,
            AttachmentFile.self
        ])

        // CloudKit 통합 비활성화, 기본 경로 사용
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // CloudKit 통합 비활성화
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [App] ModelContainer 생성 성공 (CloudKit 비활성화)")

            // 데이터베이스 경로 출력
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
            AppRootView()
        }
        .modelContainer(RapportMapApp.sharedModelContainer)
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
                        }
                }
                
            case .showingPeopleList:
                // iPad와 iPhone 모두 PeopleListView 표시
                if UIDevice.current.userInterfaceIdiom == .pad {
                    iPadMainView()
                } else {
                    PeopleListView()
                }
            }
        }
        .onAppear {
            loadAppState()
        }
    }
    
    private func loadAppState() {
        Task { @MainActor in
            // 데이터 로드 진단
            print("\n========================================")
            print("🔍 [App] 앱 시작 - 데이터 로드 시작")

            do {
                let descriptor = FetchDescriptor<Person>()
                let people = try context.fetch(descriptor)
                print("👥 [App] 로드된 Person 수: \(people.count)")
                if !people.isEmpty {
                    print("   첫 번째: \(people[0].name)")
                }
            } catch {
                print("❌ [App] Person 로드 실패: \(error)")
            }
            print("========================================\n")

            // 1. ActionType 마이그레이션 수행 (한번만)
            DataSeeder.migrateKoreanActionTypes(context: context)

            // 2. 기본 액션이 없으면 생성
            DataSeeder.seedDefaultActionsIfNeeded(context: context)

            // 3. PersonContext 마이그레이션 (한번만) - 새로 추가!
            DataSeeder.migratePersonStringFieldsToContexts(context: context)

            // 4. 전달된 알림을 히스토리에 동기화
            await NotificationHistoryManager.shared.syncDeliveredNotifications(context: context)

            // 5. 30일 이상 된 오래된 알림 히스토리 정리
            NotificationHistoryManager.shared.cleanupOldNotifications(context: context)

            // 6. 선택된 Person이 있는지 확인하고 찾기
            if let person = appStateManager.findSelectedPerson(in: context) {
                print("✅ 이전 상태 복원: \(person.name)님의 PersonDetailView")
            } else {
                print("📱 새로운 시작: PeopleListView")
            }

            isLoading = false
        }
    }
}

