//
//  Person.swift
//  RapportMap
//
//  사람 - 탐험할 관계
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Person {
    // MARK: - 기본 정보
    var id: UUID = UUID()
    var name: String = ""
    var contact: String = ""               // 연락처 (선택)

    @Attribute(.externalStorage)
    var profileImageData: Data?             // 프로필 사진

    // MARK: - 관계 정보
    var relationshipStartDate: Date = Date() // 관계 시작일
    var depthRawValue: Int = 0              // 현재 관계 깊이

    // MARK: - 메모
    var memo: String?                       // 간단한 메모

    // MARK: - Numbers 공유 문서
    var numbersSharedURL: String?           // iCloud Numbers 공유 링크

    // MARK: - 관계 (Relationships) — CloudKit requires optional to-many relationships

    /// 이 사람에 대한 발견들
    @Relationship(deleteRule: .cascade, inverse: \Discovery.person)
    var discoveries: [Discovery]?

    /// 이 사람에게 할당된 태그들
    @Relationship(deleteRule: .nullify, inverse: \PersonTag.people)
    var tags: [PersonTag]?

    /// 이 사람과의 활동 기록들
    @Relationship(deleteRule: .cascade, inverse: \ActivityRecord.person)
    var activities: [ActivityRecord]?

    /// 이 사람에 대한 자유 메모들
    @Relationship(deleteRule: .cascade, inverse: \PersonNote.person)
    var notes: [PersonNote]?
    
    // MARK: - Computed Properties
    
    /// 현재 관계 깊이
    var depth: RelationshipDepth {
        get {
            RelationshipDepth(rawValue: depthRawValue) ?? .surface
        }
        set {
            depthRawValue = newValue.rawValue
        }
    }
    
    // MARK: - Initializer
    
    init(
        id: UUID = UUID(),
        name: String = "",
        contact: String = "",
        profileImageData: Data? = nil,
        relationshipStartDate: Date = Date(),
        depth: RelationshipDepth = .surface,
        memo: String? = nil
    ) {
        self.id = id
        self.name = name
        self.contact = contact
        self.profileImageData = profileImageData
        self.relationshipStartDate = relationshipStartDate
        self.depthRawValue = depth.rawValue
        self.memo = memo
    }
}

// MARK: - 탐험 관련 Computed Properties

extension Person {
    
    /// 탐험한 영역들
    var exploredTerritories: Set<Territory> {
        Set((discoveries ?? []).map { $0.territory })
    }
    
    /// 현재 깊이에서 탐험 가능한 영역들
    var availableTerritories: [Territory] {
        Territory.accessibleTerritories(at: depth)
    }
    
    /// 아직 탐험하지 않은 영역들 (현재 깊이까지)
    var unexploredTerritories: [Territory] {
        availableTerritories.filter { !exploredTerritories.contains($0) }
    }
    
    /// 잠긴 영역들 (현재 깊이보다 높은)
    var lockedTerritories: [Territory] {
        Territory.allCases.filter { $0.depth > depth }
    }
    
    /// 탐험 진행률 (현재 깊이 기준, 0.0 ~ 1.0)
    var explorationProgress: Double {
        let available = availableTerritories.count
        guard available > 0 else { return 0 }
        let explored = exploredTerritories.filter { $0.depth <= depth }.count
        return Double(explored) / Double(available)
    }
    
    /// 전체 탐험 진행률 (모든 영역 기준)
    var totalExplorationProgress: Double {
        let total = Territory.allCases.count
        guard total > 0 else { return 0 }
        return Double(exploredTerritories.count) / Double(total)
    }
    
    /// 달 아이콘 (현재 깊이 기준)
    var moonPhase: String {
        depth.moonPhase
    }
    
    /// 진행률에 따른 달 아이콘 (더 세분화)
    var progressMoonPhase: String {
        let progress = totalExplorationProgress
        switch progress {
        case 0..<0.15: return "🌑"
        case 0.15..<0.35: return "🌒"
        case 0.35..<0.55: return "🌓"
        case 0.55..<0.75: return "🌔"
        case 0.75..<0.90: return "🌖"
        default: return "🌕"
        }
    }
}

// MARK: - 발견 관련 메서드

extension Person {
    
