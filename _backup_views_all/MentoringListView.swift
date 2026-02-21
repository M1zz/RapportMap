import SwiftUI
import UniformTypeIdentifiers

struct MentoringListView: View {
    @StateObject private var manager = MentoringManager()
    @State private var showingNewSession = false
    @State private var showingProfileEditor = false
    @State private var showingImportSheet = false
    @State private var showingFileImporter = false
    @State private var importedText = ""

    var body: some View {
        NavigationView {
            List {
                // 프로필 섹션
                Section {
                    if manager.profile != nil {
                        NavigationLink(destination: MentoringProfileView(profile: Binding(
                            get: { manager.profile ?? MentoringProfile() },
                            set: { manager.profile = $0 }
                        ))) {
                            Label("기본 정보 (최초 1회)", systemImage: "person.text.rectangle")
                        }
                    } else {
                        Button {
                            showingProfileEditor = true
                        } label: {
                            Label("기본 정보 작성하기", systemImage: "person.text.rectangle")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    Text("멘토링 프로필")
                }

                // 세션 목록
                Section {
                    ForEach(manager.sessions) { session in
                        NavigationLink(destination: MentoringSessionDetailView(session: session, manager: manager)) {
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
                    .onDelete(perform: deleteSessions)
                } header: {
                    Text("멘토링 세션")
                }
            }
            .navigationTitle("멘토링")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label("Numbers/CSV 파일 Import", systemImage: "tablecells")
                        }

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
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingNewSession = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NavigationView {
                    MentoringSessionEditView(session: MentoringSession(), manager: manager)
                }
            }
            .sheet(isPresented: $showingProfileEditor) {
                NavigationView {
                    MentoringProfileView(profile: Binding(
                        get: { manager.profile ?? MentoringProfile() },
                        set: { manager.profile = $0 }
                    ))
                }
            }
            .sheet(isPresented: $showingImportSheet) {
                NavigationView {
                    ImportTextView(importedText: $importedText, onImport: { text in
                        if let session = manager.importFromText(text) {
                            manager.addSession(session)
                            showingImportSheet = false
                        }
                    })
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.commaSeparatedText, .tabSeparatedText, UTType(filenameExtension: "numbers") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result: result)
            }
        }
    }

    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Security-scoped resource access
            guard url.startAccessingSecurityScopedResource() else {
                print("❌ 파일 접근 권한 없음")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let fileExtension = url.pathExtension.lowercased()

                if fileExtension == "csv" || fileExtension == "txt" {
                    // CSV 파일 처리
                    let data = try String(contentsOf: url, encoding: .utf8)
                    let sessions = parseCSVToSessions(data)

                    for session in sessions {
                        manager.addSession(session)
                    }

                    print("✅ \(sessions.count)개의 세션을 Import했습니다")
                } else if fileExtension == "numbers" {
                    // Numbers 파일은 직접 파싱이 어렵기 때문에 안내 메시지
                    print("⚠️ Numbers 파일은 먼저 CSV로 내보내기 한 후 업로드해주세요")
                }
            } catch {
                print("❌ 파일 읽기 실패: \(error)")
            }

        case .failure(let error):
            print("❌ 파일 선택 실패: \(error)")
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

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = manager.sessions[index]
            manager.deleteSession(session)
        }
    }

    private func importFromClipboard() {
        #if os(iOS)
        if let text = UIPasteboard.general.string {
            if let session = manager.importFromText(text) {
                manager.addSession(session)
            }
        }
        #endif
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월 d일"
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }
}

struct ImportTextView: View {
    @Binding var importedText: String
    let onImport: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            TextEditor(text: $importedText)
                .font(.system(.body, design: .monospaced))
                .padding()

            Button("Import") {
                onImport(importedText)
            }
            .buttonStyle(.borderedProminent)
            .disabled(importedText.isEmpty)
            .padding()
        }
        .navigationTitle("텍스트 Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("취소") {
                    dismiss()
                }
            }
        }
    }
}
