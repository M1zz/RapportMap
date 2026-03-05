//
//  PersonMapView.swift
//  RapportMap
//
//  핵심 뷰 - 관계 지도 (중세 왕국 지도 스타일)
//

import SwiftUI
import SwiftData

// MARK: - 색상 헬퍼

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB,
                  red: Double(r) / 255,
                  green: Double(g) / 255,
                  blue: Double(b) / 255,
                  opacity: Double(a) / 255)
    }
}

// MARK: - PersonMapView

struct PersonMapView: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person

    @State private var selectedTerritory: Territory?
    @State private var showingAddDiscovery = false
    @State private var showingDiscoveryDetail: Discovery?

    @State private var scale: CGFloat = 1.2
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var appearAnimation = false
    @State private var showingNewDiscoveryEffect = false
    @State private var newDiscoveryTerritory: Territory?

    private let minScale: CGFloat = 0.8
    private let maxScale: CGFloat = 2.5

    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let mapSize = min(geometry.size.width, geometry.size.height) - 40
            let baseRadius = mapSize / 2
            let maxRadius = baseRadius * scale

            ZStack {
                mapGroup(center: center, mapSize: mapSize, maxRadius: maxRadius)

                if showingNewDiscoveryEffect, let territory = newDiscoveryTerritory {
                    NewDiscoveryEffect(isShowing: $showingNewDiscoveryEffect, territory: territory)
                }

                // 줌 컨트롤
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        zoomControls.padding()
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddDiscovery) {
            if let territory = selectedTerritory {
                AddDiscoverySheet(person: person, territory: territory) {
                    newDiscoveryTerritory = territory
                    showingNewDiscoveryEffect = true
                }
            }
        }
        .sheet(item: $showingDiscoveryDetail) { discovery in
            DiscoveryDetailSheet(discovery: discovery)
        }
        .onAppear {
            withAnimation { appearAnimation = true }
        }
    }

    // MARK: - 메인 그룹 (줌/패닝 가능)

    private func mapGroup(center: CGPoint, mapSize: CGFloat, maxRadius: CGFloat) -> some View {
        Group {
            // 중세 지도 배경
            MedievalMapBackground(person: person, size: mapSize)
                .position(center)

            // 영역 노드들
            ForEach(Territory.allCases) { territory in
                territoryNodeView(territory: territory, center: center, maxRadius: maxRadius)
            }

            // 카르투슈 (하단)
            MapCartouche(personName: person.name)
                .position(x: center.x, y: center.y + mapSize * 0.43)
        }
        .offset(offset)
        .gesture(
            SimultaneousGesture(
                MagnifyGesture().onChanged { value in
                    scale = min(max(scale * value.magnification, minScale), maxScale)
                },
                DragGesture()
                    .onChanged { value in
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
            )
        )
    }

    private func territoryNodeView(territory: Territory, center: CGPoint, maxRadius: CGFloat) -> some View {
        TerritoryNode(
            territory: territory,
            isExplored: person.hasExplored(territory),
            isAccessible: person.canAccess(territory),
            isSelected: selectedTerritory == territory,
            scale: scale
        )
        .position(nodePosition(for: territory, center: center, maxRadius: maxRadius))
        .onTapGesture { handleTerritoryTap(territory) }
        .opacity(appearAnimation ? 1 : 0)
        .scaleEffect(appearAnimation ? 1 : 0.5)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.7)
                .delay(Double(Territory.allCases.firstIndex(of: territory) ?? 0) * 0.03),
            value: appearAnimation
        )
    }

    // MARK: - 노드 위치

    private func nodePosition(for territory: Territory, center: CGPoint, maxRadius: CGFloat) -> CGPoint {
        let depth = territory.depth
        let radius = maxRadius * nodeRadiusRatio(for: depth)
        let territoriesAtDepth = Territory.territories(for: depth)
        guard let index = territoriesAtDepth.firstIndex(of: territory) else { return center }
        let count = territoriesAtDepth.count
        let angle: CGFloat = -.pi / 2 + (2 * .pi / CGFloat(count)) * CGFloat(index)
        return CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
    }

    private func nodeRadiusRatio(for depth: RelationshipDepth) -> CGFloat {
        switch depth {
        case .surface: return 0.90
        case .personal: return 0.66
        case .deep: return 0.43
        case .intimate: return 0.21
        }
    }

    // MARK: - 줌 컨트롤

    private var zoomControls: some View {
        VStack(spacing: 8) {
            zoomButton(icon: "plus") { scale = min(scale + 0.3, maxScale) }
            zoomButton(icon: "minus") { scale = max(scale - 0.3, minScale) }
            zoomButton(icon: "arrow.counterclockwise") {
                scale = 1.2; offset = .zero; lastOffset = .zero
            }
        }
    }

    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3)) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 액션

    private func handleTerritoryTap(_ territory: Territory) {
        selectedTerritory = territory
        guard person.canAccess(territory) else { return }
        if person.hasExplored(territory) {
            if let discovery = person.discoveries(for: territory).first {
                showingDiscoveryDetail = discovery
            }
        } else {
            showingAddDiscovery = true
        }
    }
}

