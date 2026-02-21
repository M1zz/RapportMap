//
//  NotificationHistoryView.swift
//  RapportMap
//
//  Created by hyunho lee on 11/10/25.
//

import SwiftUI
import SwiftData

struct NotificationHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \NotificationHistory.deliveredDate, order: .reverse) private var allNotifications: [NotificationHistory]
    
    @State private var selectedFilter: NotificationFilterType = .all
    @State private var showingDeleteAlert = false
    
    enum NotificationFilterType: String, CaseIterable {
        case all = "전체"
        case unread = "읽지 않음"
        case criticalAction = "긴급 액션"
        case neglectedPerson = "소홀한 관계"
        case unansweredQuestion = "미답변 질문"
        case unresolvedPromise = "미해결 약속"
        
        var systemImage: String {
            switch self {
            case .all:
                return "list.bullet"
            case .unread:
                return "circle.fill"
            case .criticalAction:
                return "exclamationmark.triangle.fill"
            case .neglectedPerson:
                return "person.fill.xmark"
            case .unansweredQuestion:
                return "questionmark.circle.fill"
            case .unresolvedPromise:
                return "hand.raised.fill"
            }
        }
    }
    
    private var filteredNotifications: [NotificationHistory] {
        switch selectedFilter {
        case .all:
            return allNotifications
        case .unread:
            return allNotifications.filter { !$0.isRead }
        case .criticalAction:
            return allNotifications.filter { $0.notificationType == .criticalAction }
        case .neglectedPerson:
            return allNotifications.filter { $0.notificationType == .neglectedPerson }
        case .unansweredQuestion:
            return allNotifications.filter { $0.notificationType == .unansweredQuestion }
        case .unresolvedPromise:
            return allNotifications.filter { $0.notificationType == .unresolvedPromise }
        }
    }
    
    private var unreadCount: Int {
        allNotifications.filter { !$0.isRead }.count
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 필터 선택
                filterSelector
                
                // 알림 목록
                if filteredNotifications.isEmpty {
                    emptyStateView
                } else {
                    notificationList
                }
            }
            .navigationTitle("알림 히스토리")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("닫기") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("모두 읽음 표시") {
                            markAllAsRead()
                        }
                        .disabled(unreadCount == 0)
                        
                        Button("모두 삭제", role: .destructive) {
                            showingDeleteAlert = true
                        }
                        .disabled(allNotifications.isEmpty)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("모든 알림 삭제", isPresented: $showingDeleteAlert) {
                Button("취소", role: .cancel) { }
                Button("삭제", role: .destructive) {
                    deleteAllNotifications()
                }
            } message: {
                Text("모든 알림 히스토리를 삭제하시겠습니까?")
            }
        }
    }
    
    // MARK: - View Components
    
    @ViewBuilder
    private var filterSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(NotificationFilterType.allCases, id: \.self) { filter in
                    filterChip(for: filter)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    private func filterChip(for filter: NotificationFilterType) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedFilter = filter
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: filter.systemImage)
                    .font(.caption)
                
                Text(filter.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if filter == .all && unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(selectedFilter == filter ? Color.blue : Color(.secondarySystemGroupedBackground))
            )
            .foregroundStyle(selectedFilter == filter ? .white : .primary)
        }
    }
    
    @ViewBuilder
    private var notificationList: some View {
        List {
            ForEach(groupedNotifications.keys.sorted(by: >), id: \.self) { date in
                Section {
                    ForEach(groupedNotifications[date] ?? [], id: \.id) { notification in
                        NotificationHistoryRow(notification: notification)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteNotification(notification)
                                } label: {
                                    Label("삭제", systemImage: "trash")
                                }
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                if !notification.isRead {
                                    Button {
                                        markAsRead(notification)
                                    } label: {
                                        Label("읽음", systemImage: "checkmark.circle")
                                    }
                                    .tint(.blue)
                                }
                            }
                    }
                } header: {
                    Text(sectionHeaderText(for: date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            
            Text("알림이 없습니다")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("받은 알림이 여기에 표시됩니다")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private var groupedNotifications: [String: [NotificationHistory]] {
        Dictionary(grouping: filteredNotifications) { notification in
            dateGroupKey(for: notification.deliveredDate)
        }
    }
    
    private func dateGroupKey(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "today"
        } else if calendar.isDateInYesterday(date) {
            return "yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return "thisWeek"
        } else {
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }
    
    private func sectionHeaderText(for key: String) -> String {
        switch key {
        case "today":
            return "오늘"
        case "yesterday":
            return "어제"
        case "thisWeek":
            return "이번 주"
        default:
            return key
        }
    }
    
    private func markAsRead(_ notification: NotificationHistory) {
        withAnimation {
            notification.markAsRead()
            try? context.save()
        }
    }
    
    private func markAllAsRead() {
        withAnimation {
            for notification in allNotifications where !notification.isRead {
                notification.markAsRead()
            }
            try? context.save()
        }
    }
    
    private func deleteNotification(_ notification: NotificationHistory) {
        withAnimation {
            context.delete(notification)
            try? context.save()
        }
    }
    
    private func deleteAllNotifications() {
        withAnimation {
            for notification in allNotifications {
                context.delete(notification)
            }
            try? context.save()
        }
    }
}

// MARK: - Notification History Row

struct NotificationHistoryRow: View {
    @Bindable var notification: NotificationHistory
    @Environment(\.modelContext) private var context
    @Query private var people: [Person]
    
    private var associatedPerson: Person? {
        guard let personID = notification.personID else { return nil }
        return people.first { $0.id == personID }
    }
    
    var body: some View {
        NavigationLink {
            notificationDetailView
        } label: {
            HStack(spacing: 12) {
                // 아이콘
                notificationIcon
                
                // 내용
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundStyle(notification.isRead ? .secondary : .primary)
                        
                        if !notification.isRead {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }
                    }
                    
                    Text(notification.body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    
                    HStack(spacing: 8) {
                        if let personName = notification.personName {
                            Text(personName)
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Capsule())
                        }
                        
                        Text(notification.relativeTimeString)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 4)
        }
    }
    
    @ViewBuilder
    private var notificationIcon: some View {
        ZStack {
            Circle()
                .fill(iconColor.opacity(0.15))
                .frame(width: 44, height: 44)
            
            Image(systemName: notification.notificationType.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(iconColor)
        }
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
    
    @ViewBuilder
    private var notificationDetailView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // 헤더
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        notificationIcon
                        
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
                        
                        NavigationLink(destination: PersonDetailView(person: person)) {
                            HStack {
                                Text(person.name)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
        .onAppear {
            if !notification.isRead {
                notification.markAsRead()
                try? context.save()
            }
        }
    }
}

#Preview {
    NavigationStack {
        NotificationHistoryView()
    }
    .modelContainer(for: [NotificationHistory.self, Person.self])
}
