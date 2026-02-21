//
//  MacPersonCalendarTab.swift
//  mac
//
//  macOS용 Person 캘린더 탭
//

import SwiftUI
import SwiftData
import EventKit

// MARK: - Calendar Tab

struct MacPersonCalendarTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var calendarManager = CalendarManager.shared
    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showingAddEvent = false

    private var calendar: Calendar {
        Calendar.current
    }

    // 선택된 날짜의 이벤트들
    private var eventsForSelectedDate: [CalendarEvent] {
        let events = getCalendarEvents()
        return events.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            .sorted { $0.date < $1.date }
    }

    var body: some View {
        HStack(spacing: 0) {
            // 왼쪽: 캘린더
            VStack(spacing: 0) {
                // 월 네비게이션
                monthNavigationBar

                Divider()

                // 캘린더 그리드
                calendarGrid
                    .padding()
            }
            .frame(width: 400)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 오른쪽: 선택된 날짜의 일정
            VStack(spacing: 0) {
                // 선택된 날짜 헤더
                selectedDateHeader

                Divider()

                // 일정 목록
                if eventsForSelectedDate.isEmpty {
                    emptyEventsView
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(eventsForSelectedDate) { event in
                                CalendarEventRow(event: event)
                            }
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // MARK: - View Components

    @ViewBuilder
    private var monthNavigationBar: some View {
        HStack {
            Button {
                changeMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(currentMonth, format: .dateTime.year().month(.wide))
                .font(.headline)

            Spacer()

            Button {
                changeMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }

            Button {
                currentMonth = Date()
                selectedDate = Date()
            } label: {
                Text("오늘")
            }
        }
        .padding()
    }

    @ViewBuilder
    private var calendarGrid: some View {
        VStack(spacing: 8) {
            // 요일 헤더
            weekdayHeader

            // 날짜 그리드
            let days = generateDaysInMonth()
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                ForEach(days, id: \.self) { date in
                    if let date = date {
                        calendarDayCell(for: date)
                    } else {
                        Color.clear
                            .frame(height: 60)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(calendar.shortWeekdaySymbols, id: \.self) { weekday in
                Text(weekday)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private func calendarDayCell(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let isCurrentMonth = calendar.isDate(date, equalTo: currentMonth, toGranularity: .month)
        let eventCount = getEventCount(for: date)

        VStack(spacing: 4) {
            Text("\(calendar.component(.day, from: date))")
                .font(.subheadline)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(isCurrentMonth ? .primary : .secondary)

            if eventCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(eventCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 4, height: 4)
                    }
                    if eventCount > 3 {
                        Text("+")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.2) : (isToday ? Color.green.opacity(0.1) : Color.clear))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue : (isToday ? Color.green : Color.clear), lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }

    @ViewBuilder
    private var selectedDateHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate, format: .dateTime.year().month().day())
                    .font(.headline)
                Text(selectedDate, format: .dateTime.weekday(.wide))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(eventsForSelectedDate.count)개 일정")
                .font(.caption)
                .foregroundStyle(.secondary)

            Button {
                showingAddEvent = true
            } label: {
                Label("일정 추가", systemImage: "plus.circle.fill")
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .sheet(isPresented: $showingAddEvent) {
            MacAddEventSheet(person: person, selectedDate: selectedDate) { _ in
                // 일정 추가 후 새로고침
            }
        }
    }

    @ViewBuilder
    private var emptyEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("이 날짜에 일정이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)

            Button {
                showingAddEvent = true
            } label: {
                Label("일정 추가하기", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Methods

    private func changeMonth(by months: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: months, to: currentMonth) {
            currentMonth = newMonth
        }
    }

    private func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let monthFirstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start) else {
            return []
        }

        var days: [Date?] = []
        let monthEnd = monthInterval.end
        var currentDate = monthFirstWeek.start

        while currentDate < monthEnd {
            if calendar.isDate(currentDate, equalTo: monthInterval.start, toGranularity: .month) {
                days.append(currentDate)
            } else if currentDate < monthInterval.start {
                days.append(nil)
            } else {
                break
            }

            if let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) {
                currentDate = nextDate
            } else {
                break
            }
        }

        // 마지막 주 채우기
        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }

    private func getEventCount(for date: Date) -> Int {
        let events = getCalendarEvents()
        return events.filter { calendar.isDate($0.date, inSameDayAs: date) }.count
    }

    private func getCalendarEvents() -> [CalendarEvent] {
        var events: [CalendarEvent] = []

        // 1. 상호작용 기록
        for record in person.getAllInteractionRecordsSorted() {
            events.append(CalendarEvent(
                id: "interaction-\(record.id)",
                date: record.date,
                title: record.type.title,
                type: .interaction(record.type),
                details: record.notes
            ))
        }

        // 2. 액션 마감일 (reminderDate가 있는 경우)
        for personAction in person.actions where !personAction.isCompleted {
            if let reminderDate = personAction.reminderDate, let action = personAction.action {
                events.append(CalendarEvent(
                    id: "action-\(personAction.id)",
                    date: reminderDate,
                    title: action.title,
                    type: .actionDue(isCritical: action.type == .critical),
                    details: personAction.note
                ))
            }
        }

        // 3. 시스템 캘린더 일정
        let systemEvents = calendarManager.fetchUpcomingEvents(for: person, days: 365)
        for event in systemEvents {
            events.append(CalendarEvent(
                id: "system-\(event.eventIdentifier ?? UUID().uuidString)",
                date: event.startDate,
                title: event.title ?? "제목 없음",
                type: .systemCalendar,
                details: event.notes
            ))
        }

        return events
    }
}

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable {
    let id: String
    let date: Date
    let title: String
    let type: CalendarEventType
    let details: String?
}

enum CalendarEventType {
    case interaction(InteractionType)
    case actionDue(isCritical: Bool)
    case systemCalendar
    case relationshipChange

    var color: Color {
        switch self {
        case .interaction(let type):
            return type.color
        case .actionDue(let isCritical):
            return isCritical ? .red : .orange
        case .systemCalendar:
            return .blue
        case .relationshipChange:
            return .purple
        }
    }

    var icon: String {
        switch self {
        case .interaction(let type):
            return type.systemImage
        case .actionDue:
            return "checklist"
        case .systemCalendar:
            return "calendar"
        case .relationshipChange:
            return "heart.fill"
        }
    }
}

// MARK: - Calendar Event Row

struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // 시간
            VStack(alignment: .leading, spacing: 2) {
                Text(event.date, style: .time)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 60, alignment: .leading)

            // 아이콘과 타입
            Image(systemName: event.type.icon)
                .foregroundStyle(event.type.color)
                .frame(width: 24)

            // 내용
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .foregroundStyle(.primary)

                if let details = event.details, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(event.type.color.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(event.type.color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Mac Upcoming Event Row

struct MacUpcomingEventRow: View {
    let event: EKEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 날짜 및 시간
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.startDate, style: .date)
                        .font(.headline)
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
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.blue.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Mac Meeting Record Row

struct MacMeetingRecordRow: View {
    let meeting: MeetingRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(meeting.date, style: .date)
                    .font(.headline)
                Spacer()
                Text("\(meeting.duration)분")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(meeting.summary)
                .font(.body)

            if !meeting.transcribedText.isEmpty {
                Text(meeting.transcribedText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.05))
        )
    }
}
