//
//  ActionEnums.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation

// MARK: - ActionPhase
enum ActionPhase: String, Codable, CaseIterable, Identifiable {
    case phase1 = "첫 만남"
    case phase2 = "관계 설정"
    case phase3 = "개인적 맥락 파악"
    case phase4 = "신뢰 쌓기"
    case phase5 = "관계 깊어지기"
    case phase6 = "장기 관계"
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .phase1: return "👋"
        case .phase2: return "🤝"
        case .phase3: return "👤"
        case .phase4: return "💪"
        case .phase5: return "❤️"
        case .phase6: return "🌟"
        }
    }
    
    var description: String {
        switch self {
        case .phase1: return "처음 만나서 기본적인 인사와 파악"
        case .phase2: return "업무 관계를 설정하고 편안함 조성"
        case .phase3: return "개인의 배경과 성향 이해하기"
        case .phase4: return "서로에 대한 신뢰를 쌓아가는 단계"
        case .phase5: return "더 깊은 관계로 발전시키기"
        case .phase6: return "지속적이고 의미있는 장기 관계"
        }
    }
    
    var orderValue: Int {
        switch self {
        case .phase1: return 1
        case .phase2: return 2
        case .phase3: return 3
        case .phase4: return 4
        case .phase5: return 5
        case .phase6: return 6
        }
    }
    
    /// Phase 순서 (0부터 시작, 배열 인덱스용)
    var order: Int {
        return orderValue - 1
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