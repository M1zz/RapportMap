import SwiftUI

struct MentoringSessionEditView: View {
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
        Form {
            Section {
                DatePicker("세션 날짜", selection: $session.sessionDate, displayedComponents: .date)
            }

            // 멘토링 전
            Section {
                TextEditorField(
                    title: "지난번 이후에 어떤 시도들을 했는지",
                    text: $session.preMentoring.attemptsSinceLastTime
                )

                TextEditorField(
                    title: "지난번 이후에 어떤 변화가 있었는지",
                    text: $session.preMentoring.changesSinceLastTime
                )

                TextEditorField(
                    title: "이번에 어떤 변화가 생기기를 기대하는지",
                    text: $session.preMentoring.expectedChanges
                )

                RatingPicker(
                    title: "개인적인 삶의 만족도",
                    rating: $session.preMentoring.personalLifeSatisfaction
                )

                RatingPicker(
                    title: "지인, 가족과의 관계에서의 만족도",
                    rating: $session.preMentoring.relationshipSatisfaction
                )

                RatingPicker(
                    title: "아카데미, 사회에서의 만족도",
                    rating: $session.preMentoring.academySatisfaction
                )

                RatingPicker(
                    title: "전반적인 나의 삶",
                    rating: $session.preMentoring.overallLifeSatisfaction
                )
            } header: {
                Text("멘토링 전")
            }

            // 멘토링 후
            Section {
                RatingPicker(
                    title: "오늘 리이오와 나누고자 했던 이야기를 얼마나 나누었나요?",
                    rating: $session.postMentoring.conversationCompleteness
                )

                RatingPicker(
                    title: "리이오가 나의 이야기를 얼마나 들어주었나요?",
                    rating: $session.postMentoring.listeningQuality
                )

                RatingPicker(
                    title: "리이오와의 대화는 나에게 있어서 얼마나 도움이 되었나요?",
                    rating: $session.postMentoring.helpfulness
                )

                RatingPicker(
                    title: "전반적으로 멘토링을 평가한다면 어땠나요?",
                    rating: $session.postMentoring.overallEvaluation
                )

                TextEditorField(
                    title: "이번 멘토링에 나에게 중요했던 것들",
                    text: $session.postMentoring.importantThings
                )

                TextEditorField(
                    title: "나에게 의미있었던 것을 한 문장으로 정리",
                    text: $session.postMentoring.meaningfulSummary
                )

                TextEditorField(
                    title: "이후의 액션플랜",
                    text: $session.postMentoring.actionPlan
                )
            } header: {
                Text("멘토링 후")
            }
        }
        .navigationTitle(isNew ? "새 멘토링 세션" : "세션 편집")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("취소") {
                    dismiss()
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button("저장") {
                    if isNew {
                        manager.addSession(session)
                    } else {
                        manager.updateSession(session)
                    }
                    dismiss()
                }
            }
        }
    }
}

struct TextEditorField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            TextEditor(text: $text)
                .frame(minHeight: 80)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }
}

struct RatingPicker: View {
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
                }
            }
        }
        .padding(.vertical, 4)
    }
}
