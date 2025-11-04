//
//  RapportKind.swift
//  RapportMapIntents
//
//  Created by hyunho lee on 2025/11/04.
//

import AppIntents

@available(iOS 18.0, *)
enum RapportKind: String, AppEnum {
    case mentoring = "멘토링"
    case meal = "식사"
    case message = "메시지"

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        "라포 이벤트 종류"
    }

    static var caseDisplayRepresentations: [RapportKind: DisplayRepresentation] {
        [
            .mentoring: "멘토링",
            .meal: "식사",
            .message: "메시지"
        ]
    }
}
