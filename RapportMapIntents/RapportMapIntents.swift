//
//  RapportMapIntents.swift
//  RapportMapIntents
//
//  Created by hyunho lee on 11/3/25.
//

import AppIntents

struct RapportMapIntents: AppIntent {
    static var title: LocalizedStringResource { "RapportMapIntents" }
    
    func perform() async throws -> some IntentResult {
        return .result()
    }
}
