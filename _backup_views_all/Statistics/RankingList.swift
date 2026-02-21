//
//  RankingList.swift
//  RapportMap
//
//  TOP 5 리스트를 표시하는 컴포넌트
//

import SwiftUI

/// 멘티 순위 리스트
struct RankingList: View {
    let title: String
    let icon: String
    let iconColor: Color
    let data: [MenteeRank]
    let emptyMessage: String
    var valueFormatter: ((Int) -> String)? = nil
    var onTap: ((UUID) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 헤더
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            
            if data.isEmpty {
                emptyView
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                        RankingRow(
                            rank: index + 1,
                            item: item,
                            valueFormatter: valueFormatter
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap?(item.id)
                        }
                        
                        if index < data.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
    
    private var emptyView: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
}

/// 순위 행
struct RankingRow: View {
    let rank: Int
    let item: MenteeRank
    var valueFormatter: ((Int) -> String)?
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .secondary
        }
    }
    
    private var rankIcon: String {
        switch rank {
        case 1: return "medal.fill"
        case 2: return "medal.fill"
        case 3: return "medal.fill"
        default: return "\(rank).circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 순위 뱃지
            if rank <= 3 {
                Image(systemName: rankIcon)
                    .font(.title3)
                    .foregroundStyle(rankColor)
                    .frame(width: 28)
            } else {
                Text("\(rank)")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
            }
            
            // 프로필 이미지
            ProfileImage(imageData: item.imageData, size: 36)
            
            // 이름 및 서브타이틀
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // 값
            Text(valueFormatter?(item.value) ?? "\(item.value)")
                .font(.subheadline.monospacedDigit())
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 4)
    }
}

/// 프로필 이미지 컴포넌트
struct ProfileImage: View {
    let imageData: Data?
    let size: CGFloat
    
    var body: some View {
        Group {
            if let data = imageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.gray.opacity(0.5))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

// MARK: - Previews

#Preview("RankingList") {
    let sampleData = [
        MenteeRank(id: UUID(), name: "김철수", value: 12, subtitle: "이번 달 12회 상담", imageData: nil),
        MenteeRank(id: UUID(), name: "이영희", value: 10, subtitle: "이번 달 10회 상담", imageData: nil),
        MenteeRank(id: UUID(), name: "박지민", value: 8, subtitle: "이번 달 8회 상담", imageData: nil),
        MenteeRank(id: UUID(), name: "최수진", value: 6, subtitle: "이번 달 6회 상담", imageData: nil),
        MenteeRank(id: UUID(), name: "정민호", value: 5, subtitle: "이번 달 5회 상담", imageData: nil)
    ]
    
    return RankingList(
        title: "가장 많이 상담한 멘티",
        icon: "flame.fill",
        iconColor: .orange,
        data: sampleData,
        emptyMessage: "아직 상담 기록이 없습니다"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("RankingList - Empty") {
    RankingList(
        title: "가장 많이 상담한 멘티",
        icon: "flame.fill",
        iconColor: .orange,
        data: [],
        emptyMessage: "아직 상담 기록이 없습니다"
    )
    .padding()
    .background(Color(.systemGroupedBackground))
}
