import Foundation
import SwiftUI
import Combine
import UniformTypeIdentifiers

class MentoringManager: ObservableObject {
    @Published var profile: MentoringProfile?
    @Published var sessions: [MentoringSession] = []

    private let profileKey = "mentoring_profile"
    private let sessionsKey = "mentoring_sessions"

    init() {
        loadProfile()
        loadSessions()
    }

    // MARK: - Profile Management

    func loadProfile() {
        if let data = UserDefaults.standard.data(forKey: profileKey),
           let profile = try? JSONDecoder().decode(MentoringProfile.self, from: data) {
            self.profile = profile
        }
    }

    func saveProfile(_ profile: MentoringProfile) {
        var updatedProfile = profile
        updatedProfile.updatedAt = Date()

        if let encoded = try? JSONEncoder().encode(updatedProfile) {
            UserDefaults.standard.set(encoded, forKey: profileKey)
            self.profile = updatedProfile
        }
    }

    // MARK: - Session Management

    func loadSessions() {
        if let data = UserDefaults.standard.data(forKey: sessionsKey),
           let sessions = try? JSONDecoder().decode([MentoringSession].self, from: data) {
            self.sessions = sessions.sorted { $0.sessionDate > $1.sessionDate }
        }
    }

    func saveSessions() {
        if let encoded = try? JSONEncoder().encode(sessions) {
            UserDefaults.standard.set(encoded, forKey: sessionsKey)
        }
    }

    func addSession(_ session: MentoringSession) {
        sessions.insert(session, at: 0)
        saveSessions()
    }

