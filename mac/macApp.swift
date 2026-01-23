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

        WindowGroup(id: "interaction-creation") {
            InteractionCreationWindowView()
        }
        .modelContainer(macApp.sharedModelContainer)
        .defaultSize(width: 600, height: 700)
    }
}

// 상호작용 기록 생성 윈도우를 위한 환경 객체
@Observable
class InteractionCreationState {
    static let shared = InteractionCreationState()
    var person: Person?
    var interactionType: InteractionType?
}

struct InteractionCreationWindowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var state = InteractionCreationState.shared

    var body: some View {
        Group {
            if let person = state.person, let type = state.interactionType {
                MacCreateInteractionSheet(
                    person: person,
                    interactionType: type,
                    context: context
                )
            } else {
                VStack {
                    Text("상호작용 정보가 없습니다")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
