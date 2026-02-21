//
//  RelationshipGraphView.swift
//  RapportMap
//
//  관계 시각화 - 중앙에 현재 사람, 주변에 같은 태그를 가진 사람들
//  원형 네트워크 그래프로 관계를 시각화
//

import SwiftUI
import SwiftData

struct RelationshipGraphView: View {
    @Bindable var person: Person
    @Query private var allPeople: [Person]
    @State private var selectedConnection: PersonConnection? = nil
    @State private var showingPersonDetail: Person? = nil
    
    // 그래프 설정
    private let centerRadius: CGFloat = 50
    private let connectionRadius: CGFloat = 35
    private let orbitRadius: CGFloat = 140
    
    /// 태그 기반으로 연결된 사람들 찾기
    private var connectedPeople: [PersonConnection] {
        var connections: [PersonConnection] = []
        let personTags = Set(person.tags.map { $0.name })
        
        for other in allPeople {
            guard other.id != person.id else { continue }
            
            let otherTags = Set(other.tags.map { $0.name })
            let commonTags = personTags.intersection(otherTags)
            
            if !commonTags.isEmpty {
                connections.append(PersonConnection(
                    person: other,
                    commonTags: Array(commonTags),
                    connectionStrength: Double(commonTags.count) / max(Double(personTags.count), 1.0)
                ))
            }
        }
        
        // 연결 강도순 정렬 (강한 연결이 먼저)
        return connections.sorted { $0.connectionStrength > $1.connectionStrength }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                // 배경
                Color(UIColor.systemBackground)
                
                if connectedPeople.isEmpty {
                    emptyStateView
                } else {
                    // 연결선
                    ForEach(Array(connectedPeople.prefix(8).enumerated()), id: \.element.id) { index, connection in
                        let angle = angleFor(index: index, total: min(connectedPeople.count, 8))
                        let position = positionFor(angle: angle, center: center, radius: orbitRadius)
                        
                        ConnectionLine(
                            from: center,
                            to: position,
                            strength: connection.connectionStrength,
                            isSelected: selectedConnection?.id == connection.id
                        )
                    }
                    
                    // 중앙 노드 (현재 사람)
                    CenterPersonNode(person: person, radius: centerRadius)
                        .position(center)
                    
                    // 연결된 사람들 노드
                    ForEach(Array(connectedPeople.prefix(8).enumerated()), id: \.element.id) { index, connection in
                        let angle = angleFor(index: index, total: min(connectedPeople.count, 8))
                        let position = positionFor(angle: angle, center: center, radius: orbitRadius)
                        
                        ConnectedPersonNode(
                            connection: connection,
                            radius: connectionRadius,
                            isSelected: selectedConnection?.id == connection.id
                        )
                        .position(position)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                if selectedConnection?.id == connection.id {
                                    selectedConnection = nil
                                } else {
                                    selectedConnection = connection
                                }
                            }
                        }
                    }
                }
            }
            
            // 선택된 연결 정보 표시
            if let selected = selectedConnection {
                VStack {
                    Spacer()
                    ConnectionDetailCard(connection: selected) {
                        showingPersonDetail = selected.person
                    }
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.5), value: selectedConnection?.id)
        .sheet(item: $showingPersonDetail) { person in
            NavigationStack {
                PersonDetailView(person: person)
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("연결된 사람이 없어요")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("같은 태그를 가진 사람들이\n여기에 표시됩니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            if person.tags.isEmpty {
                Text("태그를 추가하면 관계가 연결됩니다")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.top, 8)
            }
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func angleFor(index: Int, total: Int) -> Double {
        let startAngle = -Double.pi / 2 // 12시 방향에서 시작
        return startAngle + (Double(index) / Double(total)) * 2 * Double.pi
    }
    
    private func positionFor(angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(Darwin.cos(angle)) * radius,
            y: center.y + CGFloat(Darwin.sin(angle)) * radius
        )
    }
}

// MARK: - Supporting Types

struct PersonConnection: Identifiable {
    let id = UUID()
    let person: Person
    let commonTags: [String]
    let connectionStrength: Double // 0.0 ~ 1.0
    
    var relationshipLabel: String {
        if commonTags.isEmpty { return "연결" }
        return commonTags.first ?? "연결"
    }
}

// MARK: - Subviews

struct ConnectionLine: View {
    let from: CGPoint
    let to: CGPoint
    let strength: Double
    let isSelected: Bool
    
    var body: some View {
        Path { path in
            path.move(to: from)
            path.addLine(to: to)
        }
        .stroke(
            isSelected ? Color.blue : Color.gray.opacity(0.3 + strength * 0.4),
            style: StrokeStyle(
                lineWidth: isSelected ? 3 : 1.5 + CGFloat(strength) * 2,
                lineCap: .round
            )
        )
    }
}