// MARK: - 중세 지도 배경

struct MedievalMapBackground: View {
    let person: Person
    let size: CGFloat

    private let ref: CGFloat = 560  // 기준 크기

    var body: some View {
        ZStack {
            Canvas { ctx, rect in
                let w = rect.width
                let h = rect.height
                let r = w / ref

                drawParchment(ctx: ctx, w: w, h: h)
                drawGrid(ctx: ctx, w: w, h: h, r: r)
                drawSurfaceZone(ctx: ctx, w: w, h: h)
                drawPersonalZone(ctx: ctx, w: w, h: h, r: r)
                drawDeepZone(ctx: ctx, w: w, h: h, r: r)
                drawIntimateZone(ctx: ctx, w: w, h: h, r: r)
                drawRiver(ctx: ctx, w: w, h: h, r: r)
                drawFog(ctx: ctx, w: w, h: h)
            }
            .frame(width: size, height: size)

            // 장식 테두리 + 나침반 + 라벨 (Canvas 위에 SwiftUI 오버레이)
            decorativeOverlay
        }
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Color(hex: "6a3e10").opacity(0.35), radius: 8, x: 3, y: 4)
    }

    // MARK: Canvas Draw 함수들

    private func drawParchment(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let bg = Path(CGRect(origin: .zero, size: CGSize(width: w, height: h)))
        ctx.fill(bg, with: .linearGradient(
            Gradient(stops: [
                .init(color: Color(hex: "f8edd0"), location: 0),
                .init(color: Color(hex: "e8d098"), location: 0.5),
                .init(color: Color(hex: "c89050"), location: 1)
            ]),
            startPoint: CGPoint(x: w * 0.2, y: 0),
            endPoint: CGPoint(x: w * 0.8, y: h)
        ))
    }

    private func drawGrid(ctx: GraphicsContext, w: CGFloat, h: CGFloat, r: CGFloat) {
        let spacing = 56 * r
        var path = Path()
        var x: CGFloat = 0
        while x <= w { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: h)); x += spacing }
        var y: CGFloat = 0
        while y <= h { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: w, y: y)); y += spacing }
        ctx.stroke(path, with: .color(Color(red: 100/255, green: 60/255, blue: 10/255, opacity: 0.05)), lineWidth: 1)
    }

    private func drawSurfaceZone(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let path = Path(CGRect(origin: .zero, size: CGSize(width: w, height: h)))
        ctx.fill(path, with: .color(Color(hex: "dfc870").opacity(0.55)))
        ctx.stroke(path, with: .color(Color(red: 40/255, green: 25/255, blue: 5/255, opacity: 0.65)), lineWidth: 2)
    }

    private func drawPersonalZone(ctx: GraphicsContext, w: CGFloat, h: CGFloat, r: CGFloat) {
        let pts: [(CGFloat, CGFloat)] = [
            (0.16, 0.16), (0.5, 0.11), (0.84, 0.16),
            (0.89, 0.5),  (0.84, 0.84), (0.5, 0.89),
            (0.16, 0.84), (0.11, 0.5)
        ]
        let path = polygonPath(points: pts, w: w, h: h)
        ctx.fill(path, with: .color(Color(hex: "6a9e3c").opacity(0.88)))
        ctx.stroke(path, with: .color(Color(red: 30/255, green: 25/255, blue: 18/255, opacity: 0.8)),
                   style: StrokeStyle(lineWidth: 2.5 * r))
    }

    private func drawDeepZone(ctx: GraphicsContext, w: CGFloat, h: CGFloat, r: CGFloat) {
        let pts: [(CGFloat, CGFloat)] = [
            (0.32, 0.27), (0.5, 0.23), (0.69, 0.28),
            (0.74, 0.5),  (0.68, 0.73), (0.5, 0.77),
            (0.31, 0.73), (0.26, 0.5)
        ]
        let path = polygonPath(points: pts, w: w, h: h)
        ctx.fill(path, with: .color(Color(hex: "7a8a96").opacity(0.92)))
        ctx.stroke(path, with: .color(Color(red: 20/255, green: 15/255, blue: 8/255, opacity: 0.95)),
                   style: StrokeStyle(lineWidth: 3 * r))
    }

    private func drawIntimateZone(ctx: GraphicsContext, w: CGFloat, h: CGFloat, r: CGFloat) {
        let pts: [(CGFloat, CGFloat)] = [
            (0.38, 0.37), (0.62, 0.37), (0.64, 0.5),
            (0.61, 0.63), (0.38, 0.63), (0.36, 0.5)
        ]
        let path = polygonPath(points: pts, w: w, h: h)
        ctx.fill(path, with: .color(Color(hex: "3e3028")))
        ctx.stroke(path, with: .color(Color(red: 20/255, green: 15/255, blue: 8/255, opacity: 0.95)),
                   style: StrokeStyle(lineWidth: 3 * r))
    }

    private func drawRiver(ctx: GraphicsContext, w: CGFloat, h: CGFloat, r: CGFloat) {
        var path = Path()
        let sc = w / ref
        path.move(to: CGPoint(x: 0, y: 220 * sc))
        path.addCurve(
            to: CGPoint(x: 100 * sc, y: 240 * sc),
            control1: CGPoint(x: 50 * sc, y: 215 * sc),
            control2: CGPoint(x: 90 * sc, y: 230 * sc)
        )
        path.addCurve(
            to: CGPoint(x: 228 * sc, y: 268 * sc),
            control1: CGPoint(x: 130 * sc, y: 255 * sc),
            control2: CGPoint(x: 165 * sc, y: 265 * sc)
        )
        ctx.stroke(path, with: .color(Color(hex: "3878a8").opacity(0.45)),
                   style: StrokeStyle(lineWidth: 5.5 * r, lineCap: .round))
        ctx.stroke(path, with: .color(Color(hex: "78c0e0").opacity(0.65)),
                   style: StrokeStyle(lineWidth: 2.5 * r, lineCap: .round))
    }

    private func drawFog(ctx: GraphicsContext, w: CGFloat, h: CGFloat) {
        let personalPts: [(CGFloat, CGFloat)] = [
            (0.16, 0.16), (0.5, 0.11), (0.84, 0.16),
            (0.89, 0.5),  (0.84, 0.84), (0.5, 0.89),
            (0.16, 0.84), (0.11, 0.5)
        ]
        let deepPts: [(CGFloat, CGFloat)] = [
            (0.32, 0.27), (0.5, 0.23), (0.69, 0.28),
            (0.74, 0.5),  (0.68, 0.73), (0.5, 0.77),
            (0.31, 0.73), (0.26, 0.5)
        ]
        let intimatePts: [(CGFloat, CGFloat)] = [
            (0.38, 0.37), (0.62, 0.37), (0.64, 0.5),
            (0.61, 0.63), (0.38, 0.63), (0.36, 0.5)
        ]

        if person.depth < .personal {
            ctx.fill(polygonPath(points: personalPts, w: w, h: h),
                     with: .color(Color(red: 208/255, green: 200/255, blue: 182/255, opacity: 0.78)))
        }
        if person.depth < .deep {
            ctx.fill(polygonPath(points: deepPts, w: w, h: h),
                     with: .color(Color(red: 208/255, green: 200/255, blue: 182/255, opacity: 0.78)))
        }
        if person.depth < .intimate {
            ctx.fill(polygonPath(points: intimatePts, w: w, h: h),
                     with: .color(Color(red: 195/255, green: 185/255, blue: 168/255, opacity: 0.95)))
        }
    }

    private func polygonPath(points: [(CGFloat, CGFloat)], w: CGFloat, h: CGFloat) -> Path {
        var path = Path()
        for (i, pt) in points.enumerated() {
            let p = CGPoint(x: pt.0 * w, y: pt.1 * h)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        return path
    }

    // MARK: - 장식 오버레이

    private var decorativeOverlay: some View {
        ZStack {
            // 바깥 테두리
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: "6a3e10"), lineWidth: 3)

            // 점선 안쪽 테두리
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    Color(red: 100/255, green: 64/255, blue: 20/255, opacity: 0.4),
                    style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                )
                .padding(7)

            // 코너 다이아몬드 장식
            cornerDiamonds

            // 나침반 (우상단)
            CompassView()
                .frame(width: 52, height: 52)
                .position(x: size - 38, y: 38)

            // 지도 영역 이름 라벨
            mapAreaLabels
        }
        .frame(width: size, height: size)
    }

    private var cornerDiamonds: some View {
        let corners: [(CGFloat, CGFloat)] = [(0, 0), (1, 0), (0, 1), (1, 1)]
        return ZStack {
            ForEach(Array(corners.enumerated()), id: \.offset) { _, corner in
                ZStack {
                    Rectangle()
                        .fill(Color(hex: "c88020"))
                        .frame(width: 10, height: 10)
                        .rotationEffect(.degrees(45))
                    Circle()
                        .fill(Color(hex: "c88020"))
                        .frame(width: 6, height: 6)
                }
                .position(
                    x: corner.0 == 0 ? 14 : size - 14,
                    y: corner.1 == 0 ? 14 : size - 14
                )
            }
        }
    }

    private var mapAreaLabels: some View {
        ZStack {
            Text("― 북부 평야 ―")
                .mapLabel(size: 10)
                .position(x: size * 0.5, y: size * 0.055)

            Text("숲의 북쪽 길목")
                .mapLabel(size: 8, color: Color(hex: "2a4010"))
                .position(x: size * 0.5, y: size * 0.165)

            Text("산악 지대")
                .mapLabel(size: 8, color: Color(hex: "304050"))
                .position(x: size * 0.5, y: size * 0.295)

            if person.depth >= .deep {
                Text("내성")
                    .mapLabel(size: 8, color: Color(hex: "e0d0b0").opacity(0.45))
                    .position(x: size * 0.5, y: size * 0.415)
            }
        }
    }
}

