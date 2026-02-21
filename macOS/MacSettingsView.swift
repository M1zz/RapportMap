//
//  MacSettingsView.swift
//  mac
//
//  macOS용 설정 화면 - CloudKit 백업/복원/초기화
//

import SwiftUI
import SwiftData

struct MacSettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @StateObject private var mentoringManager = MentoringManager()

    @State private var showingBackupAlert = false
    @State private var showingRestoreAlert = false
    @State private var showingRestoreOptionsAlert = false
    @State private var showingDeleteAlert = false
    @State private var showingDeleteOptionsSheet = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingSuccess = false
    @State private var successMessage = ""
    @State private var backupInfo: (date: Date, peopleCount: Int)?
    @State private var isDebugMode = false
    @State private var showingStatistics = false

    var body: some View {
        VStack(spacing: 0) {
            // 제목 헤더
            HStack {
                Text("설정")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Button("완료") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 메인 컨텐츠
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - 통계 섹션
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("분석")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            Button {
                                showingStatistics = true
                            } label: {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundStyle(.purple)
                                    Text("멘토링 통계")
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Text("멘토링 활동에 대한 통계와 인사이트를 확인하세요.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                    }

                    // MARK: - Debug 섹션
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("개발자 도구")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                Spacer()

                                Button(action: {}) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "ladybug.fill")
                                        Text(isDebugMode ? "ON" : "OFF")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                    }
                                    .foregroundStyle(isDebugMode ? .green : .secondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(isDebugMode ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                                    )
                                }
                                .buttonStyle(.plain)
                                .onTapGesture(count: 2) {
                                    isDebugMode.toggle()
                                }
                            }

                            if isDebugMode {
                                Divider()

                                VStack(spacing: 8) {
                                    Button {
                                        generateAllDummyData()
                                    } label: {
                                        HStack {
                                            Image(systemName: "doc.on.doc.fill")
                                            Text("모든 더미 데이터 생성")
                                            Spacer()
                                        }
                                    }

                                    Divider()

                                    Button {
                                        generateDummyPeople()
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.3.fill")
                                            Text("더미 사람 생성 (5명)")
                                            Spacer()
                                        }
                                    }

                                    Button {
                                        generateDummyMentoringSessions()
                                    } label: {
                                        HStack {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                            Text("더미 멘토링 생성 (10개)")
                                            Spacer()
                                        }
                                    }
                                }

                                Text("💡 더미 데이터를 생성하여 앱의 모든 기능을 테스트해보세요")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 4)
                            }
                        }
                        .padding()
                    }

                    // MARK: - 백업 정보 섹션
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("백업 상태")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            if let info = backupInfo {
                                HStack {
                                    Text("마지막 백업:")
                                    Spacer()
                                    Text(formatDate(info.date))
                                        .fontWeight(.medium)
                                }

                                HStack {
                                    Text("백업된 데이터:")
                                    Spacer()
                                    Text("\(info.peopleCount)명")
                                        .fontWeight(.medium)
                                }
                            } else if let lastBackup = cloudKitManager.lastBackupDate {
                                HStack {
                                    Text("로컬 백업 기록:")
                                    Spacer()
                                    Text(formatDate(lastBackup))
                                        .fontWeight(.medium)
                                }
                            } else {
                                Text("아직 백업된 데이터가 없습니다")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                    }

                    // MARK: - 백업/복원 섹션
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("데이터 관리")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            // 백업 버튼
                            Button {
                                showingBackupAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.up")
                                    Text("iCloud에 백업")
                                    Spacer()
                                    if cloudKitManager.isBackingUp {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .disabled(cloudKitManager.isBackingUp || cloudKitManager.isRestoring || cloudKitManager.isDeleting)

                            Divider()

                            // 복원 버튼
                            Button {
                                showingRestoreOptionsAlert = true
                            } label: {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.down")
                                    Text("iCloud에서 복원")
                                    Spacer()
                                    if cloudKitManager.isRestoring {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .disabled(cloudKitManager.isBackingUp || cloudKitManager.isRestoring || cloudKitManager.isDeleting)

                            Text("백업: 현재 데이터를 iCloud에 저장합니다 (기존 백업을 덮어씁니다).\n복원: iCloud의 데이터를 불러옵니다.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                        .padding()
                    }

                    // MARK: - 초기화 섹션
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("위험 구역")
                                .font(.headline)
                                .foregroundStyle(.red)

                            Button {
                                showingDeleteOptionsSheet = true
                            } label: {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("데이터 초기화")
                                    Spacer()
                                    if cloudKitManager.isDeleting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                            }
                            .foregroundStyle(.red)
                            .disabled(cloudKitManager.isBackingUp || cloudKitManager.isRestoring || cloudKitManager.isDeleting)

                            Text("⚠️ 데이터 삭제는 되돌릴 수 없습니다. 신중하게 선택하세요.")
                                .font(.caption)
                                .foregroundStyle(.red)
                                .padding(.top, 4)
                        }
                        .padding()
                    }

                    // MARK: - 정보 섹션
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("CloudKit 정보")
                                .font(.headline)
                                .foregroundStyle(.secondary)

                            MacInfoRow(
                                icon: "checkmark.shield",
                                title: "자동 동기화",
                                description: "데이터는 수동으로만 백업/복원됩니다"
                            )

                            Divider()

                            MacInfoRow(
                                icon: "lock.shield",
                                title: "개인정보 보호",
                                description: "모든 데이터는 개인 iCloud에만 저장됩니다"
                            )

                            Divider()

                            MacInfoRow(
                                icon: "arrow.triangle.2.circlepath",
                                title: "데이터 병합",
                                description: "복원 시 기존 데이터와 병합됩니다"
                            )
                        }
                        .padding()
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 500, minHeight: 600)
        .alert("데이터 백업", isPresented: $showingBackupAlert) {
            Button("취소", role: .cancel) { }
            Button("백업") {
                performBackup()
            }
        } message: {
            Text("현재 데이터를 iCloud에 백업하시겠습니까?\n\n기존 백업이 있다면 덮어씁니다.")
        }
        .alert("데이터 복원", isPresented: $showingRestoreOptionsAlert) {
            Button("취소", role: .cancel) { }
            Button("병합") {
                performRestore(replaceExisting: false)
            }
            Button("교체", role: .destructive) {
                performRestore(replaceExisting: true)
            }
        } message: {
            Text("iCloud 데이터를 어떻게 복원하시겠습니까?\n\n병합: 기존 데이터 유지하며 추가\n교체: 기존 데이터 삭제 후 복원")
        }
        .confirmationDialog("데이터 초기화", isPresented: $showingDeleteOptionsSheet, titleVisibility: .visible) {
            Button("로컬 데이터만 삭제", role: .destructive) {
                performDeleteLocal()
            }
            Button("클라우드 백업만 삭제", role: .destructive) {
                performDeleteCloud()
            }
            Button("모든 데이터 삭제", role: .destructive) {
                performDeleteAll()
            }
            Button("취소", role: .cancel) { }
        } message: {
            Text("어떤 데이터를 삭제하시겠습니까?\n\n⚠️ 이 작업은 되돌릴 수 없습니다.")
        }
        .alert("오류", isPresented: $showingError) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("완료", isPresented: $showingSuccess) {
            Button("확인", role: .cancel) { }
        } message: {
            Text(successMessage)
        }
        .task {
            await loadBackupInfo()
        }
        .sheet(isPresented: $showingStatistics) {
            MacStatisticsView()
        }
    }

    // MARK: - Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ko_KR")
        return formatter.string(from: date)
    }

    private func loadBackupInfo() async {
        do {
            backupInfo = try await cloudKitManager.getBackupInfo()
        } catch {
            print("⚠️ [macOS Settings] 백업 정보 로드 실패: \(error.localizedDescription)")
        }
    }

    private func performBackup() {
        Task {
            do {
                try await cloudKitManager.backupToCloud(context: context)
                successMessage = "백업이 완료되었습니다"
                showingSuccess = true
                await loadBackupInfo()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func performRestore(replaceExisting: Bool) {
        Task {
            do {
                try await cloudKitManager.restoreFromCloud(context: context, replaceExisting: replaceExisting)
                successMessage = replaceExisting ? "데이터가 교체되었습니다" : "데이터가 병합되었습니다"
                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func performDeleteLocal() {
        Task {
            do {
                try await cloudKitManager.deleteLocalData(context: context)
                successMessage = "로컬 데이터가 삭제되었습니다"
                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func performDeleteCloud() {
        Task {
            do {
                try await cloudKitManager.deleteCloudBackup()
                successMessage = "클라우드 백업이 삭제되었습니다"
                showingSuccess = true
                backupInfo = nil
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func performDeleteAll() {
        Task {
            do {
                try await cloudKitManager.deleteAllData(context: context)
                successMessage = "모든 데이터가 삭제되었습니다"
                showingSuccess = true
                backupInfo = nil
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    // MARK: - Debug Methods

    private func generateAllDummyData() {
        DataSeeder.seedDummyData(context: context)
        generateDummyMentoringSessions()

        successMessage = "모든 더미 데이터가 생성되었습니다"
        showingSuccess = true
    }

    private func generateDummyPeople() {
        DataSeeder.seedDummyData(context: context)

        successMessage = "더미 사람 데이터가 생성되었습니다"
        showingSuccess = true
    }

    private func generateDummyMentoringSessions() {
        for i in 0..<10 {
            var session = MentoringSession()
            session.sessionDate = Date().addingTimeInterval(-Double(i * 14) * 24 * 3600)

            // 멘토링 전
            session.preMentoring.attemptsSinceLastTime = "테스트 시도 내용 \(i + 1)"
            session.preMentoring.changesSinceLastTime = "테스트 변화 내용 \(i + 1)"
            session.preMentoring.expectedChanges = "테스트 기대 변화 \(i + 1)"
            session.preMentoring.personalLifeSatisfaction = Int.random(in: 3...9)
            session.preMentoring.relationshipSatisfaction = Int.random(in: 3...9)
            session.preMentoring.academySatisfaction = Int.random(in: 3...9)
            session.preMentoring.overallLifeSatisfaction = Int.random(in: 3...9)

            // 멘토링 후
            session.postMentoring.conversationCompleteness = Int.random(in: 4...10)
            session.postMentoring.listeningQuality = Int.random(in: 4...10)
            session.postMentoring.helpfulness = Int.random(in: 4...10)
            session.postMentoring.overallEvaluation = Int.random(in: 4...10)
            session.postMentoring.importantThings = "중요했던 것: 테스트 내용 \(i + 1)"
            session.postMentoring.meaningfulSummary = "의미있었던 한 줄: 테스트 요약 \(i + 1)"
            session.postMentoring.actionPlan = "다음 액션: 테스트 계획 \(i + 1)"

            mentoringManager.addSession(session)
        }

        print("✅ 10개의 더미 멘토링 세션 생성됨")
    }
}

// MARK: - Info Row Component

struct MacInfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    MacSettingsView()
}
