//
//  MacPersonAnalyticsTab.swift
//  mac
//
//  macOS용 Person 분석 탭
//

import SwiftUI
import SwiftData

// MARK: - Analytics Tab

struct MacPersonAnalyticsTab: View {
    @Environment(\.modelContext) private var context
    @Bindable var person: Person
    @StateObject private var mentoringManager = MentoringManager()

    // Debug mode
    @State private var isDebugMode = false

    private var meetingsByMonth: [(String, Int)] {
        let calendar = Calendar.current
        let meetings = person.meetingRecords

        var monthCounts: [String: Int] = [:]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"

        for meeting in meetings {
            let monthKey = dateFormatter.string(from: meeting.date)
            monthCounts[monthKey, default: 0] += 1
        }

        return monthCounts.sorted { $0.key > $1.key }.prefix(6).map { ($0.key, $0.value) }
    }

    private var conversationsByType: [(String, Int)] {
        let records = person.conversationRecords
        var typeCounts: [String: Int] = [:]

        for record in records {
            let typeName = record.type.title
            typeCounts[typeName, default: 0] += 1
        }

        return typeCounts.sorted { $0.value > $1.value }
    }

    private var actionCompletionRate: Double {
        let actions = person.actions
        guard !actions.isEmpty else { return 0 }
        let completed = actions.filter { $0.isCompleted }.count
        return Double(completed) / Double(actions.count) * 100
    }

    private var personMentoringSessions: [MentoringSession] {
        mentoringManager.sessions.filter { $0.personId == person.id }
    }

