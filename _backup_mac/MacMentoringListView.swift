import SwiftUI
import UniformTypeIdentifiers

struct MacMentoringListView: View {
    @StateObject private var manager = MentoringManager()
    @State private var selectedSession: MentoringSession?
    @State private var showingNewSession = false
    @State private var showingProfileEditor = false
    @State private var showingImportSheet = false
    @State private var importedText = ""

    var body: some View {
        NavigationSplitView {
            // 사이드바
            List(selection: $selectedSession) {
                Section {
                    if manager.profile != nil {
                        NavigationLink(value: nil as MentoringSession?) {
                            Label("기본 정보 (최초 1회)", systemImage: "person.text.rectangle")
                        }
                    } else {
                        Button {
                            showingProfileEditor = true
                        } label: {
                            Label("기본 정보 작성하기", systemImage: "person.text.rectangle")
                        }
                    }
                } header: {
                    Text("멘토링 프로필")
                }

                Section {
                    ForEach(manager.sessions) { session in
                        NavigationLink(value: session) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(formatDate(session.sessionDate))
                                    .font(.headline)
                                Text("업데이트: \(formatDate(session.updatedAt))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("멘토링 세션")
                }
            }
            .navigationTitle("멘토링")
            .toolbar {
                ToolbarItem {
                    Menu {
                        Button {
                            showingImportSheet = true
                        } label: {
                            Label("텍스트 Import", systemImage: "square.and.arrow.down")
                        }

                        Button {
                            importFromClipboard()
                        } label: {
                            Label("클립보드에서 Import", systemImage: "doc.on.clipboard")
                        }

                        Divider()

                        Button {
                            importFromFile()
                        } label: {
                            Label("Numbers/CSV 파일 Import", systemImage: "tablecells")
                        }
                    } label: {
                        Label("Import", systemImage: "square.and.arrow.down")
                    }
                }

                ToolbarItem {
                    Button {
                        showingNewSession = true
                    } label: {
                        Label("새 세션", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let session = selectedSession {
                MacMentoringSessionDetailView(session: session, manager: manager)
            } else if manager.profile != nil {
                MacMentoringProfileView(manager: manager)
            } else {
                Text("항목을 선택하세요")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingNewSession) {
            MacMentoringSessionEditView(session: MentoringSession(), manager: manager)
                .frame(minWidth: 800, minHeight: 600)
        }
        .sheet(isPresented: $showingProfileEditor) {
            MacMentoringProfileView(manager: manager)
                .frame(minWidth: 700, minHeight: 500)
        }
        .sheet(isPresented: $showingImportSheet) {
            MacImportTextView(importedText: $importedText, onImport: { text in
                if let session = manager.importFromText(text) {
                    manager.addSession(session)
                    showingImportSheet = false
                }
            })
            .frame(minWidth: 600, minHeight: 400)
        }
    }

    private func importFromClipboard() {
        #if os(macOS)
        if let text = NSPasteboard.general.string(forType: .string) {
            if let session = manager.importFromText(text) {
                manager.addSession(session)
            }
        }
        #endif
    }

    private func importFromFile() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .plainText,
            .text,
            .commaSeparatedText,
            .tabSeparatedText,
            UTType(filenameExtension: "numbers") ?? .data
        ]
        panel.message = "멘토링 세션 데이터를 포함한 CSV 또는 텍스트 파일을 선택하세요"

        if panel.runModal() == .OK {
            if let url = panel.url {
                handleFileImport(url: url)
            }
        }
        #endif
    }

    private func handleFileImport(url: URL) {
        do {
            let fileExtension = url.pathExtension.lowercased()

            if fileExtension == "csv" || fileExtension == "txt" {
                let data = try String(contentsOf: url, encoding: .utf8)

                // CSV 파일인지 확인 (쉼표가 있는지 체크)
                if data.contains(",") && data.contains("\n") {
                    let sessions = parseCSVToSessions(data)

                    for session in sessions {
                        manager.addSession(session)
                    }

                    print("✅ \(sessions.count)개의 세션을 Import했습니다")
                } else {
                    // 일반 텍스트로 처리
                    if let session = manager.importFromText(data) {
                        manager.addSession(session)
                    }
                }
            } else if fileExtension == "numbers" {
                // Numbers 파일 안내
                #if os(macOS)
                let alert = NSAlert()
                alert.messageText = "Numbers 파일 변환 필요"
                alert.informativeText = "Numbers 파일은 먼저 CSV로 내보내기 한 후 업로드해주세요.\n\n파일 > 내보내기 > CSV..."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "확인")
                alert.runModal()
                #endif
            }
        } catch {
            print("❌ 파일 읽기 실패: \(error)")
        }
    }

    private func parseCSVToSessions(_ csvContent: String) -> [MentoringSession] {
        var sessions: [MentoringSession] = []
        let lines = csvContent.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // 첫 줄은 헤더로 간주하고 건너뛰기
        guard lines.count > 1 else { return sessions }

        for i in 1..<lines.count {
            let line = lines[i]
            let components = parseCSVLine(line)

            // CSV 형식: 날짜,시도,변화,기대,개인만족도,관계만족도,아카데미만족도,전반적만족도,중요한것,한줄요약,액션플랜
            guard components.count >= 11 else { continue }

            var session = MentoringSession()

            // 날짜 파싱
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            if let date = dateFormatter.date(from: components[0]) {
                session.sessionDate = date
            }

            // 멘토링 전
            session.preMentoring.attemptsSinceLastTime = components[1]
            session.preMentoring.changesSinceLastTime = components[2]
            session.preMentoring.expectedChanges = components[3]
            session.preMentoring.personalLifeSatisfaction = Int(components[4]) ?? 5
            session.preMentoring.relationshipSatisfaction = Int(components[5]) ?? 5
            session.preMentoring.academySatisfaction = Int(components[6]) ?? 5
            session.preMentoring.overallLifeSatisfaction = Int(components[7]) ?? 5

            // 멘토링 후
            session.postMentoring.importantThings = components[8]
            session.postMentoring.meaningfulSummary = components[9]
            session.postMentoring.actionPlan = components[10]

            sessions.append(session)
        }

        return sessions
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var components: [String] = []
        var currentComponent = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                components.append(currentComponent.trimmingCharacters(in: .whitespaces))
                currentComponent = ""
            } else {
                currentComponent.append(char)
            }
        }

        // 마지막 컴포넌트 추가
        components.append(currentComponent.trimmingCharacters(in: .whitespaces))

        return components
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

struct MacImportTextView: View {
    @Binding var importedText: String
    let onImport: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("텍스트 Import")
                .font(.title2)
                .padding()

            TextEditor(text: $importedText)
                .font(.system(.body, design: .monospaced))
                .border(Color.gray.opacity(0.3))
                .padding()

            HStack {
                Button("취소") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import") {
                    onImport(importedText)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(importedText.isEmpty)
            }
            .padding()
        }
        .padding()
    }
}

struct MacMentoringProfileView: View {
    @ObservedObject var manager: MentoringManager
    @State private var profile: MentoringProfile
    @State private var isEditing = false
    @State private var showingExport = false
    @State private var exportText = ""
    @Environment(\.dismiss) var dismiss

    init(manager: MentoringManager) {
        self.manager = manager
        _profile = State(initialValue: manager.profile ?? MentoringProfile())
        _isEditing = State(initialValue: manager.profile == nil)
    }

    var body: some View {
        VStack {
            HStack {
                Text("기본 정보")
                    .font(.title2)
                Spacer()
                if isEditing {
                    Button("저장") {
                        manager.saveProfile(profile)
                        isEditing = false
                        if manager.profile != nil {
                            dismiss()
                        }
                    }
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("편집") {
                        isEditing = true
                    }
                }
            }
            .padding()

            Form {
                Section {
                    Text("당부의 말씀")
                        .font(.headline)
                    Text("최초 1회만 작성하는 기본 정보입니다")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                MacProfileField(
                    title: "멘토가 알았으면 하는 자신의 배경을 적어주세요!",
                    subtitle: "(제로 베이스, 실패의 경험, 환경 등등)",
                    text: $profile.background,
                    isEditing: isEditing
                )

                MacProfileField(
                    title: "아카데미에 나갈 때의 자신의 목표를 적어주세요",
                    subtitle: "(꿈 아님, 야망 아님, 현실적인 자신의 목표)",
                    text: $profile.academyGoal,
                    isEditing: isEditing
                )

                MacProfileField(
                    title: "아카데미에서 배우고 싶은 것들을 적어주세요",
                    subtitle: "(막연한 목표가 아닌 계획이 있는 배움의 계획)",
                    text: $profile.learningPlan,
                    isEditing: isEditing
                )

                MacProfileField(
                    title: "목표를 달성하기 위해서 지금 하고있는 노력들을 적어주세요",
                    subtitle: nil,
                    text: $profile.currentEfforts,
                    isEditing: isEditing
                )

                if !isEditing {
                    Section {
                        Button {
                            exportText = manager.exportProfileToText() ?? ""
                            showingExport = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    }
                }
            }
            .formStyle(.grouped)
        }
        .sheet(isPresented: $showingExport) {
            MacExportTextView(text: exportText)
                .frame(minWidth: 600, minHeight: 400)
        }
    }
}

struct MacProfileField: View {
    let title: String
    let subtitle: String?
    @Binding var text: String
    let isEditing: Bool

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if isEditing {
                    TextEditor(text: $text)
                        .frame(minHeight: 100)
                        .border(Color.secondary.opacity(0.2))
                } else {
                    Text(text.isEmpty ? "작성되지 않음" : text)
                        .foregroundColor(text.isEmpty ? .secondary : .primary)
                }
            }
            .padding(.vertical, 4)
        }
    }
}

struct MacExportTextView: View {
    let text: String
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            HStack {
                Text("Export")
                    .font(.title2)
                Spacer()
                Button("완료") {
                    dismiss()
                }
            }
            .padding()

            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding()
            }
            .border(Color.gray.opacity(0.3))
            .padding(.horizontal)

            HStack {
                Button {
                    #if os(macOS)
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    #endif
                } label: {
                    Label("복사", systemImage: "doc.on.doc")
                }

                Button {
                    saveToFile(text)
                } label: {
                    Label("파일로 저장", systemImage: "square.and.arrow.down")
                }
            }
            .padding()
        }
        .padding()
    }

    private func saveToFile(_ text: String) {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "멘토링_프로필_\(Date().timeIntervalSince1970).txt"
        panel.allowedContentTypes = [.plainText]

        if panel.runModal() == .OK {
            if let url = panel.url {
                try? text.write(to: url, atomically: true, encoding: .utf8)
            }
        }
        #endif
    }
}
