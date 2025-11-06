//
//  ActionEnums.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation

// MARK: - ActionPhase (관계의 깊이 기반)
enum ActionPhase: String, Codable, CaseIterable, Identifiable {
    case surface = "표면적 정보"           // Level 1: 이름, 직함, 외적 특징
    case social = "사회적 정보"            // Level 2: 취미, 관심사, 일상적 선호
    case personal = "개인적 맥락"          // Level 3: 배경, 경험, 성향, 업무 스타일
    case emotional = "감정과 신뢰"         // Level 4: 고민, 어려움, 두려움, 스트레스
    case values = "가치관과 신념"          // Level 5: 꿈, 목표, 가치관, 인생관
    case intimate = "깊은 유대"            // Level 6: 취약함 공유, 상호 의존, 진정한 친밀감
    
    var id: String { rawValue }
    
    // Custom decoder to handle legacy Korean values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        // Legacy values (기존 데이터 호환)
        case "첫 만남", "phase1":
            self = .surface
        case "관계 설정", "phase2":
            self = .social
        case "개인적 맥락 파악", "phase3":
            self = .personal
        case "신뢰 쌓기", "phase4":
            self = .emotional
        case "관계 깊어지기", "깊이 더하기", "phase5":
            self = .values
        case "장기 관계", "phase6":
            self = .intimate
        // New values
        case "표면적 정보", "surface":
            self = .surface
        case "사회적 정보", "social":
            self = .social
        case "개인적 맥락", "personal":
            self = .personal
        case "감정과 신뢰", "emotional":
            self = .emotional
        case "가치관과 신념", "values":
            self = .values
        case "깊은 유대", "intimate":
            self = .intimate
        default:
            print("⚠️ Unknown ActionPhase value: \(rawValue), defaulting to surface")
            self = .surface
        }
    }
    
    var emoji: String {
        switch self {
        case .surface: return "👤"      // 표면
        case .social: return "🎯"       // 사회적
        case .personal: return "📖"     // 개인적
        case .emotional: return "💬"    // 감정
        case .values: return "⭐️"       // 가치관
        case .intimate: return "💝"     // 깊은 유대
        }
    }
    
    var description: String {
        switch self {
        case .surface:
            return "겉으로 드러나는 기본 정보 - 누구나 알 수 있는 사실들"
        case .social:
            return "일상적인 대화 주제 - 가벼운 관심사와 선호"
        case .personal:
            return "개인의 배경과 경험 - 어떤 사람인지 이해하기"
        case .emotional:
            return "내면의 감정과 고민 - 신뢰를 바탕으로 한 공유"
        case .values:
            return "인생의 방향과 가치관 - 무엇을 중요하게 여기는지"
        case .intimate:
            return "깊은 유대와 진정성 - 서로의 취약함을 공유하는 관계"
        }
    }
    
    /// 관계 깊이의 예시
    var examples: [String] {
        switch self {
        case .surface:
            return ["이름", "나이", "직함", "출신 지역", "외모", "첫인상"]
        case .social:
            return ["취미", "좋아하는 음식", "음악 취향", "주말 활동", "운동 종류"]
        case .personal:
            return ["학력", "경력", "가족 구성", "성장 배경", "업무 스타일", "성격 특징"]
        case .emotional:
            return ["현재 고민", "스트레스 요인", "두려움", "어려움", "속상한 일", "기쁜 일"]
        case .values:
            return ["인생 목표", "커리어 방향", "중요하게 여기는 가치", "삶의 철학", "꿈"]
        case .intimate:
            return ["깊은 고민", "트라우마", "인생 전환점", "후회", "진심", "취약함"]
        }
    }
    
    var depthLevel: Int {
        switch self {
        case .surface: return 1
        case .social: return 2
        case .personal: return 3
        case .emotional: return 4
        case .values: return 5
        case .intimate: return 6
        }
    }
    
    /// Phase 순서 (0부터 시작, 배열 인덱스용)
    var order: Int {
        return depthLevel - 1
    }
    
    /// 이전 이름 (UI 호환성)
    var legacyName: String {
        switch self {
        case .surface: return "첫 만남"
        case .social: return "관계 설정"
        case .personal: return "개인적 맥락"
        case .emotional: return "신뢰 쌓기"
        case .values: return "가치관 공유"
        case .intimate: return "깊은 유대"
        }
    }
    
    /// 깊이 레벨 표시
    var depthIndicator: String {
        return String(repeating: "●", count: depthLevel) + String(repeating: "○", count: 6 - depthLevel)
    }
}

// MARK: - ActionType
enum ActionType: String, Codable, CaseIterable {
    case tracking = "tracking"     // 정보 수집/추적 액션
    case critical = "critical"     // 중요한/놓치면 안되는 액션
    case maintenance = "maintenance" // 관계 유지 액션
    
    // Custom decoder to handle legacy Korean values
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        
        switch rawValue {
        case "tracking", "정보수집":
            self = .tracking
        case "critical", "크리티컬", "중요":
            self = .critical
        case "maintenance", "관계유지":
            self = .maintenance
        default:
            // Default to tracking if unknown value
            print("⚠️ Unknown ActionType value: \(rawValue), defaulting to tracking")
            self = .tracking
        }
    }
    
    var emoji: String {
        switch self {
        case .tracking: return "📝"
        case .critical: return "⚠️"
        case .maintenance: return "🔄"
        }
    }
    
    var displayName: String {
        switch self {
        case .tracking: return "정보 수집"
        case .critical: return "중요"
        case .maintenance: return "관계 유지"
        }
    }
    
    var color: String {
        switch self {
        case .tracking: return "#007AFF"    // 파란색
        case .critical: return "#FF9500"    // 오렌지색
        case .maintenance: return "#34C759" // 초록색
        }
    }
    
    var description: String {
        switch self {
        case .tracking:
            return "상대방에 대한 정보를 수집하고 기록하는 액션입니다"
        case .critical:
            return "놓치면 관계에 부정적 영향을 줄 수 있는 중요한 액션입니다"
        case .maintenance:
            return "관계를 지속적으로 유지하고 발전시키는 액션입니다"
        }
    }
}