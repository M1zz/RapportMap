//
//  Territory.swift
//  RapportMap
//
//  탐험 가능한 영역 - 관계에서 알아갈 수 있는 것들
//

import Foundation
import SwiftUI

// MARK: - 관계 깊이

/// 관계의 깊이 단계
/// 깊이가 깊어질수록 더 내밀한 영역을 탐험할 수 있다
enum RelationshipDepth: Int, Codable, CaseIterable, Comparable {
    case surface = 0    // 🌅 표면적 - 처음 만나도 물어볼 수 있는 것
    case personal = 1   // 🌆 개인적 - 조금 친해지면
    case deep = 2       // 🌃 깊은 - 신뢰가 쌓이면
    case intimate = 3   // 🌌 내밀한 - 깊은 신뢰 관계
    
    var title: String {
        switch self {
        case .surface: return "표면적"
        case .personal: return "개인적"
        case .deep: return "깊은"
        case .intimate: return "내밀한"
        }
    }
    
    var icon: String {
        switch self {
        case .surface: return "🌅"
        case .personal: return "🌆"
        case .deep: return "🌃"
        case .intimate: return "🌌"
        }
    }
    
    var color: Color {
        switch self {
        case .surface: return .orange
        case .personal: return .blue
        case .deep: return .purple
        case .intimate: return .indigo
        }
    }
    
    /// 달 아이콘 (관계 진행도)
    var moonPhase: String {
        switch self {
        case .surface: return "🌒"
        case .personal: return "🌓"
        case .deep: return "🌔"
        case .intimate: return "🌕"
        }
    }
    
    /// 지도 안개 농도 (0 = 맑음, 1 = 완전 안개)
    var fogOpacity: Double {
        switch self {
        case .surface: return 0.0
        case .personal: return 0.3
        case .deep: return 0.6
        case .intimate: return 0.85
        }
    }
    
    /// 다음 깊이
    var next: RelationshipDepth? {
        switch self {
        case .surface: return .personal
        case .personal: return .deep
        case .deep: return .intimate
        case .intimate: return nil
        }
    }
    
    static func < (lhs: RelationshipDepth, rhs: RelationshipDepth) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - 탐험 영역

/// 탐험 가능한 영역들
/// 각 영역은 특정 깊이에 속하며, 해당 깊이에 도달해야 탐험 가능
enum Territory: String, Codable, CaseIterable, Identifiable {
    
    // 🌅 표면 (Surface) - 처음 만나도 물어볼 수 있는 것
    case nickname       // 이름/닉네임의 이유
    case hobby          // 취미
    case job            // 하는 일
    case hometown       // 고향
    case favorites      // 좋아하는 것들 (음식, 음악, 영화 등)
    
    // 🌆 개인적 (Personal) - 조금 친해지면
    case currentConcern // 요즘 고민
    case goal           // 목표/꿈
    case dailyLife      // 일상/루틴
    case taste          // 취향/스타일
    case values         // 중요하게 생각하는 것
    case relationship   // 연애/인간관계
    
    // 🌃 깊은 (Deep) - 신뢰가 쌓이면
    case family         // 가족 이야기
    case childhood      // 어린 시절
    case turningPoint   // 인생 전환점
    case fear           // 두려움
    case regret         // 후회
    case belief         // 신념/철학
    
    // 🌌 내밀한 (Intimate) - 깊은 신뢰 관계
    case trauma         // 상처/트라우마
    case secret         // 비밀
    case vulnerability  // 약한 모습
    case trueSelf       // 진짜 자기 자신
    case deepDesire     // 깊은 욕망/소망
    
    var id: String { rawValue }
    
    // MARK: - 속성
    
    /// 이 영역이 속한 깊이
    var depth: RelationshipDepth {
        switch self {
        case .nickname, .hobby, .job, .hometown, .favorites:
            return .surface
        case .currentConcern, .goal, .dailyLife, .taste, .values, .relationship:
            return .personal
        case .family, .childhood, .turningPoint, .fear, .regret, .belief:
            return .deep
        case .trauma, .secret, .vulnerability, .trueSelf, .deepDesire:
            return .intimate
        }
    }
    
    /// 표시 이름
    var title: String {
        switch self {
        // Surface
        case .nickname: return "닉네임의 이유"
        case .hobby: return "취미"
        case .job: return "하는 일"
        case .hometown: return "고향"
        case .favorites: return "좋아하는 것"
        // Personal
        case .currentConcern: return "요즘 고민"
        case .goal: return "목표"
        case .dailyLife: return "일상"
        case .taste: return "취향"
        case .values: return "가치관"
        case .relationship: return "인간관계"
        // Deep
        case .family: return "가족"
        case .childhood: return "어린 시절"
        case .turningPoint: return "전환점"
        case .fear: return "두려움"
        case .regret: return "후회"
        case .belief: return "신념"
        // Intimate
        case .trauma: return "상처"
        case .secret: return "비밀"
        case .vulnerability: return "약한 모습"
        case .trueSelf: return "진짜 나"
        case .deepDesire: return "깊은 소망"
        }
    }
    
