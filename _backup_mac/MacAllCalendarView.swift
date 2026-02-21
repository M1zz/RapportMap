//
//  MacAllCalendarView.swift
//  mac
//
//  전체 사람들의 통합 캘린더 뷰
//

import SwiftUI
import SwiftData
import EventKit

struct MacAllCalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPeople: [Person]
    @StateObject private var calendarManager = CalendarManager.shared

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var selectedPerson: Person?

    private var calendar: Calendar {
        Calendar.current
    }

    // 선택된 날짜의 모든 이벤트
    private var eventsForSelectedDate: [(Person?, CalendarEvent)] {
        let events = getAllCalendarEvents()
        return events.filter { calendar.isDate($0.1.date, inSameDayAs: selectedDate) }
            .sorted { $0.1.date < $1.1.date }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            headerView

            Divider()

            HStack(spacing: 0) {
                // 왼쪽: 캘린더
                VStack(spacing: 0) {
                    monthNavigationBar
                    Divider()
                    calendarGrid
                        .padding()
                }
                .frame(width: 400)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // 오른쪽: 선택된 날짜의 일정
                VStack(spacing: 0) {
                    selectedDateHeader
                    Divider()

                    if eventsForSelectedDate.isEmpty {
                        emptyEventsView
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(eventsForSelectedDate, id: \.1.id) { person, event in
                                    AllCalendarEventRow(person: person, event: event)
                                }
                            }
                            .padding()
                        }
                    }
                }
            }
        }
        .frame(minWidth: 900, minHeight: 700)
    }

    // MARK: - View Components

    @ViewBuilder
    private var headerView: some View {
        HStack {
            Text("전체 일정")
                .font(.title2)
                .fontWeight(.bold)

            Spacer()

            Button("닫기") {
                dismiss()
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

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
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }

    @ViewBuilder
    private var emptyEventsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)

            Text("이 날짜에 일정이 없습니다")
                .font(.headline)
                .foregroundStyle(.secondary)
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
        let events = getAllCalendarEvents()
        return events.filter { calendar.isDate($0.1.date, inSameDayAs: date) }.count
    }

    private func getAllCalendarEvents() -> [(Person?, CalendarEvent)] {
        var events: [(Person?, CalendarEvent)] = []

        // 모든 사람들의 이벤트 수집
        for person in allPeople {
            // 1. 상호작용 기록
            for record in person.getAllInteractionRecordsSorted() {
                events.append((person, CalendarEvent(
                    id: "interaction-\(person.id)-\(record.id)",
                    date: record.date,
                    title: record.type.title,
                    type: .interaction(record.type),
                    details: record.notes
                )))
            }

            // 2. 액션 마감일
            for personAction in person.actions where !personAction.isCompleted {
                if let reminderDate = personAction.reminderDate, let action = personAction.action {
                    events.append((person, CalendarEvent(
                        id: "action-\(person.id)-\(personAction.id)",
                        date: reminderDate,
                        title: action.title,
                        type: .actionDue(isCritical: action.type == .critical),
                        details: personAction.note
                    )))
                }
            }

            // 3. 시스템 캘린더 일정
            let systemEvents = calendarManager.fetchUpcomingEvents(for: person, days: 365)
            for event in systemEvents {
                events.append((person, CalendarEvent(
                    id: "system-\(person.id)-\(event.eventIdentifier ?? UUID().uuidString)",
                    date: event.startDate,
                    title: event.title ?? "제목 없음",
                    type: .systemCalendar,
                    details: event.notes
                )))
            }
        }

        return events
    }
}

// MARK: - All Calendar Event Row

struct AllCalendarEventRow: View {
    let person: Person?
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

            // 아이콘
            Image(systemName: event.type.icon)
                .foregroundStyle(event.type.color)
                .frame(width: 24)

            // 내용
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    if let person = person {
                        Text(person.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Text(event.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                }

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
