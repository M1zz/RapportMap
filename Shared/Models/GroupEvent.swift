//
//  GroupEvent.swift
//  RapportMap
//
//  여러 사람이 함께한 이벤트 기록
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class GroupEvent {
    var id: UUID = UUID()
    var title: String = ""
    var typeRawValue: String = ActivityType.travel.rawValue
    var date: Date = Date()
    var endDate: Date?
    var notes: String = ""

    @Relationship(deleteRule: .nullify, inverse: \Person.groupEvents)
    var participants: [Person]?

    var type: ActivityType {
        get { ActivityType(rawValue: typeRawValue) ?? .other }
        set { typeRawValue = newValue.rawValue }
    }

    init(
        title: String = "",
        type: ActivityType = .travel,
        date: Date = Date(),
        endDate: Date? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.typeRawValue = type.rawValue
        self.date = date
        self.endDate = endDate
        self.notes = notes
    }
}
