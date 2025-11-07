//
//  RelationshipAnalysisCard.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI

// MARK: - RelationshipAnalysisCard
struct RelationshipAnalysisCard: View {
    @Bindable var person: Person
    @State private var showingDetailedAnalysis = false
    
    // 실시간으로 계산되는 analysis
    private var analysis: RelationshipAnalysis {
        person.getRelationshipAnalysis()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 상태 요약
            HStack {
                Text(analysis.currentState.emoji)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(analysis.currentState.localizedName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text("점수: \(Int(analysis.currentScore))/100")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Button {
                    showingDetailedAnalysis = true
                } label: {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundStyle(.blue)
                }
            }
            
            // 진행률 바
            ProgressView(value: analysis.currentScore, total: 100) {
                Text("관계 건강도")
                    .font(.caption)
            } currentValueLabel: {
                Text("\(Int(analysis.currentScore))%")
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .tint(progressColor(for: analysis.currentScore))
            
            // 빠른 인사이트
            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 추천")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    
                    Text(analysis.recommendations.first ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            
            // 마지막 상호작용
            if analysis.daysSinceLastInteraction > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Text("마지막 상호작용: \(analysis.daysSinceLastInteraction)일 전")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .sheet(isPresented: $showingDetailedAnalysis) {
            DetailedRelationshipAnalysisView(person: person, analysis: analysis)
        }
    }
    
    private func progressColor(for score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - DetailedRelationshipAnalysisView
struct DetailedRelationshipAnalysisView: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let analysis: RelationshipAnalysis
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 현재 상태 카드
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(analysis.currentState.emoji)
                                .font(.largeTitle)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(analysis.currentState.rawValue)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("현재 점수: \(Int(analysis.currentScore))/100")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Text(analysis.currentState.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                        
                        ProgressView(value: analysis.currentScore, total: 100)
                            .tint(progressColor(for: analysis.currentScore))
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 상세 지표들
                    VStack(alignment: .leading, spacing: 16) {
                        Text("📊 상세 분석")
                            .font(.headline)
                        
                        MetricRow(
                            title: "전체 액션 완료율",
                            value: analysis.actionCompletionRate,
                            icon: "checkmark.circle",
                            color: .blue
                        )
                        
                        MetricRow(
                            title: "중요 액션 완료율",
                            value: analysis.criticalActionCompletionRate,
                            icon: "exclamationmark.triangle",
                            color: .orange
                        )
                        
                        HStack {
                            Image(systemName: "clock")
                                .foregroundStyle(.gray)
                            Text("마지막 상호작용")
                            Spacer()
                            Text("\(analysis.daysSinceLastInteraction)일 전")
                                .fontWeight(.semibold)
                                .foregroundStyle(analysis.daysSinceLastInteraction > 14 ? .red : .secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // 추천사항
                    if !analysis.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("💡 관계 개선 추천")
                                .font(.headline)
                            
                            ForEach(Array(analysis.recommendations.enumerated()), id: \.offset) { index, recommendation in
                                HStack(alignment: .top, spacing: 8) {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                        .foregroundStyle(.orange)
                                    
                                    Text(recommendation)
                                        .font(.body)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("\(person.name) 관계 분석")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
    
    private func progressColor(for score: Double) -> Color {
        switch score {
        case 70...: return .green
        case 40..<70: return .orange
        default: return .red
        }
    }
}

// MARK: - MetricRow
struct MetricRow: View {
    let title: String
    let value: Double
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
            
            Text(title)
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(Int(value * 100))%")
                    .fontWeight(.semibold)
                
                ProgressView(value: value, total: 1.0)
                    .frame(width: 50)
                    .tint(color)
            }
        }
    }
}
