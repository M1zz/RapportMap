//
//  MacPersonInfoTab.swift
//  mac
//
//  macOS용 Person 정보 탭
//

import SwiftUI
import SwiftData

// MARK: - Info Tab

struct MacPersonInfoTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()
    @State private var showingMentoringSession = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // 멘토링 버튼
            HStack {
                Spacer()
                Button {
                    showingMentoringSession = true
                } label: {
                    Label("멘토링 기록", systemImage: "person.2.fill")
                }
                .padding()
            }
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 0) {
                    Form {
                        Section("기본 정보") {
                            TextField("이름", text: $person.name)
                            TextField("연락처", text: $person.contact)
                            TextField("선호 호칭", text: $person.preferredName)
                        }

                        Section("관계 정보") {
                            TextField("관심사", text: $person.interests, axis: .vertical)
                                .lineLimit(3...6)
                            TextField("취향/선호", text: $person.preferences, axis: .vertical)
                                .lineLimit(3...6)
                            TextField("중요한 날짜", text: $person.importantDates, axis: .vertical)
                                .lineLimit(3...6)
                        }

                        Section("빠른 메모") {
                            TextEditor(text: $person.quickMemo)
                                .frame(minHeight: 100)
                                .font(.body)
                        }

                        // 알게 된 정보
                        if !getCompletedTrackingActions().isEmpty {
                            Section("📝 알게 된 정보") {
                                ForEach(getCompletedTrackingActions(), id: \.id) { personAction in
                                    if let action = personAction.action, !personAction.context.isEmpty {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(action.title)
                                                .font(.headline)
                                            Text(personAction.context)
                                                .font(.body)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.vertical, 4)
                                    }
                                }
                            }
                        }
                    }
                    .formStyle(.grouped)
                    .padding()

                    // 위험 작업 섹션
                    VStack(alignment: .leading, spacing: 12) {
                        Text("⚠️ 위험 작업")
                            .font(.headline)
                            .foregroundStyle(.red)

                        Button(role: .destructive) {
                            showingDeleteConfirmation = true
                        } label: {
                            Label("사람 완전 삭제", systemImage: "person.fill.xmark")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .controlSize(.large)

                        Text("이 사람과 모든 관련 데이터가 영구적으로 삭제됩니다.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.red.opacity(0.05))
                    .cornerRadius(12)
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingMentoringSession) {
            MacPersonMentoringSessionsView(person: person, manager: mentoringManager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .alert("사람 삭제", isPresented: $showingDeleteConfirmation) {
            Button("취소", role: .cancel) { }
            Button("삭제", role: .destructive) {
                deletePerson()
            }
        } message: {
            Text("\(person.name)님을 완전히 삭제하시겠습니까?\n\n모든 상호작용, 미팅, 대화, 메모, 액션이 함께 삭제되며 복구할 수 없습니다.")
        }
    }

    private func getCompletedTrackingActions() -> [PersonAction] {
        return person.actions.filter { action in
            action.completedDate != nil &&
            action.action?.type == .tracking &&
            !action.context.isEmpty
        }
    }

    private func deletePerson() {
        let personName = person.name
        context.delete(person)

        do {
            try context.save()
            print("✅ \(personName) 완전 삭제됨")

            // 윈도우 닫기
            if let window = NSApplication.shared.keyWindow {
                window.close()
            }
        } catch {
            print("❌ 사람 삭제 실패: \(error)")
        }
    }
}
