//
//  RapportMapApp.swift
//  RapportMap
//
//  Created by hyunho lee on 11/2/25.
//

import SwiftUI
import SwiftData

@main
struct RapportMapApp: App {
    var body: some Scene {
        WindowGroup {
            PeopleListView()
        }
        .modelContainer(for: [Person.self])
    }
}