struct CenterPersonNode: View {
    let person: Person
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            // 배경 원
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.8), Color.blue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
            
            // 프로필 이미지 또는 이니셜
            if let imageData = person.profileImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: radius * 2 - 8, height: radius * 2 - 8)
                    .clipShape(Circle())
            } else {
                Text(String(person.name.prefix(1)))
                    .font(.system(size: radius * 0.8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct ConnectedPersonNode: View {
    let connection: PersonConnection
    let radius: CGFloat
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // 배경 원
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(UIColor.secondarySystemBackground))
                    .frame(width: radius * 2, height: radius * 2)
                    .overlay(
                        Circle()
                            .stroke(
                                isSelected ? Color.blue : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 3 : 1.5
                            )
                    )
                    .shadow(color: isSelected ? .blue.opacity(0.2) : .clear, radius: 8)
                
                // 프로필 이미지 또는 이니셜
                if let imageData = connection.person.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: radius * 2 - 6, height: radius * 2 - 6)
                        .clipShape(Circle())
                } else {
                    Text(String(connection.person.name.prefix(1)))
                        .font(.system(size: radius * 0.6, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            
            // 이름
            Text(connection.person.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(isSelected ? .blue : .primary)
        }
    }
}

struct ConnectionDetailCard: View {
    let connection: PersonConnection
    let onNavigate: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // 헤더
            HStack {
                // 프로필
                if let imageData = connection.person.profileImageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 50, height: 50)
                        
                        Text(String(connection.person.name.prefix(1)))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(connection.person.name)
                        .font(.headline)
                    
                    if !connection.person.contact.isEmpty && connection.person.contact != "연락처 없음" {
                        Text(connection.person.contact)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Button {
                    onNavigate()
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
            }
            
            Divider()
            
            // 공통 태그
            VStack(alignment: .leading, spacing: 8) {
                Text("공통 태그")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                FlowLayout(spacing: 6) {
                    ForEach(connection.commonTags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.1))
                            .foregroundStyle(.blue)
                            .cornerRadius(12)
                    }
                }
            }
            
            // 연결 강도 표시
            HStack {
                Text("연결 강도")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                ProgressView(value: connection.connectionStrength)
                    .frame(width: 100)
                    .tint(.blue)
                
                Text("\(Int(connection.connectionStrength * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - macOS Compatible RelationshipGraphView

#if os(macOS)
struct MacRelationshipGraphView: View {
    @Bindable var person: Person
    @Query private var allPeople: [Person]
    @State private var selectedConnection: PersonConnection? = nil
    
    private let centerRadius: CGFloat = 60
    private let connectionRadius: CGFloat = 40
    private let orbitRadius: CGFloat = 180
    
    private var connectedPeople: [PersonConnection] {
        var connections: [PersonConnection] = []
        let personTags = Set(person.tags.map { $0.name })
        
        for other in allPeople {
            guard other.id != person.id else { continue }
            
            let otherTags = Set(other.tags.map { $0.name })
            let commonTags = personTags.intersection(otherTags)
            
            if !commonTags.isEmpty {
                connections.append(PersonConnection(
                    person: other,
                    commonTags: Array(commonTags),
                    connectionStrength: Double(commonTags.count) / max(Double(personTags.count), 1.0)
                ))
            }
        }
        
        return connections.sorted { $0.connectionStrength > $1.connectionStrength }
    }
    
    var body: some View {
        GeometryReader { geometry in
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            
            ZStack {
                Color(NSColor.windowBackgroundColor)
                
                if connectedPeople.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        
                        Text("연결된 사람이 없어요")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("같은 태그를 가진 사람들이 여기에 표시됩니다")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    // 연결선
                    ForEach(Array(connectedPeople.prefix(10).enumerated()), id: \.element.id) { index, connection in
                        let angle = angleFor(index: index, total: min(connectedPeople.count, 10))
                        let position = positionFor(angle: angle, center: center, radius: orbitRadius)
                        
                        ConnectionLine(
                            from: center,
                            to: position,
                            strength: connection.connectionStrength,
                            isSelected: selectedConnection?.id == connection.id
                        )
                    }
                    
                    // 중앙 노드
                    MacCenterNode(person: person, radius: centerRadius)
                        .position(center)
                    
                    // 연결된 사람들
                    ForEach(Array(connectedPeople.prefix(10).enumerated()), id: \.element.id) { index, connection in
                        let angle = angleFor(index: index, total: min(connectedPeople.count, 10))
                        let position = positionFor(angle: angle, center: center, radius: orbitRadius)
                        
                        MacConnectedNode(
                            connection: connection,
                            radius: connectionRadius,
                            isSelected: selectedConnection?.id == connection.id
                        )
                        .position(position)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedConnection = selectedConnection?.id == connection.id ? nil : connection
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func angleFor(index: Int, total: Int) -> Double {
        let startAngle = -Double.pi / 2
        return startAngle + (Double(index) / Double(total)) * 2 * Double.pi
    }
    
    private func positionFor(angle: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(
            x: center.x + CGFloat(Darwin.cos(angle)) * radius,
            y: center.y + CGFloat(Darwin.sin(angle)) * radius
        )
    }
}

struct MacCenterNode: View {
    let person: Person
    let radius: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [.blue.opacity(0.8), .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: .blue.opacity(0.3), radius: 10)
            
            if let imageData = person.profileImageData,
               let nsImage = NSImage(data: imageData) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: radius * 2 - 8, height: radius * 2 - 8)
                    .clipShape(Circle())
            } else {
                Text(String(person.name.prefix(1)))
                    .font(.system(size: radius * 0.8, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
    }
}

struct MacConnectedNode: View {
    let connection: PersonConnection
    let radius: CGFloat
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color(NSColor.controlBackgroundColor))
                    .frame(width: radius * 2, height: radius * 2)
                    .overlay(Circle().stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 3 : 1.5))
                
                if let imageData = connection.person.profileImageData,
                   let nsImage = NSImage(data: imageData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: radius * 2 - 6, height: radius * 2 - 6)
                        .clipShape(Circle())
                } else {
                    Text(String(connection.person.name.prefix(1)))
                        .font(.system(size: radius * 0.6, weight: .semibold))
                }
            }
            
            Text(connection.person.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isSelected ? .blue : .primary)
        }
    }
}
#endif

// MARK: - Preview

#Preview {
    RelationshipGraphView(person: Person(name: "홍길동"))
        .modelContainer(for: [Person.self, PersonTag.self])
}
