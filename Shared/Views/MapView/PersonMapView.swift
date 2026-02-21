//
//  PersonMapView.swift
//  RapportMap
//
//  핵심 뷰 - 관계 지도 (동심원 레이아웃)
//

import SwiftUI
import SwiftData

struct PersonMapView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    
    @State private var selectedTerritory: Territory?
    @State private var showingAddDiscovery = false
    @State private var showingDiscoveryDetail: Discovery?
    
    // 애니메이션 상태
    @State private var appearAnimation = false
    @State private var showingNewDiscoveryEffect = false
    @State private var newDiscoveryTerritory: Territory?
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let maxRadius = min(geometry.size.width, geometry.size.height) / 2 - 40
            
            ZStack {
                // 배경
                backgroundGradient
                
                // 동심원 레이어
                ForEach(RelationshipDepth.allCases.reversed(), id: \.self) { depth in
                    depthRing(depth: depth, center: center, maxRadius: maxRadius)
                }
                
                // 영역 노드들
                ForEach(Territory.allCases) { territory in
                    TerritoryNode(
                        territory: territory,
                        isExplored: person.hasExplored(territory),
                        isAccessible: person.canAccess(territory),
                        isSelected: selectedTerritory == territory
                    )
                    .position(nodePosition(for: territory, center: center, maxRadius: maxRadius))
                    .onTapGesture {
                        handleTerritoryTap(territory)
                    }
                    .opacity(appearAnimation ? 1 : 0)
                    .scaleEffect(appearAnimation ? 1 : 0.5)
                    .animation(
                        .spring(response: 0.6, dampingFraction: 0.7)
                        .delay(Double(Territory.allCases.firstIndex(of: territory) ?? 0) * 0.03),
                        value: appearAnimation
                    )
                }
                
                // 중앙: 사람 정보
                centerView(center: center)
                
                // 새 발견 효과
                if showingNewDiscoveryEffect, let territory = newDiscoveryTerritory {
                    NewDiscoveryEffect(
                        isShowing: $showingNewDiscoveryEffect,
                        territory: territory
                    )
                }
            }
        }
        .sheet(isPresented: $showingAddDiscovery) {
            if let territory = selectedTerritory {
                AddDiscoverySheet(person: person, territory: territory) {
                    // 성공 콜백
                    newDiscoveryTerritory = territory
                    showingNewDiscoveryEffect = true
                }
            }
        }
        .sheet(item: $showingDiscoveryDetail) { discovery in
            DiscoveryDetailSheet(discovery: discovery)
        }
        .onAppear {
            withAnimation {
                appearAnimation = true
            }
        }
    }
    
    // MARK: - 배경
    
    private var backgroundGradient: some View {
        RadialGradient(
            gradient: Gradient(colors: [
                Color.primaryBackground,
                Color.primaryBackground.opacity(0.95),
                Color.indigo.opacity(0.1)
            ]),
            center: .center,
            startRadius: 0,
            endRadius: 400
        )
        .ignoresSafeArea()
    }
    
    // MARK: - 동심원
    
    private func depthRing(depth: RelationshipDepth, center: CGPoint, maxRadius: CGFloat) -> some View {
        let radiusRatio = ringRadiusRatio(for: depth)
        let radius = maxRadius * radiusRatio
        let isAccessible = depth <= person.depth
        
        return ZStack {
            // 원
            Circle()
                .stroke(
                    depth.color.opacity(isAccessible ? 0.3 : 0.1),
                    lineWidth: 1
                )
                .frame(width: radius * 2, height: radius * 2)
            
            // 안개 (잠긴 영역)
            if !isAccessible {
                FogOverlay(depth: depth, isAccessible: false)
                    .frame(width: radius * 2, height: radius * 2)
                    .clipShape(Circle())
            }
            
            // 깊이 라벨
            Text("\(depth.icon) \(depth.title)")
                .font(.caption2)
                .foregroundStyle(isAccessible ? depth.color : .secondary)
                .offset(y: -radius - 12)
        }
        .position(center)
    }
    
    private func ringRadiusRatio(for depth: RelationshipDepth) -> CGFloat {
        switch depth {
        case .surface: return 0.95
        case .personal: return 0.70
        case .deep: return 0.45
        case .intimate: return 0.22
        }
    }
    
    // MARK: - 노드 위치 계산
    
    private func nodePosition(for territory: Territory, center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        let depth = territory.depth
        let radiusRatio = nodeRadiusRatio(for: depth)
        let radius = maxRadius * radiusRatio
        
        // 해당 깊이의 영역들 중 몇 번째인지
        let territoriesAtDepth = Territory.territories(for: depth)
        guard let index = territoriesAtDepth.firstIndex(of: territory) else {
            return center
        }
        
        let count = territoriesAtDepth.count
        let angleStep = (2 * .pi) / CGFloat(count)
        let startAngle: CGFloat = -.pi / 2 // 12시 방향부터 시작
        let angle = startAngle + angleStep * CGFloat(index)
        
        let x = center.x + radius * cos(angle)
        let y = center.y + radius * sin(angle)
        
        return CGPoint(x: x, y: y)
    }
    
    private func nodeRadiusRatio(for depth: RelationshipDepth) -> CGFloat {
        switch depth {
        case .surface: return 0.82
        case .personal: return 0.57
        case .deep: return 0.33
        case .intimate: return 0.15
        }
    }
    
    // MARK: - 중앙 뷰
    
    private func centerView(center: CGPoint) -> some View {
        VStack(spacing: 4) {
            MoonPhaseAnimation(progress: person.totalExplorationProgress)
            
            Text(person.name)
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("\(Int(person.totalExplorationProgress * 100))%")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .position(center)
    }
    
    // MARK: - 액션
    
    private func handleTerritoryTap(_ territory: Territory) {
        selectedTerritory = territory
        
        if person.canAccess(territory) {
            if person.hasExplored(territory) {
                // 이미 탐험한 영역 → 발견 내용 보기
                if let discovery = person.discoveries(for: territory).first {
                    showingDiscoveryDetail = discovery
                }
            } else {
                // 미탐험 영역 → 발견 추가
                showingAddDiscovery = true
            }
        }
        // 잠긴 영역은 탭해도 아무 일도 안 함 (노드 자체에서 잠금 표시)
    }
}