    /// 아이콘
    var icon: String {
        switch self {
        // Surface
        case .nickname: return "person.text.rectangle"
        case .hobby: return "star"
        case .job: return "briefcase"
        case .hometown: return "house"
        case .favorites: return "heart"
        // Personal
        case .currentConcern: return "cloud.rain"
        case .goal: return "flag"
        case .dailyLife: return "sun.max"
        case .taste: return "paintpalette"
        case .values: return "scale.3d"
        case .relationship: return "person.2"
        // Deep
        case .family: return "figure.2.and.child.holdinghands"
        case .childhood: return "teddybear"
        case .turningPoint: return "arrow.triangle.branch"
        case .fear: return "exclamationmark.triangle"
        case .regret: return "arrow.uturn.backward"
        case .belief: return "sparkles"
        // Intimate
        case .trauma: return "heart.slash"
        case .secret: return "lock"
        case .vulnerability: return "drop"
        case .trueSelf: return "figure.stand"
        case .deepDesire: return "moon.stars"
        }
    }
    
    /// 이모지
    var emoji: String {
        switch self {
        // Surface
        case .nickname: return "📛"
        case .hobby: return "⭐️"
        case .job: return "💼"
        case .hometown: return "🏠"
        case .favorites: return "💕"
        // Personal
        case .currentConcern: return "🌧️"
        case .goal: return "🎯"
        case .dailyLife: return "☀️"
        case .taste: return "🎨"
        case .values: return "⚖️"
        case .relationship: return "👥"
        // Deep
        case .family: return "👨‍👩‍👧"
        case .childhood: return "🧒"
        case .turningPoint: return "🔀"
        case .fear: return "😨"
        case .regret: return "😔"
        case .belief: return "✨"
        // Intimate
        case .trauma: return "💔"
        case .secret: return "🔐"
        case .vulnerability: return "🥺"
        case .trueSelf: return "🪞"
        case .deepDesire: return "🌙"
        }
    }
    
    /// 탐험 유도 질문
    var prompt: String {
        switch self {
        // Surface
        case .nickname: return "이 이름(닉네임)을 쓰게 된 이유가 있나요?"
        case .hobby: return "요즘 빠져있는 취미가 있나요?"
        case .job: return "어떤 일을 하고 계세요?"
        case .hometown: return "어디서 자라셨어요?"
        case .favorites: return "요즘 좋아하는 게 뭐예요?"
        // Personal
        case .currentConcern: return "요즘 고민 있으세요?"
        case .goal: return "요즘 목표로 하는 게 있나요?"
        case .dailyLife: return "보통 하루를 어떻게 보내세요?"
        case .taste: return "어떤 스타일을 좋아하세요?"
        case .values: return "뭘 중요하게 생각하세요?"
        case .relationship: return "주변 사람들과는 어떻게 지내세요?"
        // Deep
        case .family: return "가족 이야기 해주실 수 있어요?"
        case .childhood: return "어렸을 때는 어땠어요?"
        case .turningPoint: return "인생에서 전환점이 된 순간이 있었나요?"
        case .fear: return "무서운 게 있으세요?"
        case .regret: return "후회되는 게 있나요?"
        case .belief: return "삶에서 믿는 게 있나요?"
        // Intimate
        case .trauma: return "마음의 상처가 있나요?"
        case .secret: return "나만 아는 비밀이 있어요?"
        case .vulnerability: return "약해지는 순간이 있나요?"
        case .trueSelf: return "진짜 모습은 어떤가요?"
        case .deepDesire: return "마음 깊이 바라는 게 뭐예요?"
        }
    }
    
    // MARK: - 그룹핑
    
    /// 특정 깊이의 모든 영역
    static func territories(for depth: RelationshipDepth) -> [Territory] {
        allCases.filter { $0.depth == depth }
    }
    
    /// 특정 깊이까지 접근 가능한 모든 영역
    static func accessibleTerritories(at depth: RelationshipDepth) -> [Territory] {
        allCases.filter { $0.depth <= depth }
    }
}

// MARK: - 발견 감정

/// 발견했을 때의 감정
enum DiscoveryEmotion: String, Codable, CaseIterable, Identifiable {
    case surprised   // 😮 놀라웠다
    case touched     // 🥹 감동받았다
    case understood  // 🤝 이해하게 됐다
    case closer      // 💙 가까워진 느낌
    case curious     // 🤔 더 알고 싶어졌다
    case warm        // 🫠 따뜻해졌다
    case respectful  // 🫡 존경하게 됐다
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .surprised: return "😮"
        case .touched: return "🥹"
        case .understood: return "🤝"
        case .closer: return "💙"
        case .curious: return "🤔"
        case .warm: return "🫠"
        case .respectful: return "🫡"
        }
    }
    
    var title: String {
        switch self {
        case .surprised: return "놀라웠다"
        case .touched: return "감동받았다"
        case .understood: return "이해하게 됐다"
        case .closer: return "가까워진 느낌"
        case .curious: return "더 알고 싶다"
        case .warm: return "따뜻해졌다"
        case .respectful: return "존경하게 됐다"
        }
    }
}
