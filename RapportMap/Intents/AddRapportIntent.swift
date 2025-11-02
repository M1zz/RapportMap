//
//  AddRapportIntent.swift
//  RapportMap
//
//  Created by hyunho lee on 2025/11/03.
//

import AppIntents
import SwiftData

// MARK: - Intent 정의
@available(iOS 18.0, *)
struct AddRapportIntent: AppIntent {

    static var title: LocalizedStringResource = "라포 이벤트 추가"
    static var description = IntentDescription("특정 사람과의 멘토링, 식사, 메시지 이벤트를 기록합니다.")

    // 사용자 입력 파라미터
    @Parameter(title: "이름")
    var personName: String

    @Parameter(title: "이벤트 종류", default: .mentoring)
    var kind: RapportKind

    static var parameterSummary: some ParameterSummary {
        Summary("라포맵에 \(\.$personName)과(와) \(\.$kind) 기록하기")
    }

    // 실행 로직
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        // ⚠️ Intent Extension 내부에서는 SwiftData 직접 접근 불가
        // → App Groups or AppEntity 연동 필요 (지금은 임시 리턴)
        return .result(value: "‘\(personName)’에게 \(kind.rawValue) 이벤트를 기록했어요 (앱에서 반영됨).")
    }
}

// MARK: - 이벤트 종류 Enum
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

// MARK: - 단축어(Shortcut) 등록
@available(iOS 18.0, *)
struct RapportShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        [AppShortcut(
            intent: AddRapportIntent(),
            phrases: [
                // ⚙️ 최소 구성: 반드시 빌드되는 버전
                "라포맵 테스트"
                // 이후 정상 등록되면 다음과 같은 문장으로 확장 가능:
                // "라포맵에 \(.parameter(\\AddRapportIntent.$personName))과(와) \(.parameter(\\AddRapportIntent.$kind)) 했어"
            ],
            shortTitle: "라포 이벤트 추가",
            systemImageName: "person.crop.circle.badge.plus"
        )]
    }
}
