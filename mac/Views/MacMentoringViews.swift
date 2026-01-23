//
//  MacMentoringViews.swift
//  mac
//
//  macOS용 멘토링 관련 뷰들
//

import SwiftUI
import SwiftData

// MARK: - Mentoring Session Compact Card

struct MacMentoringSessionCompactCard: View {
    let session: MentoringSession

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.sessionDate, style: .date)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if !session.postMentoring.meaningfulSummary.isEmpty {
                    Text(session.postMentoring.meaningfulSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
                    .font(.caption)
                Text("\(session.preMentoring.overallLifeSatisfaction)")
                    .font(.callout)
                    .fontWeight(.semibold)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.purple.opacity(0.05))
        )
    }
}

// MARK: - Person Mentoring Sessions View

struct MacPersonMentoringSessionsView: View {
    let person: Person
    @ObservedObject var manager: MentoringManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSession = false
    @State private var selectedSession: MentoringSession?

    private var personSessions: [MentoringSession] {
        manager.sessions.filter { $0.personId == person.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(person.name)님의 멘토링 기록")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("총 \(personSessions.count)회의 세션")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    showingAddSession = true
                } label: {
                    Label("세션 추가", systemImage: "plus.circle.fill")
                }

                Button("닫기") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 세션 목록
            if personSessions.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    Text("아직 멘토링 기록이 없습니다")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text("\(person.name)님과의 멘토링 세션을 기록해보세요")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        showingAddSession = true
                    } label: {
                        Label("첫 세션 기록하기", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(personSessions) { session in
                            MacMentoringSessionDetailCard(session: session)
                                .onTapGesture {
                                    selectedSession = session
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingAddSession) {
            MacMentoringSessionEditView(
                session: MentoringSession(personId: person.id),
                manager: manager
            )
        }
        .sheet(item: $selectedSession) { session in
            MacMentoringSessionDetailView(session: session, manager: manager)
        }
    }
}

// MARK: - Mentoring Session Detail Card

struct MacMentoringSessionDetailCard: View {
    let session: MentoringSession

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(session.sessionDate, style: .date)
                        .font(.headline)
                    Text(session.sessionDate, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("\(session.preMentoring.overallLifeSatisfaction)/10")
                        .font(.title3)
                        .fontWeight(.bold)
                }
            }

            if !session.postMentoring.meaningfulSummary.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("한줄 요약")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.postMentoring.meaningfulSummary)
                        .font(.body)
                        .lineLimit(2)
                }
            }

            if !session.postMentoring.actionPlan.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("액션플랜")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(session.postMentoring.actionPlan)
                        .font(.callout)
                        .foregroundStyle(.purple)
                        .lineLimit(2)
                }
            }

            HStack {
                Label("업데이트: \(session.updatedAt, style: .date)", systemImage: "clock")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.purple.opacity(0.2), lineWidth: 1)
                )
        )
    }
}
