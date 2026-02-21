//
//  MentoringProgressChartView.swift
//  RapportMap
//
//  멘토링 변화 추이 그래프
//

import SwiftUI
import Charts

struct MentoringProgressChartView: View {
    let sessions: [MentoringSession]
    @State private var selectedMetric: MetricType = .overall

    enum MetricType: String, CaseIterable {
        case overall = "전반적인 삶"
        case personal = "개인 삶"
        case relationship = "관계"
        case academy = "아카데미"

        var color: Color {
            switch self {
            case .overall: return .blue
            case .personal: return .green
            case .relationship: return .orange
            case .academy: return .purple
            }
        }

        func value(from form: PreMentoringForm) -> Int {
            switch self {
            case .overall: return form.overallLifeSatisfaction
            case .personal: return form.personalLifeSatisfaction
            case .relationship: return form.relationshipSatisfaction
            case .academy: return form.academySatisfaction
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            // 철학 메시지
            philosophyCard

            // 메트릭 선택
            metricSelector

            // 그래프
            if !sessions.isEmpty {
                chartView
            } else {
                emptyStateView
            }

            // 변화율 표시
            if sessions.count >= 2 {
                changeRateCard
            }

            // 최근 기록
            recentSessionsCard
        }
    }

    // MARK: - 철학 메시지

    private var philosophyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundStyle(.blue)
                Text("변화 추이의 중요성")
                    .font(.headline)
            }

            Text(MentoringPhilosophy.shortMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 메트릭 선택기

    private var metricSelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("측정 항목")
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("측정 항목", selection: $selectedMetric) {
                ForEach(MetricType.allCases, id: \.self) { metric in
                    Text(metric.rawValue)
                        .tag(metric)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - 차트

    private var chartView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("만족도 변화")
                    .font(.headline)
                Spacer()
                Text("최근 \(sessions.count)회")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Chart {
                ForEach(Array(sessions.enumerated()), id: \.element.id) { index, session in
                    let value = selectedMetric.value(from: session.preMentoring)

                    LineMark(
                        x: .value("세션", index + 1),
                        y: .value("만족도", value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("세션", index + 1),
                        y: .value("만족도", value)
                    )
                    .foregroundStyle(selectedMetric.color)
                    .symbolSize(100)
                }
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 2, 4, 6, 8, 10])
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: min(sessions.count, 10)))
            }
            .frame(height: 250)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.xyaxis.line")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("아직 기록이 없습니다")
                .font(.headline)

            Text("멘토링 세션을 기록하면\n변화 추이를 확인할 수 있습니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 250)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - 변화율 카드

    private var changeRateCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(changeRate >= 0 ? .green : .red)
                Text("변화율")
                    .font(.headline)
            }

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("첫 기록")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(firstValue)/10")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Image(systemName: changeRate >= 0 ? "arrow.right" : "arrow.down.right")
                    .foregroundStyle(changeRate >= 0 ? .green : .red)

                VStack(alignment: .leading, spacing: 4) {
                    Text("최근 기록")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(lastValue)/10")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(changeRate >= 0 ? .green : .red)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("변화")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(changeRate >= 0 ? "+\(changeRate)" : "\(changeRate)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(changeRate >= 0 ? .green : .red)
                }
            }

            // 변화율 해석
            Text(changeRateInterpretation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(changeRate >= 0 ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(changeRate >= 0 ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var firstValue: Int {
        guard let first = sessions.first else { return 0 }
        return selectedMetric.value(from: first.preMentoring)
    }

    private var lastValue: Int {
        guard let last = sessions.last else { return 0 }
        return selectedMetric.value(from: last.preMentoring)
    }

    private var changeRate: Int {
        lastValue - firstValue
    }

    private var changeRateInterpretation: String {
        let avgChangePerSession = sessions.count > 1 ? Double(changeRate) / Double(sessions.count - 1) : 0

        if avgChangePerSession > 0.5 {
            return "🚀 그래프가 가파르게 상승하고 있습니다! 지금처럼 계속 성장하세요."
        } else if avgChangePerSession > 0.2 {
            return "📈 꾸준히 성장하고 있습니다. 좋은 흐름입니다!"
        } else if avgChangePerSession >= -0.2 {
            return "⚠️ 제자리 걸음 중입니다. 변화를 위한 새로운 시도가 필요할 수 있습니다."
        } else {
            return "📉 만족도가 하락하고 있습니다. 멘토와 함께 원인을 찾아보세요."
        }
    }

    // MARK: - 최근 세션

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("최근 기록")
                .font(.headline)

            if sessions.isEmpty {
                Text("아직 기록이 없습니다")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(sessions.suffix(3).reversed()), id: \.id) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func sessionRow(_ session: MentoringSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionDate.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !session.postMentoring.meaningfulSummary.isEmpty {
                    Text(session.postMentoring.meaningfulSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text("\(selectedMetric.value(from: session.preMentoring))/10")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(selectedMetric.color)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct MentoringProgressChartView_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            MentoringProgressChartView(sessions: sampleSessions)
                .padding()
        }
    }

    static var sampleSessions: [MentoringSession] {
        [
            MentoringSession(
                sessionDate: Date().addingTimeInterval(-86400 * 21),
                preMentoring: PreMentoringForm(
                    personalLifeSatisfaction: 5,
                    relationshipSatisfaction: 4,
                    academySatisfaction: 6,
                    overallLifeSatisfaction: 5
                )
            ),
            MentoringSession(
                sessionDate: Date().addingTimeInterval(-86400 * 14),
                preMentoring: PreMentoringForm(
                    personalLifeSatisfaction: 6,
                    relationshipSatisfaction: 5,
                    academySatisfaction: 7,
                    overallLifeSatisfaction: 6
                )
            ),
            MentoringSession(
                sessionDate: Date().addingTimeInterval(-86400 * 7),
                preMentoring: PreMentoringForm(
                    personalLifeSatisfaction: 7,
                    relationshipSatisfaction: 6,
                    academySatisfaction: 8,
                    overallLifeSatisfaction: 7
                )
            ),
        ]
    }
}
