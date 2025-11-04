//
//  RelationshipStateManager.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation
import SwiftData

/// 관계 상태를 자동으로 관리하는 매니저 클래스
@MainActor
class RelationshipStateManager {
    static let shared = RelationshipStateManager()
    
    private init() {}
    
    /// 모든 사람의 관계 상태를 업데이트
    func updateAllRelationshipStates(context: ModelContext) {
        do {
            let descriptor = FetchDescriptor<Person>()
            let people = try context.fetch(descriptor)
            
            var updatedCount = 0
            
            for person in people {
                let oldState = person.state
                person.updateRelationshipState()
                
                if oldState != person.state {
                    updatedCount += 1
                }
            }
            
            try context.save()
            
            print("✅ [RelationshipStateManager] \(people.count)명 중 \(updatedCount)명의 관계 상태가 업데이트되었습니다")
            
        } catch {
            print("❌ [RelationshipStateManager] 관계 상태 업데이트 실패: \(error)")
        }
    }
    
    /// 특정 사람의 관계 상태 업데이트
    func updatePersonRelationshipState(_ person: Person, context: ModelContext) {
        person.updateRelationshipState()
        try? context.save()
    }
    
    /// 소홀한 관계들 찾기
    func findNeglectedRelationships(context: ModelContext) -> [Person] {
        do {
            let descriptor = FetchDescriptor<Person>(
                predicate: #Predicate<Person> { person in
                    person.state.rawValue == "distant" || person.isNeglected
                }
            )
            return try context.fetch(descriptor)
        } catch {
            print("❌ [RelationshipStateManager] 소홀한 관계 조회 실패: \(error)")
            return []
        }
    }
    
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
    
    /// 관계 상태 통계 가져오기
    func getRelationshipStatistics(context: ModelContext) -> RelationshipStatistics {
        do {
            let descriptor = FetchDescriptor<Person>()
            let people = try context.fetch(descriptor)
            
            var closeCount = 0
            var warmingCount = 0
            var distantCount = 0
            var neglectedCount = 0
            var totalScore: Double = 0
            
            for person in people {
                switch person.state {
                case .close: closeCount += 1
                case .warming: warmingCount += 1
                case .distant: distantCount += 1
                }
                
                if person.isNeglected {
                    neglectedCount += 1
                }
                
                totalScore += person.calculateRelationshipScore()
            }
            
            let averageScore = people.isEmpty ? 0 : totalScore / Double(people.count)
            
            return RelationshipStatistics(
                totalPeople: people.count,
                closeRelationships: closeCount,
                warmingRelationships: warmingCount,
                distantRelationships: distantCount,
                neglectedRelationships: neglectedCount,
                averageRelationshipScore: averageScore
            )
            
        } catch {
            print("❌ [RelationshipStateManager] 관계 통계 조회 실패: \(error)")
            return RelationshipStatistics(
                totalPeople: 0,
                closeRelationships: 0,
                warmingRelationships: 0,
                distantRelationships: 0,
                neglectedRelationships: 0,
                averageRelationshipScore: 0
            )
        }
    }
    
    /// 정기적인 관계 상태 체크 스케줄링 (앱이 활성화될 때마다 실행)
    func scheduleRelationshipStateCheck(context: ModelContext) {
        // 마지막 체크 시간 확인
        let lastCheckKey = "lastRelationshipStateCheck"
        let lastCheck = UserDefaults.standard.object(forKey: lastCheckKey) as? Date ?? Date.distantPast
        let now = Date()
        
        // 마지막 체크로부터 4시간 이상 경과했을 때만 실행
        if now.timeIntervalSince(lastCheck) > 4 * 60 * 60 {
            updateAllRelationshipStates(context: context)
            UserDefaults.standard.set(now, forKey: lastCheckKey)
            
            // 소홀한 관계가 있으면 알림
            let neglectedPeople = findNeglectedRelationships(context: context)
            if !neglectedPeople.isEmpty {
                print("🔔 [RelationshipStateManager] 관심이 필요한 관계가 \(neglectedPeople.count)개 있습니다")
            }
        }
    }
}

struct RelationshipStatistics {
    let totalPeople: Int
    let closeRelationships: Int
    let warmingRelationships: Int
    let distantRelationships: Int
    let neglectedRelationships: Int
    let averageRelationshipScore: Double
    
    var healthScore: Double {
        guard totalPeople > 0 else { return 0 }
        
        // 건강한 관계 비율 계산
        let healthyCount = closeRelationships + warmingRelationships
        return Double(healthyCount) / Double(totalPeople) * 100
    }
    
    var needsAttentionCount: Int {
        return distantRelationships + neglectedRelationships
    }
}
