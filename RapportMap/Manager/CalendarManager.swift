//
//  CalendarManager.swift
//  RapportMap
//
//  iOS 캘린더 연동 매니저
//

import Foundation
import EventKit
import SwiftData
import Combine

@MainActor
class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()
    @Published var isAuthorized = false

    private init() {
        checkAuthorizationStatus()
    }

    // MARK: - Authorization

    func checkAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, *) {
            isAuthorized = (status == .fullAccess || status == .writeOnly)
        } else {
            isAuthorized = (status == .authorized)
        }
    }

    func requestAccess() async throws {
        if #available(iOS 17.0, *) {
            let granted = try await eventStore.requestFullAccessToEvents()
            isAuthorized = granted
        } else {
            let granted = try await eventStore.requestAccess(to: .event)
            isAuthorized = granted
        }
    }

    // MARK: - Create Event

    /// Person과 연결된 캘린더 이벤트 생성
    func createEvent(
        for person: Person,
        title: String,
        date: Date,
        duration: Int, // 분 단위
        notes: String = "",
        context: ModelContext
    ) async throws -> MeetingRecord {
        // 1. 캘린더 권한 확인
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        // 2. 캘린더 이벤트 생성
        let event = EKEvent(eventStore: eventStore)
        event.title = "\(person.name) - \(title)"
        event.startDate = date
        event.endDate = Calendar.current.date(byAdding: .minute, value: duration, to: date) ?? date
        event.notes = notes
        event.calendar = eventStore.defaultCalendarForNewEvents

        // Person ID를 URL로 저장 (나중에 매칭에 사용)
        event.url = URL(string: "rapportmap://person/\(person.id.uuidString)")

        // 3. 캘린더에 저장
        try eventStore.save(event, span: .thisEvent)

        print("✅ [Calendar] 캘린더 이벤트 생성: \(event.title ?? "")")

        // 4. MeetingRecord 생성
        let meetingRecord = MeetingRecord(
            date: date,
            meetingType: .mentoring,
            transcribedText: notes,
            summary: title,
            duration: TimeInterval(duration * 60)  // 분을 초로 변환
        )

        // 5. Person과 연결
        person.meetingRecords.append(meetingRecord)

        // 6. 저장
        context.insert(meetingRecord)
        try context.save()

        return meetingRecord
    }

    // MARK: - Fetch Events

    /// 특정 Person과 관련된 다가오는 이벤트 조회
    func fetchUpcomingEvents(for person: Person, days: Int = 30) -> [EKEvent] {
        guard isAuthorized else { return [] }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        // Person ID로 필터링
        let personURLString = "rapportmap://person/\(person.id.uuidString)"
        let personEvents = events.filter { event in
            // URL로 매칭
            if event.url?.absoluteString == personURLString {
                return true
            }
            // 또는 이름으로 매칭
            if let title = event.title, title.contains(person.name) {
                return true
            }
            return false
        }

        return personEvents
    }

    /// 모든 사람들의 다가오는 이벤트 조회
    func fetchAllUpcomingEvents(days: Int = 7) -> [EKEvent] {
        guard isAuthorized else { return [] }

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: days, to: startDate) ?? startDate

        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)

        // RapportMap 관련 이벤트만 필터링
        return events.filter { event in
            event.url?.scheme == "rapportmap" ||
            event.notes?.contains("[RapportMap]") == true
        }
    }

    /// 이벤트에서 Person ID 추출
    func extractPersonID(from event: EKEvent) -> UUID? {
        if let url = event.url,
           url.scheme == "rapportmap",
           url.host == "person",
           let idString = url.pathComponents.last,
           let uuid = UUID(uuidString: idString) {
            return uuid
        }
        return nil
    }

    // MARK: - Delete Event

    func deleteEvent(_ event: EKEvent) throws {
        guard isAuthorized else {
            throw CalendarError.notAuthorized
        }

        try eventStore.remove(event, span: .thisEvent)
        print("✅ [Calendar] 캘린더 이벤트 삭제: \(event.title ?? "")")
    }
}

// MARK: - Errors

enum CalendarError: LocalizedError {
    case notAuthorized
    case eventNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "캘린더 접근 권한이 필요합니다"
        case .eventNotFound:
            return "이벤트를 찾을 수 없습니다"
        }
    }
}
