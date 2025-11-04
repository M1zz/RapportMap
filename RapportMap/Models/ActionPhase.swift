//
//  ActionPhase.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation

enum ActionPhase: String, Codable, CaseIterable, Identifiable {
    case phase1 = "첫 만남"
    case phase2 = "관계 설정"
    case phase3 = "신뢰 쌓기"
    case phase4 = "깊이 더하기"
    case phase5 = "관계 심화"
    case phase6 = "관계 유지"
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .phase1: return "1일차 - 첫 업무 시작"
        case .phase2: return "1주차 - 일상 루틴 형성"
        case .phase3: return "2-4주차 - 개인적 맥락 파악"
        case .phase4: return "1-2개월차 - 신뢰 쌓기"
        case .phase5: return "2-3개월차 - 관계 깊어지기"
        case .phase6: return "3개월 이후 - 장기 관계"
        }
    }
    
    var emoji: String {
        switch self {
        case .phase1: return "👋"
        case .phase2: return "🤝"
        case .phase3: return "💬"
        case .phase4: return "🤗"
        case .phase5: return "❤️"
        case .phase6: return "🌟"
        }
    }
    
    /// Phase 순서 (0부터 시작)
    var order: Int {
        switch self {
        case .phase1: return 0
        case .phase2: return 1
        case .phase3: return 2
        case .phase4: return 3
        case .phase5: return 4
        case .phase6: return 5
        }
    }
}
