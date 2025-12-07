//
//  macApp.swift
//  mac
//
//  Created by Leeo on 12/4/25.
//

import SwiftUI
import SwiftData

@main
struct macApp: App {
    // macOS용 ModelContainer (CloudKit 비활성화)
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
            QuickMemoArchive.self
        ])

        // CloudKit 통합 비활성화, 기본 경로 사용
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // CloudKit 통합 비활성화
        )

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            print("✅ [macOS] ModelContainer 생성 성공")

            // 데이터베이스 경로 출력
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
            ContentView()
        }
        .modelContainer(macApp.sharedModelContainer)
    }
}
