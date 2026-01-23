//
//  RelationshipMapView.swift
//  RapportMap
//
//  iPad 전용 - 관계 맵 시각화
//  - Force-directed graph 레이아웃
//  - 인터랙티브 줌/팬
//  - 관계 강도 시각화
//

import SwiftUI
import SwiftData
import Combine

// MARK: - 데이터 모델

class MapNode: Identifiable, ObservableObject {
    let id: UUID
    let person: Person
    @Published var position: CGPoint
    @Published var velocity: CGPoint = .zero
    var force: CGPoint = .zero

    init(person: Person, position: CGPoint = .zero) {
        self.id = person.id
        self.person = person
        self.position = position
    }
}

struct MapEdge: Identifiable {
    let id = UUID()
    let from: UUID
    let to: UUID
    let strength: Double // 0.0 ~ 1.0
    let relationshipType: String

    var color: Color {
        if strength > 0.7 {
            return .green
        } else if strength > 0.4 {
            return .blue
        } else {
            return .gray
        }
    }

    var lineWidth: CGFloat {
        CGFloat(1 + strength * 4)
    }
}

// MARK: - ViewModel

@Observable
class RelationshipMapViewModel {
    var nodes: [MapNode] = []
    var edges: [MapEdge] = []
    var scale: CGFloat = 1.0
    var offset: CGSize = .zero
    var selectedNode: MapNode?

    private var timer: Timer?
    private let k: CGFloat = 100 // 이상적인 spring 길이
    private let repulsionStrength: CGFloat = 5000
    private let attractionStrength: CGFloat = 0.05
    private let damping: CGFloat = 0.8

    init() {}

    func loadPeople(_ people: [Person], in size: CGSize) {
        // 노드 생성
        nodes = people.enumerated().map { index, person in
            let angle = 2 * .pi * Double(index) / Double(people.count)
            let radius = min(size.width, size.height) * 0.3
            let x = size.width / 2 + CGFloat(cos(angle)) * radius
            let y = size.height / 2 + CGFloat(sin(angle)) * radius
            return MapNode(person: person, position: CGPoint(x: x, y: y))
        }

        // 엣지 생성 (관계 강도 계산)
        edges = []
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let person1 = nodes[i].person
                let person2 = nodes[j].person

                // 관계 강도 계산 (미팅 횟수 기반)
                let strength = calculateRelationshipStrength(person1, person2)

                if strength > 0.1 { // 최소 관계 강도
                    edges.append(MapEdge(
                        from: nodes[i].id,
                        to: nodes[j].id,
                        strength: strength,
                        relationshipType: "colleague"
                    ))
                }
            }
        }
    }

    private func calculateRelationshipStrength(_ person1: Person, _ person2: Person) -> Double {
        // 간단한 예: 랜덤 값 (실제로는 미팅 횟수, 마지막 연락 등 고려)
        // TODO: 실제 관계 데이터 기반 계산
        return Double.random(in: 0.2...1.0)
    }

    func startSimulation() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1/60.0, repeats: true) { [weak self] _ in
            self?.updateForces()
        }
    }

    func stopSimulation() {
        timer?.invalidate()
        timer = nil
    }

    private func updateForces() {
        // 1. 모든 힘 초기화
        for node in nodes {
            node.force = .zero
        }

        // 2. 반발력 (모든 노드 간)
        for i in 0..<nodes.count {
            for j in (i+1)..<nodes.count {
                let node1 = nodes[i]
                let node2 = nodes[j]

                let dx = node2.position.x - node1.position.x
                let dy = node2.position.y - node1.position.y
                let distance = max(sqrt(dx * dx + dy * dy), 1)

                let repulsion = repulsionStrength / (distance * distance)
                let fx = (dx / distance) * repulsion
                let fy = (dy / distance) * repulsion

                node1.force.x -= fx
                node1.force.y -= fy
                node2.force.x += fx
                node2.force.y += fy
            }
        }

        // 3. 인력 (엣지로 연결된 노드 간)
        for edge in edges {
            guard let node1 = nodes.first(where: { $0.id == edge.from }),
                  let node2 = nodes.first(where: { $0.id == edge.to }) else {
                continue
            }

            let dx = node2.position.x - node1.position.x
            let dy = node2.position.y - node1.position.y
            let distance = sqrt(dx * dx + dy * dy)

            let displacement = distance - k
            let attraction = attractionStrength * displacement * CGFloat(edge.strength)
            let fx = (dx / distance) * attraction
            let fy = (dy / distance) * attraction

            node1.force.x += fx
            node1.force.y += fy
            node2.force.x -= fx
            node2.force.y -= fy
        }

        // 4. 위치 업데이트
        for node in nodes {
            node.velocity.x = (node.velocity.x + node.force.x) * damping
            node.velocity.y = (node.velocity.y + node.force.y) * damping

            node.position.x += node.velocity.x
            node.position.y += node.velocity.y
        }
    }
}

// MARK: - Main View

