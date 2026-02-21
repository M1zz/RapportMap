//
//  PersonDetailView+Components.swift
//  RapportMap
//
//  분할된 파일: 재사용 가능한 컴포넌트들
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Important Record Row Views

struct ImportantInteractionRow: View {
    let interaction: InteractionRecord
    @State private var isNewlyAdded = false
    
    var body: some View {
        HStack(spacing: 12) {
            // 상호작용 타입 아이콘
            ZStack {
                Circle()
                    .fill(interaction.type.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: interaction.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(interaction.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(interaction.type.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 중요 표시
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    
                    // 새로 추가된 항목 표시
                    if isRecentlyAdded(interaction.date) {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(for: interaction.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if let notes = interaction.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                if let duration = interaction.formattedDuration {
                    Text("지속시간: \(duration)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded(interaction.date) ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    // 최근 5분 내에 추가된 항목인지 확인
    private func isRecentlyAdded(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 300 // 5분 = 300초
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ImportantMeetingRow: View {
    let meeting: MeetingRecord
    
    var body: some View {
        HStack(spacing: 12) {
            // 미팅 타입 아이콘
            ZStack {
                Circle()
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Text(meeting.meetingType.emoji)
                    .font(.system(size: 16))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(meeting.meetingType.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 중요 표시
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    
                    // 오디오 파일 있음 표시
                    if meeting.hasAudio {
                        Image(systemName: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    
                    // 새로 추가된 항목 표시
                    if isRecentlyAdded(meeting.date) {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(for: meeting.date))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                if !meeting.transcribedText.isEmpty {
                    Text(meeting.transcribedText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                
                Text("길이: \(meeting.formattedDuration)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded(meeting.date) ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    // 최근 5분 내에 추가된 항목인지 확인
    private func isRecentlyAdded(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 300 // 5분 = 300초
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ImportantConversationRow: View {
    let conversation: ConversationRecord
    @Environment(\.modelContext) private var context
    
    var body: some View {
        HStack(spacing: 12) {
            // 대화 타입 아이콘
            ZStack {
                Circle()
                    .fill(conversation.type.color.opacity(0.1))
                    .frame(width: 32, height: 32)
                
                Image(systemName: conversation.type.systemImage)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(conversation.type.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.type.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    // 중요 표시
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                    
                    // 우선순위 표시 (긴급/높음일 때만)
                    if conversation.priority == .urgent || conversation.priority == .high {
                        Text(conversation.priority.emoji)
                            .font(.caption2)
                    }
                    
                    // 새로 추가된 항목 표시
                    if isRecentlyAdded(conversation.createdDate) {
                        Text("NEW")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    
                    Spacer()
                    
                    Text(relativeDateString(for: conversation.createdDate))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // 대화 내용
                Text(conversation.content)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                
                // 미해결 상태 표시 (해결된 것은 이미 목록에서 제외됨)
                Text("⏳ 미해결")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            // 해결 체크 버튼
            Button {
                toggleResolvedStatus()
            } label: {
                ZStack {
                    Circle()
                        .fill(conversation.isResolved ? Color.green : Color.clear)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(conversation.isResolved ? Color.green : Color.gray, lineWidth: 2)
                        )
                    
                    if conversation.isResolved {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .background(isRecentlyAdded(conversation.createdDate) ? Color.orange.opacity(0.05) : Color.clear)
        .cornerRadius(8)
    }
    
    private func toggleResolvedStatus() {
        // 해결 상태를 토글하고 해결 날짜 설정
        conversation.isResolved.toggle()
        
        if conversation.isResolved {
            conversation.resolvedDate = Date()
        } else {
            conversation.resolvedDate = nil
        }
        
        // 데이터베이스 저장
        try? context.save()
        
        // 해결된 경우 UI에서 사라지도록 새로고침 알림 발송
        if conversation.isResolved {
            NotificationCenter.default.post(
                name: .importantRecordingAdded,
                object: conversation.person
            )
        }
        
        // 햅틱 피드백
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        let status = conversation.isResolved ? "해결됨 (목록에서 숨김)" : "미해결"
        print("✅ \(conversation.type.title) '\(conversation.content)' 상태: \(status)")
    }
    
    // 최근 5분 내에 추가된 항목인지 확인
    private func isRecentlyAdded(_ date: Date) -> Bool {
        Date().timeIntervalSince(date) < 300 // 5분 = 300초
    }
    
    private func relativeDateString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Upcoming Event Row

struct UpcomingEventRow: View {
    let event: EKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 날짜 및 시간
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.startDate, style: .date)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                    Text(event.startDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // 소요 시간
                if let endDate = event.endDate {
                    let duration = Int(endDate.timeIntervalSince(event.startDate) / 60)
                    Text("\(duration)분")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.blue.opacity(0.1))
                        )
                }
            }

            // 제목
            if let title = event.title {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
            }

            // 메모
            if let notes = event.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.blue.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Badge Card Component
struct BadgeCard: View {
    let count: Int
    let title: String
    let color: Color
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                // 아이콘과 숫자
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.title2)
                    Text("\(count)")
                        .font(.title)
                        .fontWeight(.bold)
                }
                .foregroundStyle(color)

                // 제목
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(minWidth: 100)
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(color.opacity(0.4), lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Badge Row
struct NotificationBadgeRow: View {
    let notification: NotificationHistory
    let action: () -> Void

    private var iconColor: Color {
        switch notification.notificationType.color {
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        default: return .gray
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 아이콘
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 44, height: 44)

                    Image(systemName: notification.notificationType.icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)

                    Text(notification.body)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    Text(notification.relativeTimeString)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Notification Detail Sheet
struct NotificationDetailSheet: View {
    let notification: NotificationHistory
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var people: [Person]

    private var associatedPerson: Person? {
        guard let personID = notification.personID else { return nil }
        return people.first { $0.id == personID }
    }

    private var iconColor: Color {
        switch notification.notificationType.color {
        case "red": return .red
        case "orange": return .orange
        case "blue": return .blue
        case "purple": return .purple
        case "green": return .green
        default: return .gray
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 헤더
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(iconColor.opacity(0.15))
                                    .frame(width: 60, height: 60)

                                Image(systemName: notification.notificationType.icon)
                                    .font(.system(size: 28, weight: .medium))
                                    .foregroundStyle(iconColor)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(notification.notificationType.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                Text(notification.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }

                            Spacer()
                        }

                        Text(notification.deliveredDate.formatted(date: .long, time: .shortened))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // 알림 내용
                    VStack(alignment: .leading, spacing: 12) {
                        Text("내용")
                            .font(.headline)

                        Text(notification.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)

                    // 연결된 사람 정보
                    if let person = associatedPerson {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("관련 인물")
                                .font(.headline)

                            HStack {
                                Text(person.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)

                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }

                    // 액션 정보
                    if let actionTitle = notification.actionTitle {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("관련 액션")
                                .font(.headline)

                            Text(actionTitle)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("알림 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        // 알림을 읽음으로 표시
                        notification.markAsRead()
                        try? context.save()
                        dismiss()
                    }
                }
            }
            .onAppear {
                if !notification.isRead {
                    notification.markAsRead()
                    try? context.save()
                }
            }
        }
    }
}