    /// 새로운 발견 추가
    @discardableResult
    func addDiscovery(
        territory: Territory,
        content: String,
        context: String? = nil,
        emotion: DiscoveryEmotion? = nil,
        isSignificant: Bool = false,
        date: Date = Date()
    ) -> Discovery {
        let discovery = Discovery(
            date: date,
            territory: territory,
            content: content,
            context: context,
            emotion: emotion,
            isSignificant: isSignificant
        )
        discovery.person = self
        discoveries = (discoveries ?? []) + [discovery]
        return discovery
    }
    
    /// 특정 영역의 발견들 (최신순)
    func discoveries(for territory: Territory) -> [Discovery] {
        (discoveries ?? [])
            .filter { $0.territory == territory }
            .sorted { $0.date > $1.date }
    }

    /// 특정 깊이의 발견들 (최신순)
    func discoveries(at depth: RelationshipDepth) -> [Discovery] {
        (discoveries ?? [])
            .filter { $0.depth == depth }
            .sorted { $0.date > $1.date }
    }

    /// 모든 발견 (최신순)
    var sortedDiscoveries: [Discovery] {
        (discoveries ?? []).sorted { $0.date > $1.date }
    }

    /// 중요한 발견들
    var significantDiscoveries: [Discovery] {
        (discoveries ?? [])
            .filter { $0.isSignificant }
            .sorted { $0.date > $1.date }
    }

    /// 최근 발견들 (7일 이내)
    var recentDiscoveries: [Discovery] {
        (discoveries ?? [])
            .filter { $0.isRecent }
            .sorted { $0.date > $1.date }
    }
    
    /// 특정 영역이 탐험되었는지
    func hasExplored(_ territory: Territory) -> Bool {
        exploredTerritories.contains(territory)
    }
    
    /// 특정 영역에 접근 가능한지 (현재 깊이로)
    func canAccess(_ territory: Territory) -> Bool {
        territory.depth <= depth
    }
}

// MARK: - 깊이 진행 관련

extension Person {
    
    /// 다음 깊이로 진행 가능한지
    var canAdvanceDepth: Bool {
        // 현재 깊이의 영역 중 절반 이상 탐험했으면 다음 깊이로 진행 가능
        let currentDepthTerritories = Territory.territories(for: depth)
        let explored = currentDepthTerritories.filter { exploredTerritories.contains($0) }.count
        return explored >= currentDepthTerritories.count / 2 && depth.next != nil
    }
    
    /// 다음 깊이로 진행
    func advanceDepth() {
        guard let next = depth.next else { return }
        depth = next
    }
    
    /// 깊이 수동 설정
    func setDepth(_ newDepth: RelationshipDepth) {
        depth = newDepth
    }
}

// MARK: - 통계

extension Person {
    
    /// 발견 통계
    var discoveryStats: DiscoveryStats {
        let allDiscoveries = discoveries ?? []
        return DiscoveryStats(
            total: allDiscoveries.count,
            byDepth: Dictionary(grouping: allDiscoveries, by: { $0.depth })
                .mapValues { $0.count },
            significant: significantDiscoveries.count,
            recent: recentDiscoveries.count
        )
    }
}

/// 발견 통계 구조체
struct DiscoveryStats {
    let total: Int
    let byDepth: [RelationshipDepth: Int]
    let significant: Int
    let recent: Int
    
    var surfaceCount: Int { byDepth[.surface] ?? 0 }
    var personalCount: Int { byDepth[.personal] ?? 0 }
    var deepCount: Int { byDepth[.deep] ?? 0 }
    var intimateCount: Int { byDepth[.intimate] ?? 0 }
}

// MARK: - 표시용

extension Person {
    
    /// 표시용 이름 (메모가 있으면 메모 일부 표시)
    var displayName: String {
        name
    }
    
    /// 관계 시작으로부터 경과 일수
    var daysSinceStart: Int {
        Calendar.current.dateComponents([.day], from: relationshipStartDate, to: Date()).day ?? 0
    }
    
    /// 관계 기간 텍스트
    var relationshipDuration: String {
        let days = daysSinceStart
        if days < 7 {
            return "\(days)일"
        } else if days < 30 {
            return "\(days / 7)주"
        } else if days < 365 {
            return "\(days / 30)개월"
        } else {
            let years = days / 365
            let months = (days % 365) / 30
            if months > 0 {
                return "\(years)년 \(months)개월"
            }
            return "\(years)년"
        }
    }
    
    /// 요약 텍스트
    var summary: String {
        let explored = exploredTerritories.count
        let total = Territory.allCases.count
        return "\(explored)/\(total) 영역 탐험 • \(depth.title)"
    }
}
