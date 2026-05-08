//
//  PersonSnapshot.swift
//  RapportMap
//
//  특정 시점의 사람 상태 스냅샷 (면접, 첫 만남 등)
//

import Foundation
import SwiftData

@Model
final class PersonSnapshot {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""            // 예: "1차 면접", "2025년 초"
    var occupation: String = ""       // 직업/직무
    var organization: String = ""     // 소속 (회사/학교)
    var careerYears: Int = 0          // 경력 연수
    var currentConcerns: String = ""  // 당시 고민
    var goals: String = ""            // 당시 목표/방향
    var strengths: String = ""        // 강점으로 보인 것
    var freeNote: String = ""         // 전반적인 인상/메모

    @Relationship(deleteRule: .nullify)
    var person: Person?

    init(
        title: String = "",
        date: Date = Date(),
        occupation: String = "",
        organization: String = "",
        careerYears: Int = 0,
        currentConcerns: String = "",
        goals: String = "",
        strengths: String = "",
        freeNote: String = ""
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.occupation = occupation
        self.organization = organization
        self.careerYears = careerYears
        self.currentConcerns = currentConcerns
        self.goals = goals
        self.strengths = strengths
        self.freeNote = freeNote
    }
}
