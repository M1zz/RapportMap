//
//  RapportEvent.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation
import SwiftData

@Model
final class RapportEvent: Identifiable {
    var id: UUID
    var date: Date
    var note: String
    var kind: String

    init(id: UUID = UUID(), date: Date = .now, note: String = "", kind: String = "기타") {
        self.id = id
        self.date = date
        self.note = note
        self.kind = kind
    }
}
