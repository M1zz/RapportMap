import SwiftUI

struct MacMentoringSessionDetailView: View {
    let session: MentoringSession
    @ObservedObject var manager: MentoringManager
    @State private var showingEdit = false
    @State private var showingExport = false
    @State private var exportText = ""

    var body: some View {
        VStack {
            HStack {
                Text("멘토링 세션")
                    .font(.title2)
                Spacer()
                Button("편집") {
                    showingEdit = true
                }
            }
            .padding()

            Form {
                Section {
                    HStack {
                        Text("세션 날짜")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(session.sessionDate))
                    }
                }

                // 멘토링 전
                Section {
                    MacDetailRow(title: "지난번 이후에 어떤 시도들을 했는지", value: session.preMentoring.attemptsSinceLastTime)
                    MacDetailRow(title: "지난번 이후에 어떤 변화가 있었는지", value: session.preMentoring.changesSinceLastTime)
                    MacDetailRow(title: "이번에 어떤 변화가 생기기를 기대하는지", value: session.preMentoring.expectedChanges)

                    MacRatingRow(title: "개인적인 삶의 만족도", rating: session.preMentoring.personalLifeSatisfaction)
                    MacRatingRow(title: "지인, 가족과의 관계에서의 만족도", rating: session.preMentoring.relationshipSatisfaction)
                    MacRatingRow(title: "아카데미, 사회에서의 만족도", rating: session.preMentoring.academySatisfaction)
                    MacRatingRow(title: "전반적인 나의 삶", rating: session.preMentoring.overallLifeSatisfaction)
                } header: {
                    Text("멘토링 전")
                }

                // 멘토링 후
                Section {
                    MacRatingRow(title: "오늘 리이오와 나누고자 했던 이야기를 얼마나 나누었나요?", rating: session.postMentoring.conversationCompleteness)
                    MacRatingRow(title: "리이오가 나의 이야기를 얼마나 들어주었나요?", rating: session.postMentoring.listeningQuality)
                    MacRatingRow(title: "리이오와의 대화는 나에게 있어서 얼마나 도움이 되었나요?", rating: session.postMentoring.helpfulness)
                    MacRatingRow(title: "전반적으로 멘토링을 평가한다면 어땠나요?", rating: session.postMentoring.overallEvaluation)

                    MacDetailRow(title: "이번 멘토링에 나에게 중요했던 것들", value: session.postMentoring.importantThings)
                    MacDetailRow(title: "나에게 의미있었던 것을 한 문장으로 정리", value: session.postMentoring.meaningfulSummary)
                    MacDetailRow(title: "이후의 액션플랜", value: session.postMentoring.actionPlan)
                } header: {
                    Text("멘토링 후")
                }

                Section {
                    Button {
                        exportText = manager.exportToText(session)
                        showingExport = true
                    } label: {
                        Label("Export", systemImage: "square.and.arrow.up")
                    }
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $showingEdit) {
            MacMentoringSessionEditView(session: session, manager: manager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showingExport) {
            MacExportTextView(text: exportText)
                .frame(minWidth: 600, minHeight: 400)
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

struct MacDetailRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(value.isEmpty ? "작성되지 않음" : value)
                .font(.body)
                .foregroundColor(value.isEmpty ? .secondary : .primary)
        }
        .padding(.vertical, 4)
    }
}

struct MacRatingRow: View {
    let title: String
    let rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Text("\(rating)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("/ 10")
                    .foregroundColor(.secondary)
                Spacer()
                ForEach(1...10, id: \.self) { index in
                    Circle()
                        .fill(index <= rating ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct MacMentoringSessionEditView: View {
    @ObservedObject var manager: MentoringManager
    @State private var session: MentoringSession
    @Environment(\.dismiss) var dismiss

    private let isNew: Bool

    init(session: MentoringSession, manager: MentoringManager) {
        self.manager = manager
        _session = State(initialValue: session)
        self.isNew = manager.sessions.first(where: { $0.id == session.id }) == nil
    }

    var body: some View {
        VStack {
            HStack {
                Text(isNew ? "새 멘토링 세션" : "세션 편집")
                    .font(.title2)
                Spacer()
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("저장") {
                    if isNew {
                        manager.addSession(session)
                    } else {
                        manager.updateSession(session)
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()

            Form {
                Section {
                    DatePicker("세션 날짜", selection: $session.sessionDate, displayedComponents: .date)
                }

                // 멘토링 전
                Section {
                    MacTextEditorField(
                        title: "지난번 이후에 어떤 시도들을 했는지",
                        text: $session.preMentoring.attemptsSinceLastTime
                    )

                    MacTextEditorField(
                        title: "지난번 이후에 어떤 변화가 있었는지",
                        text: $session.preMentoring.changesSinceLastTime
                    )

                    MacTextEditorField(
                        title: "이번에 어떤 변화가 생기기를 기대하는지",
                        text: $session.preMentoring.expectedChanges
                    )

                    MacRatingPicker(
                        title: "개인적인 삶의 만족도",
                        rating: $session.preMentoring.personalLifeSatisfaction
                    )

                    MacRatingPicker(
                        title: "지인, 가족과의 관계에서의 만족도",
                        rating: $session.preMentoring.relationshipSatisfaction
                    )

                    MacRatingPicker(
                        title: "아카데미, 사회에서의 만족도",
                        rating: $session.preMentoring.academySatisfaction
                    )

                    MacRatingPicker(
                        title: "전반적인 나의 삶",
                        rating: $session.preMentoring.overallLifeSatisfaction
                    )
                } header: {
                    Text("멘토링 전")
                }

                // 멘토링 후
                Section {
                    MacRatingPicker(
                        title: "오늘 리이오와 나누고자 했던 이야기를 얼마나 나누었나요?",
                        rating: $session.postMentoring.conversationCompleteness
                    )

                    MacRatingPicker(
                        title: "리이오가 나의 이야기를 얼마나 들어주었나요?",
                        rating: $session.postMentoring.listeningQuality
                    )

                    MacRatingPicker(
                        title: "리이오와의 대화는 나에게 있어서 얼마나 도움이 되었나요?",
                        rating: $session.postMentoring.helpfulness
                    )

                    MacRatingPicker(
                        title: "전반적으로 멘토링을 평가한다면 어땠나요?",
                        rating: $session.postMentoring.overallEvaluation
                    )

                    MacTextEditorField(
                        title: "이번 멘토링에 나에게 중요했던 것들",
                        text: $session.postMentoring.importantThings
                    )

                    MacTextEditorField(
                        title: "나에게 의미있었던 것을 한 문장으로 정리",
                        text: $session.postMentoring.meaningfulSummary
                    )

                    MacTextEditorField(
                        title: "이후의 액션플랜",
                        text: $session.postMentoring.actionPlan
                    )
                } header: {
                    Text("멘토링 후")
                }
            }
            .formStyle(.grouped)
        }
        .padding()
    }
}

struct MacTextEditorField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: 80)
                .border(Color.secondary.opacity(0.2))
        }
        .padding(.vertical, 4)
    }
}

struct MacRatingPicker: View {
    let title: String
    @Binding var rating: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 12) {
                ForEach(1...10, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Text("\(value)")
                            .font(.body)
                            .fontWeight(rating == value ? .bold : .regular)
                            .foregroundColor(rating == value ? .white : .primary)
                            .frame(width: 32, height: 32)
                            .background(rating == value ? Color.blue : Color.gray.opacity(0.2))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
