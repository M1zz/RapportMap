//
//  ActionType.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation

enum ActionType: String, Codable, CaseIterable {
    case tracking = "트래킹"     // [A] 기록용, 알림 X
    case critical = "크리티컬"   // [B] 놓치면 안되는 것, 알림 O
    
    var emoji: String {
        switch self {
        case .tracking: return "📝"
        case .critical: return "⚠️"
        }
    }
    
    var description: String {
        switch self {
        case .tracking: return "기록만 하고 필요할 때 참고"
        case .critical: return "놓치면 관계에 금이 가는 중요한 액션"
        }
    }
}
