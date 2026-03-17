//
//  PersonNote.swift
//  RapportMap
//
//  이 사람에 대해 알게 된 메모 (자유 형식, 날짜 자동 기록)
//

import Foundation
import SwiftData

@Model
final class PersonNote {
    var id: UUID = UUID()
    var date: Date = Date()
    var content: String = ""

    @Relationship(deleteRule: .nullify)
    var person: Person?

    init(content: String = "", date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.content = content
    }
}
