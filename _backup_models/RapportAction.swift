//
//  RapportAction.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation
import SwiftData

@Model
final class RapportAction {
    var id: UUID
    var title: String
    var actionDescription: String  // 'description'은 예약어라서 피함
    var phase: ActionPhase
    var type: ActionType
    var order: Int  // Phase 내에서의 순서
    var isDefault: Bool  // 기본 제공 액션인지 (삭제 방지)
    var isActive: Bool   // 활성화 여부 (사용자가 끌 수 있음)
    var placeholder: String  // 입력 예시 (예: "예: 아메리카노 좋아함")
    
    // 관계
    @Relationship(deleteRule: .cascade, inverse: \PersonAction.action)
    var personActions: [PersonAction] = []
    
    init(
        id: UUID = UUID(),
        title: String,
        actionDescription: String = "",
        phase: ActionPhase,
        type: ActionType,
        order: Int,
        isDefault: Bool = false,
        isActive: Bool = true,
        placeholder: String = "예: 입력하세요"
    ) {
        self.id = id
        self.title = title
        self.actionDescription = actionDescription
        self.phase = phase
        self.type = type
        self.order = order
        self.isDefault = isDefault
        self.isActive = isActive
        self.placeholder = placeholder
    }
}

// MARK: - Default Actions Factory (깊이 기반)
extension RapportAction {
    /// 관계의 깊이에 따른 30가지 기본 액션 생성
    static func createDefaultActions() -> [RapportAction] {
        var actions: [RapportAction] = []
        
        // ========================================
        // Level 1: 표면적 정보 (Surface) - 1~5
        // 겉으로 보이는 기본 정보
        // ========================================
        actions.append(RapportAction(
            title: "이름과 선호 호칭 확인",
            actionDescription: "뭐라고 부르면 편하세요?",
            phase: .surface,
            type: .tracking,
            order: 1,
            isDefault: true,
            placeholder: "예: 민준님, 김 대리"
        ))
        actions.append(RapportAction(
            title: "직함과 역할 파악",
            actionDescription: "무슨 일을 하시나요?",
            phase: .surface,
            type: .tracking,
            order: 2,
            isDefault: true,
            placeholder: "예: iOS 개발자, 신입 디자이너"
        ))
        actions.append(RapportAction(
            title: "나이대 또는 경력 파악",
            actionDescription: "얼마나 일하셨어요?",
            phase: .surface,
            type: .tracking,
            order: 3,
            isDefault: true,
            placeholder: "예: 3년차, 2030년대 초반"
        ))
        actions.append(RapportAction(
            title: "출퇴근 시간/방식 파악",
            actionDescription: "언제 연락 가능한지",
            phase: .surface,
            type: .tracking,
            order: 4,
            isDefault: true,
            placeholder: "예: 9시 출근, 저녁 8시 이후 연락 피하기"
        ))
        actions.append(RapportAction(
            title: "첫인상과 외적 특징 메모",
            actionDescription: "기억에 남는 특징",
            phase: .surface,
            type: .tracking,
            order: 5,
            isDefault: true,
            placeholder: "예: 안경 착용, 말투가 차분함, 웃는 얼굴"
        ))
        
        // ========================================
        // Level 2: 사회적 정보 (Social) - 6~10
        // 일상적인 관심사와 선호
        // ========================================
        actions.append(RapportAction(
            title: "취미 물어보기",
            actionDescription: "여가 시간에 뭐 하세요?",
            phase: .social,
            type: .tracking,
            order: 6,
            isDefault: true,
            placeholder: "예: 게임, 러닝, 독서"
        ))
        actions.append(RapportAction(
            title: "커피/음료 취향 파악",
            actionDescription: "함께 마실 때 뭐 드릴까요?",
            phase: .social,
            type: .tracking,
            order: 7,
            isDefault: true,
            placeholder: "예: 아메리카노 좋아함, 카페인 피함"
        ))
        actions.append(RapportAction(
            title: "음식 취향과 식단",
            actionDescription: "좋아하는 음식, 못 먹는 것",
            phase: .social,
            type: .tracking,
            order: 8,
            isDefault: true,
            placeholder: "예: 매운 거 못 먹음, 파스타 좋아함"
        ))
        actions.append(RapportAction(
            title: "주말 활동 패턴",
            actionDescription: "주말엔 주로 뭐 하세요?",
            phase: .social,
            type: .tracking,
            order: 9,
            isDefault: true,
            placeholder: "예: 집에서 쉼, 등산 자주 감"
        ))
        actions.append(RapportAction(
            title: "점심/커피 함께 하기",
            actionDescription: "가벼운 식사나 커피 제안",
            phase: .social,
            type: .maintenance,
            order: 10,
            isDefault: true,
            placeholder: "예: 목요일 점심 같이 먹음"
        ))
        
        // ========================================
        // Level 3: 개인적 맥락 (Personal) - 11~15
        // 배경과 경험, 성향
        // ========================================
        actions.append(RapportAction(
            title: "학력과 전공 파악",
            actionDescription: "어디서 공부하셨어요?",
            phase: .personal,
            type: .tracking,
            order: 11,
            isDefault: true,
            placeholder: "예: KAIST 전산학과"
        ))
        actions.append(RapportAction(
            title: "이전 경력 알아가기",
            actionDescription: "전에는 어디서 일하셨어요?",
            phase: .personal,
            type: .tracking,
            order: 12,
            isDefault: true,
            placeholder: "예: 네이버 2년, 스타트업 1년"
        ))
        actions.append(RapportAction(
            title: "출신과 배경 이야기",
            actionDescription: "어디 출신이세요?",
            phase: .personal,
            type: .tracking,
            order: 13,
            isDefault: true,
            placeholder: "예: 서울 출신, 지방에서 올라옴"
        ))
        actions.append(RapportAction(
            title: "업무 스타일과 성향 파악",
            actionDescription: "어떻게 일하는 걸 선호하세요?",
            phase: .personal,
            type: .tracking,
            order: 14,
            isDefault: true,
            placeholder: "예: 문서화 선호, 집중할 때 헤드폰"
        ))
        actions.append(RapportAction(
            title: "가족 구성 가볍게 언급",
            actionDescription: "가족 이야기가 나오면 메모",
            phase: .personal,
            type: .tracking,
            order: 15,
            isDefault: true,
            placeholder: "예: 동생 있음, 부모님 부산"
        ))
        
        // ========================================
        // Level 4: 감정과 신뢰 (Emotional) - 16~20
        // 고민, 어려움, 감정 공유
        // ========================================
        actions.append(RapportAction(
            title: "현재 고민 들어주기",
            actionDescription: "요즘 힘든 거 없어요?",
            phase: .emotional,
            type: .tracking,
            order: 16,
            isDefault: true,
            placeholder: "예: 프로젝트 데드라인 스트레스"
        ))
        actions.append(RapportAction(
            title: "업무 스트레스 파악",
            actionDescription: "무엇이 가장 힘든가요?",
            phase: .emotional,
            type: .tracking,
            order: 17,
            isDefault: true,
            placeholder: "예: 팀 커뮤니케이션 어려움"
        ))
        actions.append(RapportAction(
            title: "실수했을 때 응원",
            actionDescription: "괜찮아요, 다들 그래요",
            phase: .emotional,
            type: .critical,
            order: 18,
            isDefault: true,
            placeholder: "예: 배포 실수 위로함"
        ))
        actions.append(RapportAction(
            title: "어려움에 공감 표현",
            actionDescription: "충분히 힘들 수 있어요",
            phase: .emotional,
            type: .critical,
            order: 19,
            isDefault: true,
            placeholder: "예: 야근 많아서 힘들다고 공감"
        ))
        actions.append(RapportAction(
            title: "중요한 날 챙기기",
            actionDescription: "생일, 발표일 등",
            phase: .emotional,
            type: .critical,
            order: 20,
            isDefault: true,
            placeholder: "예: 생일 5월 15일"
        ))
        
        // ========================================
        // Level 5: 가치관과 신념 (Values) - 21~25
        // 꿈, 목표, 인생관
        // ========================================
        actions.append(RapportAction(
            title: "커리어 목표 물어보기",
            actionDescription: "앞으로 뭘 하고 싶으세요?",
            phase: .values,
            type: .tracking,
            order: 21,
            isDefault: true,
            placeholder: "예: 게임 회사로 이직 희망"
        ))
        actions.append(RapportAction(
            title: "일에서 중요하게 여기는 것",
            actionDescription: "무엇이 가장 중요한가요?",
            phase: .values,
            type: .tracking,
            order: 22,
            isDefault: true,
            placeholder: "예: 성장 기회, 워라밸"
        ))
        actions.append(RapportAction(
            title: "5년 후 모습 상상",
            actionDescription: "5년 후엔 어떤 모습일까요?",
            phase: .values,
            type: .tracking,
            order: 23,
            isDefault: true,
            placeholder: "예: 시니어 개발자, 팀 리드"
        ))
        actions.append(RapportAction(
            title: "인생에서 추구하는 가치",
            actionDescription: "무엇이 의미있나요?",
            phase: .values,
            type: .tracking,
            order: 24,
            isDefault: true,
            placeholder: "예: 의미있는 제품 만들기, 사람 돕기"
        ))
        actions.append(RapportAction(
            title: "롤모델과 영감",
            actionDescription: "존경하는 사람, 영향 받은 것",
            phase: .values,
            type: .tracking,
            order: 25,
            isDefault: true,
            placeholder: "예: 특정 개발자, 책, 경험"
        ))
        
        // ========================================
        // Level 6: 깊은 유대 (Intimate) - 26~30
        // 취약함 공유, 진정한 친밀감
        // ========================================
        actions.append(RapportAction(
            title: "인생 전환점 이야기",
            actionDescription: "삶을 바꾼 경험이 있나요?",
            phase: .intimate,
            type: .tracking,
            order: 26,
            isDefault: true,
            placeholder: "예: 전공 바꾼 이유, 이직 결심"
        ))
        actions.append(RapportAction(
            title: "두려움과 불안 공유",
            actionDescription: "무엇이 두렵거나 불안한가요?",
            phase: .intimate,
            type: .tracking,
            order: 27,
            isDefault: true,
            placeholder: "예: 실력 부족 두려움, 미래 불안"
        ))
        actions.append(RapportAction(
            title: "후회와 아쉬움 들어주기",
            actionDescription: "돌이키고 싶은 선택",
            phase: .intimate,
            type: .tracking,
            order: 28,
            isDefault: true,
            placeholder: "예: 더 일찍 전공 바꿀걸"
        ))
        actions.append(RapportAction(
            title: "진심 어린 조언과 지지",
            actionDescription: "있는 그대로 응원하기",
            phase: .intimate,
            type: .critical,
            order: 29,
            isDefault: true,
            placeholder: "예: 충분히 잘하고 있다고 격려"
        ))
        actions.append(RapportAction(
            title: "상호 취약함 공유",
            actionDescription: "나의 어려움도 나누기",
            phase: .intimate,
            type: .critical,
            order: 30,
            isDefault: true,
            placeholder: "예: 나도 비슷한 고민 있었다고 공유"
        ))
        
        return actions
    }
}
