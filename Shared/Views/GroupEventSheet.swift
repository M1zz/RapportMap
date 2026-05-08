//
//  GroupEventSheet.swift
//  RapportMap
//
//  여러 사람이 함께한 그룹 이벤트 기록 시트
//

import SwiftUI
import SwiftData

struct GroupEventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Person.name) private var allPeople: [Person]

    let initialPerson: Person?

    @State private var title = ""
    @State private var selectedType: ActivityType = .travel
    @State private var date = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var notes = ""
    @State private var selectedIDs: Set<PersistentIdentifier> = []

    init(person: Person? = nil) {
        self.initialPerson = person
    }

    var body: some View {
        NavigationStack {
            Form {
                // 이벤트 이름
                Section("이벤트 이름") {
                    TextField("예: 제주도 여행, 팀 회식, 영화 관람", text: $title)
                }

                // 종류
                Section("종류") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(ActivityType.allCases) { type in
                                Button {
                                    selectedType = type
                                } label: {
                                    VStack(spacing: 4) {
                                        Text(type.emoji)
                                            .font(.title)
                                        Text(type.title)
                                            .font(.body)
                                    }
                                    .frame(width: 70, height: 70)
                                    .background(selectedType == type ? type.color.opacity(0.2) : Color.secondary.opacity(0.08))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedType == type ? type.color : Color.clear, lineWidth: 2)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // 날짜
                Section("날짜") {
                    DatePicker("시작일", selection: $date, displayedComponents: .date)
                    Toggle("종료일 있음", isOn: $hasEndDate)
                    if hasEndDate {
                        DatePicker("종료일", selection: $endDate, in: date..., displayedComponents: .date)
                    }
                }

                // 참여자
                Section("함께한 사람 \(selectedIDs.isEmpty ? "" : "(\(selectedIDs.count)명)")") {
                    if allPeople.isEmpty {
                        Text("등록된 사람이 없습니다")
                            .foregroundStyle(.secondary)
                            .font(.body)
                    } else {
                        ForEach(allPeople) { person in
                            PersonPickerRow(
                                person: person,
                                isSelected: selectedIDs.contains(person.persistentModelID)
                            ) {
                                if selectedIDs.contains(person.persistentModelID) {
                                    selectedIDs.remove(person.persistentModelID)
                                } else {
                                    selectedIDs.insert(person.persistentModelID)
                                }
                            }
                        }
                    }
                }

                // 메모
                Section("메모 (선택)") {
                    TextField("어떤 시간이었나요?", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            #if os(macOS)
            .formStyle(.grouped)
            #endif
            .navigationTitle("그룹 이벤트 기록")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") {
                        saveGroupEvent()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || selectedIDs.isEmpty)
                }
            }
            .onAppear {
                if let person = initialPerson {
                    selectedIDs.insert(person.persistentModelID)
                }
            }
        }
        #if os(macOS)
        .frame(width: 480, height: 600)
        #endif
    }

    private func saveGroupEvent() {
        let event = GroupEvent(
            title: title.trimmingCharacters(in: .whitespaces),
            type: selectedType,
            date: date,
            endDate: hasEndDate ? endDate : nil,
            notes: notes
        )
        let participants = allPeople.filter { selectedIDs.contains($0.persistentModelID) }
        event.participants = participants
        context.insert(event)
        try? context.save()
        dismiss()
    }
}

// MARK: - 사람 선택 행

private struct PersonPickerRow: View {
    let person: Person
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // 프로필 이미지
                Group {
                    if let data = person.profileImageData,
                       let uiImage = platformImage(from: data) {
                        uiImage
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 36, height: 36)
                .clipShape(Circle())

                Text(person.name)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary.opacity(0.4))
                    .font(.title3)
            }
        }
        .buttonStyle(.plain)
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(iOS)
        if let ui = UIImage(data: data) { return Image(uiImage: ui) }
        return nil
        #else
        if let ns = NSImage(data: data) { return Image(nsImage: ns) }
        return nil
        #endif
    }
}

// MARK: - 그룹 이벤트 행

struct GroupEventRow: View {
    let event: GroupEvent
    let onDelete: () -> Void

    private var participantNames: String {
        let names = (event.participants ?? []).map { $0.name }
        if names.isEmpty { return "참여자 없음" }
        if names.count <= 3 { return names.joined(separator: ", ") }
        return "\(names.prefix(3).joined(separator: ", ")) 외 \(names.count - 3)명"
    }

    private var dateText: String {
        let start = event.date.formatted(date: .abbreviated, time: .omitted)
        if let end = event.endDate {
            return "\(start) ~ \(end.formatted(date: .abbreviated, time: .omitted))"
        }
        return start
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(event.type.emoji)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(event.type.color.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 3) {
                Text(event.title)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Image(systemName: "person.2")
                        .font(.body)
                    Text(participantNames)
                        .font(.body)
                }
                .foregroundStyle(.secondary)

                if !event.notes.isEmpty {
                    Text(event.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(dateText)
                    .font(.body)
                    .foregroundStyle(.secondary)

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .font(.body)
                        .foregroundStyle(.red.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(10)
    }
}
