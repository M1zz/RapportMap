//
//  ChartComponents.swift
//  RapportMap
//
//  Swift Charts를 활용한 차트 컴포넌트들
//

import SwiftUI
import Charts

// MARK: - Weekly Bar Chart

/// 주간 상담 추이를 보여주는 막대 그래프
struct WeeklyBarChart: View {
    let data: [DailyInteraction]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("주간 상담 추이")
                .font(.headline)
            
            Chart(data) { item in
                BarMark(
                    x: .value("요일", item.dayOfWeek),
                    y: .value("상담 수", item.count)
                )
                .foregroundStyle(
                    item.date.isToday ? Color.blue : Color.blue.opacity(0.6)
                )
                .cornerRadius(4)
                .annotation(position: .top, spacing: 4) {
                    if item.count > 0 {
                        Text("\(item.count)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
            .frame(height: 180)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Tag Distribution Pie Chart

/// 태그별 분포를 보여주는 파이 차트
struct TagDistributionChart: View {
    let data: [TagStatItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("태그별 분포")
                .font(.headline)
            
            HStack(spacing: 20) {
                // 파이 차트
                Chart(data) { item in
                    SectorMark(
                        angle: .value("멘티 수", item.count),
                        innerRadius: .ratio(0.5),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(Color(hex: item.tagColor) ?? .gray)
                }
                .frame(width: 120, height: 120)
                
                // 범례
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data.prefix(5)) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color(hex: item.tagColor) ?? .gray)
                                .frame(width: 10, height: 10)
                            
                            Text(item.tagName)
                                .font(.caption)
                                .lineLimit(1)
                            
                            Spacer()
                            
                            Text("\(item.count)명")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if data.count > 5 {
                        Text("외 \(data.count - 5)개...")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Interaction Type Chart

/// 상호작용 타입별 통계를 보여주는 가로 막대 그래프
struct InteractionTypeChart: View {
    let data: [InteractionTypeStat]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("상호작용 유형")
                .font(.headline)
            
            Chart(data) { item in
                BarMark(
                    x: .value("횟수", item.count),
                    y: .value("유형", item.type.title)
                )
                .foregroundStyle(item.type.color.gradient)
                .cornerRadius(4)
                .annotation(position: .trailing, spacing: 4) {
                    Text("\(item.count)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks { value in
                    AxisValueLabel()
                }
            }
            .frame(height: CGFloat(data.count * 36 + 20))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Month Comparison Chart

/// 이번 달 vs 지난 달 비교 차트
struct MonthComparisonChart: View {
    let thisMonth: Int
    let lastMonth: Int
    
    private var data: [(label: String, value: Int, color: Color)] {
        [
            ("지난 달", lastMonth, .gray),
            ("이번 달", thisMonth, .blue)
        ]
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("월별 비교")
                .font(.headline)
            
            Chart {
                ForEach(data, id: \.label) { item in
                    BarMark(
                        x: .value("월", item.label),
                        y: .value("상담 수", item.value)
                    )
                    .foregroundStyle(item.color.gradient)
                    .cornerRadius(8)
                    .annotation(position: .top, spacing: 4) {
                        Text("\(item.value)회")
                            .font(.caption.bold())
                            .foregroundStyle(item.color)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .frame(height: 160)
            
            // Growth indicator
            HStack {
                Image(systemName: thisMonth >= lastMonth ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                    .foregroundStyle(thisMonth >= lastMonth ? .green : .red)
                
                let diff = thisMonth - lastMonth
                let percentage = lastMonth > 0 ? abs(diff) * 100 / lastMonth : (diff > 0 ? 100 : 0)
                Text(diff >= 0 ? "+\(diff)회 (\(percentage)% 증가)" : "\(diff)회 (\(percentage)% 감소)")
                    .font(.caption)
                    .foregroundStyle(thisMonth >= lastMonth ? .green : .red)
                
                Spacer()
            }
            .padding(.top, 4)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }
}

// MARK: - Date Extension

extension Date {
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
}

// MARK: - Previews

#Preview("WeeklyBarChart") {
    let sampleData = (0..<7).map { i in
        DailyInteraction(
            date: Calendar.current.date(byAdding: .day, value: -6 + i, to: Date())!,
            count: Int.random(in: 0...5),
            dayOfWeek: ["일", "월", "화", "수", "목", "금", "토"][i]
        )
    }
    
    return WeeklyBarChart(data: sampleData)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("TagDistributionChart") {
    let sampleData = [
        TagStatItem(tagName: "1기", tagColor: "#007AFF", count: 8, percentage: 33),
        TagStatItem(tagName: "2기", tagColor: "#5856D6", count: 6, percentage: 25),
        TagStatItem(tagName: "개발", tagColor: "#32ADE6", count: 5, percentage: 21),
        TagStatItem(tagName: "디자인", tagColor: "#FF2D55", count: 3, percentage: 13),
        TagStatItem(tagName: "태그 없음", tagColor: "#8E8E93", count: 2, percentage: 8)
    ]
    
    return TagDistributionChart(data: sampleData)
        .padding()
        .background(Color(.systemGroupedBackground))
}

#Preview("MonthComparisonChart") {
    MonthComparisonChart(thisMonth: 42, lastMonth: 35)
        .padding()
        .background(Color(.systemGroupedBackground))
}