// MARK: - 라벨 modifier

private extension Text {
    func mapLabel(size: CGFloat, color: Color = Color(hex: "4a3010").opacity(0.55)) -> some View {
        self
            .font(.custom("Georgia", size: size).italic())
            .foregroundStyle(color)
    }
}

// MARK: - 나침반

struct CompassView: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "f0e0b0").opacity(0.9))
                .overlay(Circle().stroke(Color(hex: "8a6030"), lineWidth: 1))

            // N 방향 (금색)
            TriangleShape()
                .fill(Color(hex: "c07010"))
                .frame(width: 10, height: 14)
                .offset(y: -10)

            // S 방향
            TriangleShape()
                .fill(Color(hex: "7a4e28"))
                .frame(width: 10, height: 14)
                .rotationEffect(.degrees(180))
                .offset(y: 10)

            // W 방향
            TriangleShape()
                .fill(Color(hex: "8a6030"))
                .frame(width: 14, height: 10)
                .rotationEffect(.degrees(-90))
                .offset(x: -10)

            // E 방향
            TriangleShape()
                .fill(Color(hex: "8a6030"))
                .frame(width: 14, height: 10)
                .rotationEffect(.degrees(90))
                .offset(x: 10)

            Circle()
                .fill(Color(hex: "c07010"))
                .frame(width: 6, height: 6)

            Text("N")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(hex: "c07010"))
                .offset(y: -21)
        }
    }
}

