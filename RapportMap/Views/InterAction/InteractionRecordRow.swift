//
//  InteractionRecordRow.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI
import SwiftData

// MARK: - InteractionRecordRow
struct InteractionRecordRow: View {
    let record: InteractionRecord
    @Environment(\.modelContext) private var context
    @State private var showingEditSheet = false
    
    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: record.date, relativeTo: .now)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // 타입 아이콘 및 색상
            VStack {
                Circle()
                    .fill(record.type.color)
                    .frame(width: 8, height: 8)
                
                Rectangle()
                    .fill(record.type.color.opacity(0.3))
                    .frame(width: 2)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 12)
            
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(record.type.title)
                        .font(.headline)
                        .foregroundStyle(record.type.color)
                    
                    if record.isRecent {
                        Text("최근")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.green))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                }
                
                Text(relativeDate)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                // 추가 정보들
                VStack(alignment: .leading, spacing: 4) {
                    if let duration = record.formattedDuration {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("지속 시간: \(duration)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let location = record.location, !location.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text("장소: \(location)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    if let notes = record.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(record.type.color.opacity(0.1))
                            )
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            
            VStack {
                Button {
                    showingEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title3)
                        .foregroundStyle(record.type.color)
                }
                .buttonStyle(.plain)
                
                Button(role: .destructive) {
                    withAnimation {
                        context.delete(record)
                        try? context.save()
                    }
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingEditSheet) {
            EditInteractionRecordSheet(record: record)
        }
    }
}
