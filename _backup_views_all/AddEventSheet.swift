//
//  AddEventSheet.swift
//  RapportMap
//
//  일정 추가 시트
//

import SwiftUI
import SwiftData

struct AddEventSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var calendarManager = CalendarManager.shared

    let person: Person
    let onAdd: (MeetingRecord) -> Void

    @State private var title = ""
    @State private var date = Date()
    @State private var duration = 60 // 기본 60분
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section("일정 정보") {
                    TextField("제목 (예: 멘토링, 미팅)", text: $title)

                    DatePicker("날짜 및 시간", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    Picker("소요 시간", selection: $duration) {
                        Text("30분").tag(30)
                        Text("1시간").tag(60)
                        Text("1.5시간").tag(90)
                        Text("2시간").tag(120)
                    }
                }

                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                if !calendarManager.isAuthorized {
                    Section {
                        Button {
                            requestCalendarAccess()
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.exclamationmark")
                                Text("캘린더 권한 요청")
                            }
                        }
                    }
                }
            }
            .navigationTitle("\(person.name)님과 일정 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    if isCreating {
                        ProgressView()
                    } else {
                        Button("추가") {
                            createEvent()
                        }
                        .disabled(title.isEmpty || !calendarManager.isAuthorized)
                    }
                }
            }
            .alert("오류", isPresented: $showingError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                calendarManager.checkAuthorizationStatus()
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
    AddEventSheet(
        person: Person(name: "홍길동"),
        onAdd: { _ in }
    )
    .modelContainer(for: [Person.self])
}