// MARK: - 영역 노드

struct TerritoryNode: View {
    let territory: Territory
    let isExplored: Bool
    let isAccessible: Bool
    let isSelected: Bool
    
    @State private var isGlowing = false
    
    var body: some View {
        ZStack {
            // 글로우 효과 (탐험 완료)
            if isExplored {
                Circle()
                    .fill(territory.depth.color.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)
                    .opacity(isGlowing ? 0.8 : 0.4)
                
                DiscoverySparkle(isActive: isSelected)
                    .frame(width: 60, height: 60)
            }
            
            // 배경 원
            Circle()
                .fill(backgroundColor)
                .frame(width: 50, height: 50)
            
            // 테두리
            Circle()
                .stroke(borderColor, lineWidth: isSelected ? 3 : 1.5)
                .frame(width: 50, height: 50)
            
            // 아이콘
            VStack(spacing: 2) {
                if isAccessible {
                    Text(territory.emoji)
                        .font(.system(size: 20))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                
                Text(territory.title)
                    .font(.system(size: 8))
                    .foregroundStyle(isAccessible ? .primary : .secondary)
                    .lineLimit(1)
            }
            
            // 탐험 완료 체크
            if isExplored {
                Circle()
                    .fill(territory.depth.color)
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 18, y: -18)
            }
        }
        .opacity(isAccessible ? 1 : 0.5)
        .onAppear {
            if isExplored {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isGlowing = true
                }
            }
        }
    }
    
    private var backgroundColor: Color {
        if isExplored {
            return territory.depth.color.opacity(0.15)
        } else if isAccessible {
            return Color.primaryBackground
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var borderColor: Color {
        if isExplored {
            return territory.depth.color
        } else if isAccessible {
            return Color.secondary.opacity(0.3)
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)
    
    let person = Person(name: "김철수", depth: .personal)
    container.mainContext.insert(person)
    
    // 샘플 발견 추가
    person.addDiscovery(territory: .nickname, content: "달빛이라는 닉네임, 밤에 산책하는 걸 좋아해서")
    person.addDiscovery(territory: .hobby, content: "등산을 좋아함, 주말마다 감")
    person.addDiscovery(territory: .currentConcern, content: "이직 고민중")
    
    return PersonMapView(person: person)
        .modelContainer(container)
}