    func updateSession(_ session: MentoringSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            var updatedSession = session
            updatedSession.updatedAt = Date()
            sessions[index] = updatedSession
            saveSessions()
        }
    }

    func deleteSession(_ session: MentoringSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    // MARK: - Import/Export

    func importFromText(_ text: String) -> MentoringSession? {
        var session = MentoringSession()

        let lines = text.components(separatedBy: .newlines)
        var currentSection = ""
        var currentText = ""

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("---") {
                // 섹션 구분자
                if !currentSection.isEmpty && !currentText.isEmpty {
                    assignValue(section: currentSection, text: currentText, to: &session)
                    currentText = ""
                }
                continue
            }

            if trimmed.hasPrefix("<") || trimmed.contains("멘토링 전") || trimmed.contains("멘토링 후") {
                // 섹션 헤더
                currentSection = trimmed
                continue
            }

            if !trimmed.isEmpty {
                if trimmed.hasSuffix("(1-10)") {
                    currentSection = trimmed
                } else {
                    currentText += (currentText.isEmpty ? "" : "\n") + trimmed
                }
            }
        }

        // 마지막 섹션 처리
        if !currentSection.isEmpty && !currentText.isEmpty {
            assignValue(section: currentSection, text: currentText, to: &session)
        }

        return session
    }

    private func assignValue(section: String, text: String, to session: inout MentoringSession) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // 멘토링 전
        if section.contains("지난번 이후에 어떤 시도") {
            session.preMentoring.attemptsSinceLastTime = cleanText
        } else if section.contains("지난번 이후에 어떤 변화") {
            session.preMentoring.changesSinceLastTime = cleanText
        } else if section.contains("이번에 어떤 변화가 생기기를") {
            session.preMentoring.expectedChanges = cleanText
        } else if section.contains("개인적인 삶의 만족도") {
            session.preMentoring.personalLifeSatisfaction = Int(cleanText) ?? 5
        } else if section.contains("지인, 가족과의 관계") {
            session.preMentoring.relationshipSatisfaction = Int(cleanText) ?? 5
        } else if section.contains("아카데미, 사회에서의 만족도") {
            session.preMentoring.academySatisfaction = Int(cleanText) ?? 5
        } else if section.contains("전반적인 나의 삶") {
            session.preMentoring.overallLifeSatisfaction = Int(cleanText) ?? 5
        }
        // 멘토링 후
        else if section.contains("리이오와 나누고자") {
            session.postMentoring.conversationCompleteness = Int(cleanText) ?? 5
        } else if section.contains("리이오가 나의 이야기를") {
            session.postMentoring.listeningQuality = Int(cleanText) ?? 5
        } else if section.contains("리이오와의 대화는") {
            session.postMentoring.helpfulness = Int(cleanText) ?? 5
        } else if section.contains("전반적으로 멘토링을 평가") {
            session.postMentoring.overallEvaluation = Int(cleanText) ?? 5
        } else if section.contains("이번 멘토링에 나에게 중요했던") {
            session.postMentoring.importantThings = cleanText
        } else if section.contains("의미있었던 것을 한 문장") {
            session.postMentoring.meaningfulSummary = cleanText
        } else if section.contains("이후의 액션플랜") {
            session.postMentoring.actionPlan = cleanText
        }
    }

    func exportToText(_ session: MentoringSession) -> String {
        var text = """
        멘토링 세션 - \(formatDate(session.sessionDate))

        ---
        <멘토링 전>
        ---

        지난번 이후에 어떤 시도들을 했는지
        ---
        \(session.preMentoring.attemptsSinceLastTime)
        ---

        지난번 이후에 어떤 변화가 있었는지
        ---
        \(session.preMentoring.changesSinceLastTime)
        ---

        이번에 어떤 변화가 생기기를 기대하는지
        ---
        \(session.preMentoring.expectedChanges)
        ---

        개인적인 삶의 만족도는 몇 인가요? (1-10)
        ---
        \(session.preMentoring.personalLifeSatisfaction)
        ---

        지인, 가족과의 관계에서의 만족도는 몇 인가요? (1-10)
        ---
        \(session.preMentoring.relationshipSatisfaction)
        ---

        아카데미, 사회에서의 만족도는 몇 인가요? (1-10)
        ---
        \(session.preMentoring.academySatisfaction)
        ---

        전반적인 나의 삶은 지금 몇 점인가요? (1-10)
        ---
        \(session.preMentoring.overallLifeSatisfaction)
        ---

        ---
        <멘토링 후>
        ---

        오늘 리이오와 나누고자 했던 이야기를 얼마나 나누었나요? (1-10)
        ---
        \(session.postMentoring.conversationCompleteness)
        ---

        리이오가 나의 이야기를 얼마나 들어주었나요? (1-10)
        ---
        \(session.postMentoring.listeningQuality)
        ---

        리이오와의 대화는 나에게 있어서 얼마나 도움이 되었나요? (1-10)
        ---
        \(session.postMentoring.helpfulness)
        ---

        전반적으로 멘토링을 평가한다면 어땠나요? (1-10)
        ---
        \(session.postMentoring.overallEvaluation)
        ---

        이번 멘토링에 나에게 중요했던 것들
        ---
        \(session.postMentoring.importantThings)
        ---

        나에게 의미있었던 것을 한 문장으로 정리
        ---
        \(session.postMentoring.meaningfulSummary)
        ---

        이후의 액션플랜
        ---
        \(session.postMentoring.actionPlan)
        ---
        """

        return text
    }

    func exportProfileToText() -> String? {
        guard let profile = profile else { return nil }

        return """
        당부의 말씀
        ---
        <멘토링 전>
        ---

        멘토가 알았으면 하는 자신의 배경을 적어주세요! (제로 베이스, 실패의 경험, 환경 등등)
        ---
        \(profile.background)
        ---

        아카데미에 나갈 때의 자신의 목표를 적어주세요 (꿈 아님, 야망 아님, 현실적인 자신의 목표)
        ---
        \(profile.academyGoal)
        ---

        아카데미에서 배우고 싶은 것들을 적어주세요 (막연한 목표가 아닌 계획이 있는 배움의 계획)
        ---
        \(profile.learningPlan)
        ---

        목표를 달성하기 위해서 지금 하고있는 노력들을 적어주세요
        ---
        \(profile.currentEfforts)
        ---
        """
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}
