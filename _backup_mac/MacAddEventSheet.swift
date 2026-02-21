//
//  MacAddEventSheet.swift
//  mac
//
//  일정 추가 시트
//

import SwiftUI
import SwiftData

struct MacAddEventSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calendarManager = CalendarManager.shared

    let person: Person
    let selectedDate: Date?
    let onAdd: (MeetingRecord) -> Void

    @State private var title = ""
    @State private var date = Date()
    @State private var duration = 60 // 기본 60분
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCreating = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("\(person.name)님과 일정 추가")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 폼
            Form {
                Section("일정 정보") {
                    TextField("제목 (예: 멘토링, 미팅)", text: $title)
                        .textFieldStyle(.roundedBorder)

                    DatePicker("날짜 및 시간", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    HStack {
                        Text("소요 시간")
                        Spacer()
                        Picker("", selection: $duration) {
                            Text("30분").tag(30)
                            Text("1시간").tag(60)
                            Text("1.5시간").tag(90)
                            Text("2시간").tag(120)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }
                }

                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                        .font(.body)
                }
            }
            .padding()

            Divider()

            // 버튼
            HStack {
                if !calendarManager.isAuthorized {
                    Button("캘린더 권한 요청") {
                        requestCalendarAccess()
                    }
                }

                Spacer()

                Button("추가") {
                    createEvent()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty || isCreating || !calendarManager.isAuthorized)

                if isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .alert("오류", isPresented: $showingError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            calendarManager.checkAuthorizationStatus()
            // 선택된 날짜가 있으면 해당 날짜로 초기화
            if let selectedDate = selectedDate {
                date = selectedDate
            }
        }
    }

    private func requestCalendarAccess() {
        Task {
            do {
                try await calendarManager.requestAccess()
            } catch {
                errorMessage = "캘린더 접근 권한을 얻지 못했습니다: \(error.localizedDescription)"
                showingError = true
            }
        }
    }

    private func createEvent() {
        guard !title.isEmpty else { return }

        isCreating = true

        Task {
            do {
                let meetingRecord = try await calendarManager.createEvent(
                    for: person,
                    title: title,
                    date: date,
                    duration: duration,
                    notes: notes,
                    context: context
                )

                await MainActor.run {
                    onAdd(meetingRecord)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    isCreating = false
                }
            }
        }
    }
}

#Preview {
    MacAddEventSheet(
        person: Person(name: "홍길동"),
        selectedDate: Date(),
        onAdd: { _ in }
    )
    .modelContainer(for: [Person.self])
}