// MARK: - 삼각형 Shape

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 카르투슈

struct MapCartouche: View {
    let personName: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(personName)의 탐험 지도")
                .font(.custom("Georgia", size: 12).italic())
                .foregroundStyle(Color(hex: "4a2e0a"))
            Text("Anno 2025")
                .font(.custom("Georgia", size: 9).italic())
                .foregroundStyle(Color(hex: "6a4020").opacity(0.75))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 7)
        .background(
            Ellipse()
                .fill(Color(hex: "f0dc9a").opacity(0.92))
                .overlay(Ellipse().stroke(Color(hex: "8a5020"), lineWidth: 1.5))
        )
    }
}

// MARK: - 영역 노드

struct TerritoryNode: View {
    let territory: Territory
    let isExplored: Bool
    let isAccessible: Bool
    let isSelected: Bool
    var scale: CGFloat = 1.0

    @State private var isGlowing = false

    private var nodeSize: CGFloat { 50 * scale }
    private var fontSize: CGFloat { 18 * scale }
    private var labelSize: CGFloat { max(8 * scale, 6) }

    var body: some View {
        ZStack {
            if isExplored {
                Circle()
                    .fill(territory.depth.color.opacity(0.3))
                    .frame(width: nodeSize + 16, height: nodeSize + 16)
                    .blur(radius: 10 * scale)
                    .opacity(isGlowing ? 0.8 : 0.4)

                DiscoverySparkle(isActive: isSelected)
                    .frame(width: nodeSize + 16, height: nodeSize + 16)
            }

            Circle()
                .fill(backgroundColor)
                .frame(width: nodeSize, height: nodeSize)

            Circle()
                .stroke(borderColor, lineWidth: isSelected ? 3 : 1.5)
                .frame(width: nodeSize, height: nodeSize)

            VStack(spacing: 3 * scale) {
                if isAccessible {
                    Text(territory.emoji).font(.system(size: fontSize))
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16 * scale))
                        .foregroundStyle(.secondary)
                }

                Text(territory.title)
                    .font(.system(size: labelSize, weight: .medium))
                    .foregroundStyle(isAccessible ? .primary : .secondary)
                    .lineLimit(1)
            }

            if isExplored {
                Circle()
                    .fill(territory.depth.color)
                    .frame(width: 18 * scale, height: 18 * scale)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.system(size: 9 * scale, weight: .bold))
                            .foregroundStyle(.white)
                    )
                    .offset(x: 22 * scale, y: -22 * scale)
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
        if isExplored { return territory.depth.color.opacity(0.15) }
        if isAccessible { return Color.primaryBackground }
        return Color.gray.opacity(0.1)
    }

    private var borderColor: Color {
        if isExplored { return territory.depth.color }
        if isAccessible { return Color.secondary.opacity(0.3) }
        return Color.gray.opacity(0.2)
    }
}

// MARK: - Preview

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Person.self, Discovery.self, configurations: config)

    let person = Person(name: "김철수", depth: .personal)
    container.mainContext.insert(person)

    person.addDiscovery(territory: .nickname, content: "달빛이라는 닉네임")
    person.addDiscovery(territory: .hobby, content: "등산을 좋아함")
    person.addDiscovery(territory: .currentConcern, content: "이직 고민중")

    return PersonMapView(person: person)
        .modelContainer(container)
}
