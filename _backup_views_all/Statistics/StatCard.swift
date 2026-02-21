//
//  StatCard.swift
//  RapportMap
//
//  숫자 + 라벨을 표시하는 통계 카드
//

import SwiftUI

/// 통계 숫자를 표시하는 카드 컴포넌트
struct StatisticsCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let color: Color
    var trend: Int? = nil  // 양수: 증가, 음수: 감소
    
    init(
        title: String,
        value: String,
        subtitle: String? = nil,
        icon: String,
        color: Color,
        trend: Int? = nil
    ) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.color = color
        self.trend = trend
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
                Spacer()
                if let trend = trend, trend != 0 {
                    trendBadge(trend)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private func trendBadge(_ trend: Int) -> some View {
        HStack(spacing: 2) {
            Image(systemName: trend > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2)
            Text("\(abs(trend))")
                .font(.caption.bold())
        }
        .foregroundStyle(trend > 0 ? .green : .red)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(trend > 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        )
    }
}

/// 비율을 표시하는 통계 카드
struct RatioCard: View {
    let title: String
    let ratio: Double  // 0.0 ~ 1.0
    let activeLabel: String
    let inactiveLabel: String
    let activeColor: Color
    let inactiveColor: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Progress Bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(inactiveColor.opacity(0.3))
                    
                    RoundedRectangle(cornerRadius: 8)
                        .fill(activeColor)
                        .frame(width: geometry.size.width * ratio)
                }
            }
            .frame(height: 12)
            
            // Legend
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 8, height: 8)
                    Text(activeLabel)
                        .font(.caption)
                    Text("\(Int(ratio * 100))%")
                        .font(.caption.bold())
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(inactiveColor)
                        .frame(width: 8, height: 8)
                    Text(inactiveLabel)
                        .font(.caption)
                    Text("\(Int((1 - ratio) * 100))%")
                        .font(.caption.bold())
                }
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Previews

#Preview("StatisticsCard") {
    VStack(spacing: 16) {
        StatisticsCard(
            title: "총 멘티 수",
            value: "24",
            subtitle: "활성 멘티 포함",
            icon: "person.3.fill",
            color: .blue,
            trend: 3
        )
        
        StatisticsCard(
            title: "이번 달 상담",
            value: "42",
            subtitle: "일평균 1.4회",
            icon: "message.fill",
            color: .green,
            trend: -5
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("RatioCard") {
    RatioCard(
        title: "멘티 활성화 비율",
        ratio: 0.75,
        activeLabel: "활성",
        inactiveLabel: "소홀",
        activeColor: .green,
        inactiveColor: .red
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
