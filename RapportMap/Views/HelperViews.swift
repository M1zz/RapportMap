//
//  HelperViews.swift
//  RapportMap
//
//  Created by hyunho lee on 11/8/25.
//

import SwiftUI

// MARK: - Helper Views
struct KnowledgeItemView: View {
    let personAction: PersonAction
    let action: RapportAction
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.caption)
                    .foregroundStyle(.blue)
                
                Text(action.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Text("정보")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.2)))
                    .foregroundStyle(.blue)
            }
            
            Text(personAction.context)
                .font(.subheadline)
                .foregroundStyle(.primary)
            
            if let completedDate = personAction.completedDate {
                Text("완료: \(completedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct EditableConversationField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
    }
}

struct ConversationCard: View {
    let icon: String
    let title: String
    let content: String?
    let color: Color
    
    var body: some View {
        if let content = content, !content.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.caption)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(color)
                }
                Text(content)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(color.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }
}

struct EmptyPeopleView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.crop.circle.badge.questionmark")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("아직 등록된 사람이 없어요.")
                .font(.headline)
            Text("상단의 + 버튼을 눌러 새로운 관계를 추가해보세요.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }
}
