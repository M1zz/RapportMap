//
//  SettingsView.swift
//  RapportMap
//
//  CloudKit 백업/복원/초기화 설정 화면
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var cloudKitManager = CloudKitManager.shared

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

    var body: some View {
        NavigationStack {
            List {
                // MARK: - 백업 정보 섹션
                Section {
                    if let info = backupInfo {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("마지막 백업")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(formatDate(info.date))
                                    .fontWeight(.medium)
                            }

                            HStack {
                                Text("백업된 데이터")
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(info.peopleCount)명")
                                    .fontWeight(.medium)
                            }
                        }
                    } else if let lastBackup = cloudKitManager.lastBackupDate {
                        HStack {
                            Text("로컬 백업 기록")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(formatDate(lastBackup))
                                .fontWeight(.medium)
                        }
                    } else {
                        Text("아직 백업된 데이터가 없습니다")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("백업 상태")
                }

                // MARK: - 백업/복원 섹션
                Section {
                    // 백업 버튼
                    Button {
                        showingBackupAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                                .foregroundStyle(.blue)
                            Text("iCloud에 백업")
                            Spacer()
                            if cloudKitManager.isBackingUp {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(cloudKitManager.isBackingUp || cloudKitManager.isRestoring || cloudKitManager.isDeleting)

                    // 복원 버튼
                    Button {
                        showingRestoreOptionsAlert = true
                    } label: {
                        HStack {
                            Image(systemName: "icloud.and.arrow.down")
                                .foregroundStyle(.green)
                            Text("iCloud에서 복원")
                            Spacer()
                            if cloudKitManager.isRestoring {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(cloudKitManager.isBackingUp || cloudKitManager.isRestoring || cloudKitManager.isDeleting)
                } header: {
                    Text("데이터 관리")
                } footer: {
                    Text("백업: 현재 데이터를 iCloud에 저장합니다 (기존 백업을 덮어씁니다).\n복원: iCloud의 데이터를 불러옵니다.")
                }

                // MARK: - 초기화 섹션
                Section {
                    Button(role: .destructive) {
                        showingDeleteOptionsSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("데이터 초기화")
                            Spacer()
                            if cloudKitManager.isDeleting {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(cloudKitManager.isBackingUp || cloudKitManager.isRestoring || cloudKitManager.isDeleting)
                } header: {
                    Text("위험 구역")
                } footer: {
                    Text("⚠️ 데이터 삭제는 되돌릴 수 없습니다. 신중하게 선택하세요.")
                        .foregroundStyle(.red)
                }

                // MARK: - 정보 섹션
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        InfoRow(
                            icon: "checkmark.shield",
                            title: "자동 동기화",
                            description: "데이터는 수동으로만 백업/복원됩니다"
                        )

                        InfoRow(
                            icon: "lock.shield",
                            title: "개인정보 보호",
                            description: "모든 데이터는 개인 iCloud에만 저장됩니다"
                        )

                        InfoRow(
                            icon: "arrow.triangle.2.circlepath",
                            title: "데이터 병합",
                            description: "복원 시 기존 데이터와 병합됩니다"
                        )
                    }
                    .font(.caption)
                } header: {
                    Text("CloudKit 정보")
                }
            }
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
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
            print("⚠️ [Settings] 백업 정보 로드 실패: \(error.localizedDescription)")
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
}

// MARK: - Info Row Component

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .modelContainer(for: [Person.self])
}
