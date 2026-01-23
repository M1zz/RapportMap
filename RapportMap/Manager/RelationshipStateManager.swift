//
//  RelationshipStateManager.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation
import SwiftData

/// 관계 관리를 도와주는 매니저 클래스
@MainActor
class RelationshipStateManager {
    static let shared = RelationshipStateManager()

    private init() {}

    /// 관심이 필요한 관계들 찾기 (최근 상호작용이 오래된 관계)
    func findRelationshipsNeedingAttention(context: ModelContext, daysThreshold: Int = 7) -> [Person] {
        do {
            let descriptor = FetchDescriptor<Person>()
            let people = try context.fetch(descriptor)

            let now = Date()
            let calendar = Calendar.current
            let thresholdDate = calendar.date(byAdding: .day, value: -daysThreshold, to: now) ?? now

            return people.filter { person in
                let recentInteractionDate = [person.lastContact, person.lastMeal, person.lastMentoring]
                    .compactMap { $0 }
                    .max() ?? person.relationshipStartDate

                return recentInteractionDate < thresholdDate
            }
        } catch {
            print("❌ [RelationshipStateManager] 관심 필요 관계 조회 실패: \(error)")
            return []
        }
    }

    /// 소홀한 관계들 찾기
    func findNeglectedRelationships(context: ModelContext) -> [Person] {
        do {
            let descriptor = FetchDescriptor<Person>()
            let people = try context.fetch(descriptor)

            return people.filter { $0.isNeglected }
        } catch {
            print("❌ [RelationshipStateManager] 소홀한 관계 조회 실패: \(error)")
            return []
        }
    }
}
