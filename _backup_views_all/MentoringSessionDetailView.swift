import SwiftUI

struct MentoringSessionDetailView: View {
    let session: MentoringSession
    @ObservedObject var manager: MentoringManager
    @State private var showingEdit = false

    var body: some View {
        List {
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
                DetailRow(title: "지난번 이후에 어떤 시도들을 했는지", value: session.preMentoring.attemptsSinceLastTime)
                DetailRow(title: "지난번 이후에 어떤 변화가 있었는지", value: session.preMentoring.changesSinceLastTime)
                DetailRow(title: "이번에 어떤 변화가 생기기를 기대하는지", value: session.preMentoring.expectedChanges)

                RatingRow(title: "개인적인 삶의 만족도", rating: session.preMentoring.personalLifeSatisfaction)
                RatingRow(title: "지인, 가족과의 관계에서의 만족도", rating: session.preMentoring.relationshipSatisfaction)
                RatingRow(title: "아카데미, 사회에서의 만족도", rating: session.preMentoring.academySatisfaction)
                RatingRow(title: "전반적인 나의 삶", rating: session.preMentoring.overallLifeSatisfaction)
            } header: {
                Text("멘토링 전")
            }

            // 멘토링 후
            Section {
                RatingRow(title: "오늘 리이오와 나누고자 했던 이야기를 얼마나 나누었나요?", rating: session.postMentoring.conversationCompleteness)
                RatingRow(title: "리이오가 나의 이야기를 얼마나 들어주었나요?", rating: session.postMentoring.listeningQuality)
                RatingRow(title: "리이오와의 대화는 나에게 있어서 얼마나 도움이 되었나요?", rating: session.postMentoring.helpfulness)
                RatingRow(title: "전반적으로 멘토링을 평가한다면 어땠나요?", rating: session.postMentoring.overallEvaluation)

                DetailRow(title: "이번 멘토링에 나에게 중요했던 것들", value: session.postMentoring.importantThings)
                DetailRow(title: "나에게 의미있었던 것을 한 문장으로 정리", value: session.postMentoring.meaningfulSummary)
                DetailRow(title: "이후의 액션플랜", value: session.postMentoring.actionPlan)
            } header: {
                Text("멘토링 후")
            }

            Section {
                ShareLink(item: manager.exportToText(session)) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
            }
        }
        .navigationTitle("멘토링 세션")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("편집") {
                    showingEdit = true
                }
            }
        }
        .sheet(isPresented: $showingEdit) {
            NavigationView {
                MentoringSessionEditView(session: session, manager: manager)
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

struct DetailRow: View {
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

struct RatingRow: View {
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
                        .frame(width: 8, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
