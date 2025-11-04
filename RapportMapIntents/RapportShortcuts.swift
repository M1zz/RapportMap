//
//  RapportShortcuts.swift
//  RapportMapIntents
//
//  Created by hyunho lee on 2025/11/04.
//

import AppIntents

@available(iOS 18.0, *)
struct RapportShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddRapportIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Show me \(.applicationName)"
            ],
            shortTitle: "라포 이벤트 추가",
            systemImageName: "person.crop.circle.badge.plus"
        )
    }
}