struct RelationshipMapView: View {
    @Query(sort: \Person.name) private var people: [Person]
    @State private var viewModel = RelationshipMapViewModel()
    @State private var containerSize: CGSize = .zero

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // 배경
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                // 맵 콘텐츠
                Canvas { context, size in
                    // 엣지 그리기
                    for edge in viewModel.edges {
                        guard let fromNode = viewModel.nodes.first(where: { $0.id == edge.from }),
                              let toNode = viewModel.nodes.first(where: { $0.id == edge.to }) else {
                            continue
                        }

                        let from = transformPoint(fromNode.position, size: size)
                        let to = transformPoint(toNode.position, size: size)

                        var path = Path()
                        path.move(to: from)
                        path.addLine(to: to)

                        context.stroke(
                            path,
                            with: .color(edge.color.opacity(0.5)),
                            lineWidth: edge.lineWidth
                        )
                    }
                }

                // 노드 그리기 (SwiftUI로)
                ForEach(viewModel.nodes) { node in
                    NodeView(node: node, isSelected: viewModel.selectedNode?.id == node.id)
                        .position(transformPoint(node.position, size: containerSize))
                        .onTapGesture {
                            viewModel.selectedNode = node
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let transformed = inverseTransformPoint(value.location, size: containerSize)
                                    node.position = transformed
                                    node.velocity = .zero
                                }
                        )
                }

                // 선택된 노드 정보
                if let selectedNode = viewModel.selectedNode {
                    VStack {
                        Spacer()
                        SelectedNodeCard(node: selectedNode)
                            .padding()
                    }
                }

                // 컨트롤
                VStack {
                    HStack {
                        controlButtons
                        Spacer()
                        zoomControls
                    }
                    .padding()
                    Spacer()
                }
            }
            .onAppear {
                containerSize = geometry.size
                if viewModel.nodes.isEmpty {
                    viewModel.loadPeople(people, in: geometry.size)
                    viewModel.startSimulation()
                }
            }
            .onDisappear {
                viewModel.stopSimulation()
            }
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        viewModel.scale = max(0.5, min(value, 3.0))
                    }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        viewModel.offset = CGSize(
                            width: viewModel.offset.width + value.translation.width,
                            height: viewModel.offset.height + value.translation.height
                        )
                    }
            )
        }
        .navigationTitle("관계 맵")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var controlButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.loadPeople(people, in: containerSize)
            } label: {
                Label("재배치", systemImage: "arrow.triangle.2.circlepath")
                    .padding(8)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .cornerRadius(8)
            }

            Button {
                viewModel.scale = 1.0
                viewModel.offset = .zero
            } label: {
                Label("초기화", systemImage: "viewfinder")
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    private var zoomControls: some View {
        HStack(spacing: 8) {
            Button {
                viewModel.scale = max(0.5, viewModel.scale - 0.2)
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }

            Text("\(Int(viewModel.scale * 100))%")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 50)

            Button {
                viewModel.scale = min(3.0, viewModel.scale + 0.2)
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .padding(8)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
        }
    }

    private func transformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        let scaledX = point.x * viewModel.scale + viewModel.offset.width
        let scaledY = point.y * viewModel.scale + viewModel.offset.height
        return CGPoint(x: scaledX, y: scaledY)
    }

    private func inverseTransformPoint(_ point: CGPoint, size: CGSize) -> CGPoint {
        let x = (point.x - viewModel.offset.width) / viewModel.scale
        let y = (point.y - viewModel.offset.height) / viewModel.scale
        return CGPoint(x: x, y: y)
    }
}

// MARK: - Node View

struct NodeView: View {
    @ObservedObject var node: MapNode
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            // 프로필 이미지
            if let imageData = node.person.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.blue : Color.white, lineWidth: isSelected ? 4 : 2)
                    )
                    .shadow(radius: isSelected ? 8 : 4)
            } else {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Text(String(node.person.name.prefix(1)))
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(isSelected ? Color.blue : Color.white, lineWidth: isSelected ? 4 : 2)
                    )
                    .shadow(radius: isSelected ? 8 : 4)
            }

            // 이름
            Text(node.person.name)
                .font(.caption)
                .fontWeight(isSelected ? .bold : .regular)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.blue : Color.white)
                        .shadow(radius: 2)
                )
                .foregroundStyle(isSelected ? .white : .primary)
        }
    }

}

// MARK: - Selected Node Card

struct SelectedNodeCard: View {
    let node: MapNode

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if let imageData = node.person.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(String(node.person.name.prefix(1)))
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(node.person.name)
                        .font(.headline)
                    if !node.person.contact.isEmpty {
                        Text(node.person.contact)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()
            }

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("미팅")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(node.person.meetingRecords.count)회")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("대화")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(node.person.conversationRecords.count)건")
                        .font(.title3)
                        .fontWeight(.semibold)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    Text("활동")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(node.person.actions.count)개")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(radius: 10)
        )
    }
}

#Preview {
    RelationshipMapView()
        .modelContainer(for: [Person.self])
}
