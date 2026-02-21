//
//  FogRevealEffect.swift
//  RapportMap
//
//  안개 걷힘 & 발견 애니메이션 효과
//

import SwiftUI

// MARK: - 안개 오버레이

struct FogOverlay: View {
    let depth: RelationshipDepth
    let isAccessible: Bool
    
    @State private var animateNoise = false
    
    var body: some View {
        ZStack {
            // 기본 안개
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            Color.gray.opacity(isAccessible ? 0 : depth.fogOpacity * 0.7),
                            Color.gray.opacity(isAccessible ? 0 : depth.fogOpacity * 0.3)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: 30
                    )
                )
            
            // 움직이는 안개 효과 (잠긴 영역)
            if !isAccessible {
                Circle()
                    .fill(Color.gray.opacity(0.2))
                    .blur(radius: 8)
                    .scaleEffect(animateNoise ? 1.1 : 0.9)
            }
        }
        .onAppear {
            if !isAccessible {
                withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) {
                    animateNoise = true
                }
            }
        }
    }
}

// MARK: - 발견 반짝임 효과

struct DiscoverySparkle: View {
    let isActive: Bool
    
    @State private var sparkleScale: CGFloat = 1.0
    @State private var sparkleOpacity: Double = 0.8
    @State private var rotation: Double = 0
    
    var body: some View {
        ZStack {
            // 외곽 글로우
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [.yellow, .orange, .yellow],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .scaleEffect(sparkleScale)
                .opacity(sparkleOpacity)
            
            // 별 모양 반짝임
            ForEach(0..<4, id: \.self) { i in
                Rectangle()
                    .fill(Color.yellow.opacity(0.6))
                    .frame(width: 2, height: 12)
                    .offset(y: -20)
                    .rotationEffect(.degrees(Double(i) * 90 + rotation))
            }
        }
        .opacity(isActive ? 1 : 0)
        .onAppear {
            guard isActive else { return }
            
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                sparkleScale = 1.3
                sparkleOpacity = 0.3
            }
            
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

// MARK: - 새 발견 축하 효과

struct NewDiscoveryEffect: View {
    @Binding var isShowing: Bool
    let territory: Territory
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var particleOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 배경 딤
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .opacity(opacity)
            
            // 중앙 카드
            VStack(spacing: 20) {
                // 이모지 + 반짝임
                ZStack {
                    // 파티클 효과
                    ForEach(0..<8, id: \.self) { i in
                        Circle()
                            .fill(territory.depth.color)
                            .frame(width: 8, height: 8)
                            .offset(y: CGFloat(-50) - particleOffset)
                            .rotationEffect(.degrees(Double(i) * 45))
                            .opacity(Double(1) - Double(particleOffset / 50))
                    }
                    
                    Text(territory.emoji)
                        .font(.system(size: 60))
                }
                
                Text("새로운 발견!")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text(territory.title)
                    .font(.headline)
                    .foregroundStyle(territory.depth.color)
                
                Text("영역이 밝혀졌어요 ✨")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(40)
            .background(Color.primaryBackground)
            .cornerRadius(24)
            .shadow(radius: 20)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.easeOut(duration: 1).repeatCount(3, autoreverses: false)) {
                particleOffset = 50
            }
            
            // 자동으로 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 0.8
                    opacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isShowing = false
                }
            }
        }
        .onTapGesture {
            withAnimation(.easeOut(duration: 0.2)) {
                scale = 0.8
                opacity = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                isShowing = false
            }
        }
    }
}

// MARK: - 달 차오름 애니메이션

struct MoonPhaseAnimation: View {
    let progress: Double  // 0.0 ~ 1.0
    
    @State private var glowOpacity: Double = 0.3
    
    private var moonEmoji: String {
        switch progress {
        case 0..<0.15: return "🌑"
        case 0.15..<0.35: return "🌒"
        case 0.35..<0.55: return "🌓"
        case 0.55..<0.75: return "🌔"
        case 0.75..<0.90: return "🌖"
        default: return "🌕"
        }
    }
    
    var body: some View {
        ZStack {
            // 글로우 효과
            Circle()
                .fill(Color.yellow.opacity(glowOpacity * progress))
                .blur(radius: 15)
                .frame(width: 50, height: 50)
            
            // 달 이모지
            Text(moonEmoji)
                .font(.system(size: 32))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowOpacity = 0.6
            }
        }
    }
}

// MARK: - 영역 잠금 해제 효과

struct UnlockEffect: View {
    @Binding var isShowing: Bool
    let depth: RelationshipDepth
    
    @State private var lockScale: CGFloat = 1.0
    @State private var lockRotation: Double = 0
    @State private var showUnlocked = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    // 자물쇠 → 열린 자물쇠
                    Image(systemName: showUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(depth.color)
                        .scaleEffect(lockScale)
                        .rotationEffect(.degrees(lockRotation))
                }
                
                if showUnlocked {
                    VStack(spacing: 8) {
                        Text("\(depth.icon) \(depth.title)")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("새로운 영역이 열렸어요!")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(40)
            .background(Color.primaryBackground)
            .cornerRadius(24)
        }
        .onAppear {
            // 자물쇠 흔들기
            withAnimation(.easeInOut(duration: 0.1).repeatCount(6, autoreverses: true)) {
                lockRotation = 10
            }
            
            // 자물쇠 열기
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                    lockScale = 1.2
                    showUnlocked = true
                }
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7).delay(0.1)) {
                    lockScale = 1.0
                    lockRotation = 0
                }
            }
            
            // 자동 닫기
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    isShowing = false
                }
            }
        }
        .onTapGesture {
            withAnimation {
                isShowing = false
            }
        }
    }
}

// MARK: - Preview

#Preview("Fog Overlay") {
    HStack(spacing: 20) {
        ForEach(RelationshipDepth.allCases, id: \.self) { depth in
            VStack {
                ZStack {
                    Circle()
                        .fill(depth.color.opacity(0.2))
                        .frame(width: 60, height: 60)
                    
                    FogOverlay(depth: depth, isAccessible: depth == .surface)
                        .frame(width: 60, height: 60)
                }
                
                Text(depth.title)
                    .font(.caption)
            }
        }
    }
    .padding()
}

#Preview("Discovery Sparkle") {
    ZStack {
        Circle()
            .fill(Color.orange.opacity(0.2))
            .frame(width: 60, height: 60)
        
        DiscoverySparkle(isActive: true)
            .frame(width: 60, height: 60)
        
        Text("⭐️")
            .font(.title)
    }
}

#Preview("New Discovery") {
    NewDiscoveryEffect(isShowing: .constant(true), territory: .nickname)
}

#Preview("Moon Phase") {
    VStack(spacing: 20) {
        ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { progress in
            HStack {
                MoonPhaseAnimation(progress: progress)
                Text("\(Int(progress * 100))%")
            }
        }
    }
}
