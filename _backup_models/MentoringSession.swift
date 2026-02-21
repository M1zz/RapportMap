import Foundation
import SwiftUI

/// 멘토링 철학 메시지
struct MentoringPhilosophy {
    static let message = """
    📊 변화 추이의 중요성

    지금 현재 수준이 높고 낮음도 중요하지만, 더욱 중요한 것은 변화 추이입니다.

    변화의 그래프가 가파르지 않다면, 제자리 걸음을 걸을 확률이 높습니다.
    그래서 그 변화 추이를 기록하고자 합니다.

    ✏️ 솔직한 기록의 중요성

    자신의 변화를 위해서 자신이 기록해주세요.
    대화의 흐름이 끊겨도 괜찮습니다.
    녹음, 녹화를 해도 괜찮습니다. (유포가 괜찮다는 뜻과는 다릅니다 :))

    🎯 멘토의 역할

    저는 목표를 같이 설정하고 그 목표 달성을 위해서 노력하고
    변화를 같이 확인하려고 합니다.

    자신을 위해서 솔직하게 작성해주세요!
    """

    static let shortMessage = "변화의 그래프가 가파르지 않다면, 제자리 걸음을 걸을 확률이 높습니다. 솔직하게 기록해주세요!"
}

// 최초 1회 작성하는 기본 정보 (언제든 다시 확인 및 수정 가능)
struct MentoringProfile: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var background: String = "" // 멘토가 알았으면 하는 자신의 배경
    var academyGoal: String = "" // 아카데미에 나갈 때의 자신의 목표
    var learningPlan: String = "" // 아카데미에서 배우고 싶은 것들
    var currentEfforts: String = "" // 목표를 달성하기 위해서 지금 하고있는 노력들
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    var isComplete: Bool {
        !background.isEmpty && !academyGoal.isEmpty
    }
}

// 매 세션마다 작성하는 멘토링 폼
struct MentoringSession: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var sessionDate: Date = Date()
    var eventId: String? // 연결된 이벤트 ID
    var personId: UUID? // 연결된 Person ID

    // 멘토링 전
    var preMentoring: PreMentoringForm = PreMentoringForm()

    // 멘토링 후
    var postMentoring: PostMentoringForm = PostMentoringForm()

    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

struct PreMentoringForm: Codable, Hashable {
    var attemptsSinceLastTime: String = "" // 지난번 이후에 어떤 시도들을 했는지
    var changesSinceLastTime: String = "" // 지난번 이후에 어떤 변화가 있었는지
    var expectedChanges: String = "" // 이번에 어떤 변화가 생기기를 기대하는지

    // 만족도 평가 (1-10)
    var personalLifeSatisfaction: Int = 5 // 개인적인 삶의 만족도
    var relationshipSatisfaction: Int = 5 // 지인, 가족과의 관계에서의 만족도
    var academySatisfaction: Int = 5 // 아카데미, 사회에서의 만족도
    var overallLifeSatisfaction: Int = 5 // 전반적인 나의 삶
}

struct PostMentoringForm: Codable, Hashable {
    var conversationCompleteness: Int = 5 // 오늘 리이오와 나누고자 했던 이야기를 얼마나 나누었나요?
    var listeningQuality: Int = 5 // 리이오가 나의 이야기를 얼마나 들어주었나요?
    var helpfulness: Int = 5 // 리이오와의 대화는 나에게 있어서 얼마나 도움이 되었나요?
    var overallEvaluation: Int = 5 // 전반적으로 멘토링을 평가한다면 어땠나요?

    var importantThings: String = "" // 이번 멘토링에 나에게 중요했던 것들
    var meaningfulSummary: String = "" // 나에게 의미있었던 것을 한 문장으로 정리
    var actionPlan: String = "" // 이후의 액션플랜
}