    private var mentoringTrend: [(String, Int)] {
        let sessions = personMentoringSessions
        guard !sessions.isEmpty else { return [] }

        return sessions.enumerated().map { index, session in
            ("세션 \(index + 1)", session.preMentoring.overallLifeSatisfaction)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Debug Button (더블클릭으로 활성화)
            HStack {
                Button(action: {}) {
                    HStack(spacing: 8) {
                        Image(systemName: "ladybug.fill")
                            .font(.title3)
                        Text(isDebugMode ? "Debug Mode ON" : "Debug Mode")
                            .font(.headline)
                    }
                    .foregroundStyle(isDebugMode ? .green : .secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDebugMode ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .onTapGesture(count: 2) {
                    isDebugMode.toggle()
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    if isDebugMode {
                        debugSection
                    }

                    // 만남 빈도
                    meetingFrequencySection

                    // 대화 유형 분포
                    conversationTypeSection

                    // 액션 완료율
                    actionCompletionSection

                    // 멘토링 추이
                    if !personMentoringSessions.isEmpty {
                        mentoringTrendSection
                    }

                    // 전체 통계
                    overallStatsSection
                }
                .padding()
            }
        }
    }

    // MARK: - Debug Section

    private var debugSection: some View {
        VStack(spacing: 12) {
            Text("🔧 Debug Tools")
                .font(.headline)

            HStack(spacing: 12) {
                Button {
                    generateDummyMeetings()
                } label: {
                    Label("더미 미팅 생성", systemImage: "calendar.badge.plus")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    generateDummyConversations()
                } label: {
                    Label("더미 대화 생성", systemImage: "message.badge.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    generateDummyMentoringSessions()
                } label: {
                    Label("더미 멘토링 생성", systemImage: "person.2.badge.gearshape")
                }
                .buttonStyle(.borderedProminent)
            }

            Button(role: .destructive) {
                clearAllData()
            } label: {
                Label("모든 데이터 삭제", systemImage: "trash.fill")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                deletePerson()
            } label: {
                Label("사람 완전 삭제", systemImage: "person.fill.xmark")
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Chart Sections

    private var meetingFrequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("만남 빈도 (최근 6개월)")
                .font(.headline)

            if meetingsByMonth.isEmpty {
                emptyChartView(message: "아직 미팅 기록이 없습니다")
            } else {
                VStack(spacing: 8) {
                    ForEach(meetingsByMonth, id: \.0) { month, count in
                        HStack {
                            Text(month)
                                .font(.caption)
                                .frame(width: 60, alignment: .leading)

                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.blue)
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(meetingsByMonth.map(\.1).max() ?? 1))
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 20)

                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var conversationTypeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("대화 유형 분포")
                .font(.headline)

            if conversationsByType.isEmpty {
                emptyChartView(message: "아직 대화 기록이 없습니다")
            } else {
                VStack(spacing: 8) {
                    ForEach(conversationsByType, id: \.0) { type, count in
                        HStack {
                            Text(type)
                                .font(.caption)
                                .frame(width: 80, alignment: .leading)

                            GeometryReader { geometry in
                                HStack(spacing: 0) {
                                    Rectangle()
                                        .fill(Color.green)
                                        .frame(width: geometry.size.width * CGFloat(count) / CGFloat(conversationsByType.map(\.1).max() ?? 1))
                                    Spacer(minLength: 0)
                                }
                            }
                            .frame(height: 20)

                            Text("\(count)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var actionCompletionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("액션 완료율")
                .font(.headline)

            HStack {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 30)

                        Rectangle()
                            .fill(Color.purple)
                            .frame(width: geometry.size.width * actionCompletionRate / 100, height: 30)
                    }
                }
                .frame(height: 30)
                .cornerRadius(8)

                Text("\(Int(actionCompletionRate))%")
                    .font(.title3)
                    .fontWeight(.bold)
                    .frame(width: 60, alignment: .trailing)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var mentoringTrendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("멘토링 만족도 추이")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(mentoringTrend, id: \.0) { session, score in
                    HStack {
                        Text(session)
                            .font(.caption)
                            .frame(width: 60, alignment: .leading)

                        GeometryReader { geometry in
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(Color.orange)
                                    .frame(width: geometry.size.width * CGFloat(score) / 10)
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(height: 20)

                        Text("\(score)/10")
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private var overallStatsSection: some View {
        VStack(spacing: 16) {
            Text("전체 통계")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                StatCard(title: "총 미팅", value: "\(person.meetingRecords.count)회", icon: "calendar", color: .blue)
                StatCard(title: "총 대화", value: "\(person.conversationRecords.count)회", icon: "message", color: .green)
                StatCard(title: "액션 아이템", value: "\(person.actions.count)개", icon: "checklist", color: .purple)
                StatCard(title: "멘토링 세션", value: "\(personMentoringSessions.count)회", icon: "person.2", color: .orange)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }

    private func emptyChartView(message: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Dummy Data Generation

    private func generateDummyMeetings() {
        let meetingTypes: [MeetingType] = [.mentoring, .meal, .coffee, .general, .presentation, .oneOnOne]

        for i in 0..<10 {
            let meeting = MeetingRecord(
                date: Date().addingTimeInterval(-Double(i) * 7 * 24 * 3600), // 주마다 하나씩
                meetingType: meetingTypes.randomElement() ?? .general,
                summary: "더미 미팅 \(i + 1)",
                duration: Double.random(in: 1800...7200)
            )
            meeting.person = person
            context.insert(meeting)
        }

        try? context.save()
        print("✅ 10개의 더미 미팅 생성됨")
    }

    private func generateDummyConversations() {
        let conversationTypes: [ConversationType] = [.question, .concern, .promise, .update, .feedback, .achievement]
        let priorities: [ConversationPriority] = [.low, .normal, .high, .urgent]

        for i in 0..<15 {
            let record = person.addConversationRecord(
                type: conversationTypes.randomElement() ?? .question,
                content: "더미 대화 내용 \(i + 1): 테스트 데이터입니다.",
                priority: priorities.randomElement() ?? .normal,
                isImportant: Bool.random(),
                date: Date().addingTimeInterval(-Double(i) * 3 * 24 * 3600)
            )
            context.insert(record)
        }

        try? context.save()
        print("✅ 15개의 더미 대화 생성됨")
    }

    private func generateDummyMentoringSessions() {
        for i in 0..<5 {
            var session = MentoringSession(personId: person.id)
            session.sessionDate = Date().addingTimeInterval(-Double(i) * 14 * 24 * 3600)
            session.preMentoring.overallLifeSatisfaction = Int.random(in: 5...10)
            session.preMentoring.personalLifeSatisfaction = Int.random(in: 5...10)
            session.preMentoring.relationshipSatisfaction = Int.random(in: 5...10)
            session.preMentoring.academySatisfaction = Int.random(in: 5...10)
            session.postMentoring.meaningfulSummary = "더미 세션 \(i + 1): 테스트 요약"
            session.postMentoring.actionPlan = "다음 단계 계획"

            mentoringManager.addSession(session)
        }

        print("✅ 5개의 더미 멘토링 세션 생성됨")
    }

    private func clearAllData() {
        // 미팅 삭제
        for meeting in person.meetingRecords {
            context.delete(meeting)
        }

        // 대화 삭제
        for conversation in person.conversationRecords {
            context.delete(conversation)
        }

        // 멘토링 세션 삭제
        let sessionsToDelete = mentoringManager.sessions.filter { $0.personId == person.id }
        for session in sessionsToDelete {
            mentoringManager.deleteSession(session)
        }

        try? context.save()
        print("✅ 모든 데이터가 삭제되었습니다")
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

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}
