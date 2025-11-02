//
//  AddRapportIntent.swift
//  RapportMapIntents
//
//  Created by hyunho lee on 2025/11/04.
//

import AppIntents

// MARK: - 라포 이벤트 추가 Intent
@available(iOS 18.0, *)
struct AddRapportIntent: AppIntent {
    static var title: LocalizedStringResource = "라포 이벤트 추가"
    static var description = IntentDescription("특정 사람과의 멘토링, 식사, 메시지 이벤트를 기록합니다.")

    // 사용자 입력 파라미터
    @Parameter(title: "사람 이름")
    var personName: String

    @Parameter(title: "이벤트 종류", default: .mentoring)
    var kind: RapportKind

    static var parameterSummary: some ParameterSummary {
        Summary("라포맵에 \(\.$personName)과(와) \(\.$kind) 했어")
    }

    // 실행 로직
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // ⚠️ SwiftData 연동은 나중 단계 (App Group 필요)
        // 지금은 단순히 텍스트 리턴
        return .result(value: "‘\(personName)’과(와) \(kind.rawValue) 이벤트를 기록했어요!")
    }
}
