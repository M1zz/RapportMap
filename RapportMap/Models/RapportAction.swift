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

// MARK: - Default Actions Factory
extension RapportAction {
    /// 30가지 기본 액션 생성
    static func createDefaultActions() -> [RapportAction] {
        var actions: [RapportAction] = []
        
        // Phase 1: 첫 만남 (1-5)
        actions.append(RapportAction(
            title: "이름과 선호 호칭 확인",
            actionDescription: "뭐라고 부르면 편해요?",
            phase: .phase1,
            type: .tracking,
            order: 1,
            isDefault: true,
            placeholder: "예: 철수님, 김 대리"
        ))
        actions.append(RapportAction(
            title: "커피/식사 취향 물어보기",
            actionDescription: "실용적이면서 개인적인 질문",
            phase: .phase1,
            type: .tracking,
            order: 2,
            isDefault: true,
            placeholder: "예: 아메리카노 좋아함, 매운 거 못 먹음"
        ))
        actions.append(RapportAction(
            title: "출퇴근 시간/방식 파악",
            actionDescription: "언제 연락 가능한지",
            phase: .phase1,
            type: .tracking,
            order: 3,
            isDefault: true,
            placeholder: "예: 9시 30분 출근, 저녁 7시 이후 연락 피하기"
        ))
        actions.append(RapportAction(
            title: "업무 스타일 가볍게 물어보기",
            actionDescription: "어떻게 일하는 걸 선호해요?",
            phase: .phase1,
            type: .tracking,
            order: 4,
            isDefault: true,
            placeholder: "예: 문서로 소통 선호, 대면 미팅 싫어함"
        ))
        actions.append(RapportAction(
            title: "첫 업무 후 가벼운 피드백",
            actionDescription: "오늘 수고했어요",
            phase: .phase1,
            type: .tracking,
            order: 5,
            isDefault: true,
            placeholder: "예: 발표 잘했다고 칭찬함"
        ))
        
        // Phase 2: 관계 설정 (6-10)
        actions.append(RapportAction(
            title: "아침 인사 건네기",
            actionDescription: "매일 짧게라도",
            phase: .phase2,
            type: .tracking,
            order: 6,
            isDefault: true,
            placeholder: "예: 매일 아침 인사함"
        ))
        actions.append(RapportAction(
            title: "점심/커피 함께 가기 제안",
            actionDescription: "첫 주 내 한 번",
            phase: .phase2,
            type: .tracking,
            order: 7,
            isDefault: true,
            placeholder: "예: 목요일 점심 같이 먹음, 회사 근처 파스타집"
        ))
        actions.append(RapportAction(
            title: "업무 외 가벼운 잡담",
            actionDescription: "날씨, 주말 계획 등",
            phase: .phase2,
            type: .tracking,
            order: 8,
            isDefault: true,
            placeholder: "예: 주말에 등산 다녀왔다고 함"
        ))
        actions.append(RapportAction(
            title: "일하는 모습 관찰 후 칭찬",
            actionDescription: "구체적으로",
            phase: .phase2,
            type: .tracking,
            order: 9,
            isDefault: true,
            placeholder: "예: 코드 리뷰 꼼꼼하다고 칭찬"
        ))
        actions.append(RapportAction(
            title: "질문하기 편한 분위기 만들기",
            actionDescription: "언제든 물어봐요",
            phase: .phase2,
            type: .tracking,
            order: 10,
            isDefault: true,
            placeholder: "예: 편하게 질문하라고 함, 첫 질문 받음"
        ))
        
        // Phase 3: 개인적 맥락 파악 (11-15)
        actions.append(RapportAction(
            title: "출신/배경 자연스럽게 알아가기",
            actionDescription: "어디 출신인지, 전 직장 등",
            phase: .phase3,
            type: .tracking,
            order: 11,
            isDefault: true,
            placeholder: "예: 서울 출신, 전 직장 네이버"
        ))
        actions.append(RapportAction(
            title: "관심사 한 가지 파악",
            actionDescription: "취미, 좋아하는 것",
            phase: .phase3,
            type: .tracking,
            order: 12,
            isDefault: true,
            placeholder: "예: 게임 개발에 관심 많음, 주말에 사이드 프로젝트"
        ))
        actions.append(RapportAction(
            title: "멘토 본인 이야기도 공유",
            actionDescription: "일방적이지 않게",
            phase: .phase3,
            type: .tracking,
            order: 13,
            isDefault: true,
            placeholder: "예: 나도 초보 때 비슷한 실수했다고 공유"
        ))
        actions.append(RapportAction(
            title: "일하면서 불편한 점 물어보기",
            actionDescription: "뭐 필요한 거 없어요?",
            phase: .phase3,
            type: .tracking,
            order: 14,
            isDefault: true,
            placeholder: "예: 듀얼 모니터 필요하다고 함"
        ))
        actions.append(RapportAction(
            title: "작은 도움 주기",
            actionDescription: "업무 팁, 단축키 등",
            phase: .phase3,
            type: .tracking,
            order: 15,
            isDefault: true,
            placeholder: "예: VSCode 단축키 알려줌"
        ))
        
        // Phase 4: 신뢰 쌓기 (16-20)
        actions.append(RapportAction(
            title: "고민 상담 가볍게 받아주기",
            actionDescription: "업무 관련",
            phase: .phase4,
            type: .tracking,
            order: 16,
            isDefault: true,
            placeholder: "예: 프로젝트 일정 부담스럽다고 상담함"
        ))
        actions.append(RapportAction(
            title: "실수해도 괜찮다는 신호",
            actionDescription: "나도 그랬어요",
            phase: .phase4,
            type: .critical,
            order: 17,
            isDefault: true,
            placeholder: "예: 배포 실수했을 때 괜찮다고 위로함"
        ))
        actions.append(RapportAction(
            title: "회의/발표 전 응원",
            actionDescription: "잘 될 거예요",
            phase: .phase4,
            type: .tracking,
            order: 18,
            isDefault: true,
            placeholder: "예: 목요일 발표 전 응원 메시지"
        ))
        actions.append(RapportAction(
            title: "회의 후 격려나 피드백",
            actionDescription: "1:1로",
            phase: .phase4,
            type: .critical,
            order: 19,
            isDefault: true,
            placeholder: "예: 발표 후 잘했다고 피드백, 개선점 부드럽게 제안"
        ))
        actions.append(RapportAction(
            title: "개인적 어려움 눈치채기",
            actionDescription: "컨디션 안 좋아 보일 때",
            phase: .phase4,
            type: .tracking,
            order: 20,
            isDefault: true,
            placeholder: "예: 피곤해 보여서 괜찮냐고 물음"
        ))
        
        // Phase 5: 관계 깊어지기 (21-25)
        actions.append(RapportAction(
            title: "중요한 날 기억하기",
            actionDescription: "생일, 입사기념일",
            phase: .phase5,
            type: .critical,
            order: 21,
            isDefault: true,
            placeholder: "예: 생일 5월 15일, 입사 1년 11월 20일"
        ))
        actions.append(RapportAction(
            title: "업무 외 초대",
            actionDescription: "팀 회식, 가벼운 모임",
            phase: .phase5,
            type: .tracking,
            order: 22,
            isDefault: true,
            placeholder: "예: 팀 회식 참석, 즐거워 보임"
        ))
        actions.append(RapportAction(
            title: "강점을 구체적으로 인정",
            actionDescription: "당신의 이런 점이 팀에 도움돼요",
            phase: .phase5,
            type: .tracking,
            order: 23,
            isDefault: true,
            placeholder: "예: 문서화 능력 뛰어나다고 인정"
        ))
        actions.append(RapportAction(
            title: "커리어 고민 들어주기",
            actionDescription: "본인이 먼저 공유할 때",
            phase: .phase5,
            type: .tracking,
            order: 24,
            isDefault: true,
            placeholder: "예: 프론트엔드로 전환 고민 중"
        ))
        actions.append(RapportAction(
            title: "개선점은 1:1로 조심스럽게",
            actionDescription: "공개적으로 지적 X",
            phase: .phase5,
            type: .tracking,
            order: 25,
            isDefault: true,
            placeholder: "예: 코드 리뷰 방식 개선 제안"
        ))
        
        // Phase 6: 장기 관계 (26-30)
        actions.append(RapportAction(
            title: "정기적 1:1 시간",
            actionDescription: "한 달에 한 번이라도",
            phase: .phase6,
            type: .critical,
            order: 26,
            isDefault: true,
            placeholder: "예: 매월 첫째 주 금요일 1:1 미팅"
        ))
        actions.append(RapportAction(
            title: "성장 인정하고 표현",
            actionDescription: "많이 늘었네요",
            phase: .phase6,
            type: .tracking,
            order: 27,
            isDefault: true,
            placeholder: "예: 3개월 전보다 코드 퀄리티 많이 좋아짐"
        ))
        actions.append(RapportAction(
            title: "예상 못한 순간 챙기기",
            actionDescription: "아플 때, 힘들 때",
            phase: .phase6,
            type: .critical,
            order: 28,
            isDefault: true,
            placeholder: "예: 감기 걸렸을 때 일찍 퇴근하라고 배려"
        ))
        actions.append(RapportAction(
            title: "개인 경계 존중",
            actionDescription: "너무 깊이 들어가지 않기",
            phase: .phase6,
            type: .tracking,
            order: 29,
            isDefault: true,
            placeholder: "예: 개인사 물어보지 않기로 함"
        ))
        actions.append(RapportAction(
            title: "장기적 관심 표현",
            actionDescription: "앞으로도 응원할게요",
            phase: .phase6,
            type: .critical,
            order: 30,
            isDefault: true,
            placeholder: "예: 이직해도 연락하고 지내자고 함"
        ))
        
        return actions
    }
}
