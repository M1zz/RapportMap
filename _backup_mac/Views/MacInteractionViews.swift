//
//  MacInteractionViews.swift
//  mac
//
//  macOS용 상호작용 관련 뷰들
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Mac Create Interaction Sheet

struct MacCreateInteractionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let person: Person
    let interactionType: InteractionType
    let context: ModelContext

    @State private var date = Date()
    @State private var notes = ""
    @State private var location = ""
    @State private var selectedFiles: [URL] = []
    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // 헤더
            HStack {
                Text("새 \(interactionType.title) 기록")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                Button("취소") {
                    dismiss()
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // 폼 (스크롤 가능)
            ScrollView {
                Form {
                Section {
                    HStack {
                        Text(interactionType.emoji)
                            .font(.largeTitle)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(interactionType.title)
                                .font(.headline)
                            Text("새로운 \(interactionType.title) 기록을 추가하세요")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("날짜 및 시간") {
                    DatePicker("날짜와 시간", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.graphical)
                }

                Section("장소") {
                    TextField("어디서 만났나요?", text: $location)
                }

                Section("메모") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }

                Section("첨부파일") {
                    VStack(alignment: .leading, spacing: 12) {
                        // 드롭 영역
                        VStack(spacing: 8) {
                            if selectedFiles.isEmpty {
                                VStack(spacing: 8) {
                                    Image(systemName: "arrow.down.doc.fill")
                                        .font(.largeTitle)
                                        .foregroundStyle(.secondary)
                                    Text("파일을 여기로 드래그하거나 클릭하여 선택")
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                                        .foregroundStyle(.secondary.opacity(0.3))
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectFiles()
                                }
                            } else {
                                ForEach(selectedFiles, id: \.self) { url in
                                    HStack {
                                        Image(systemName: iconForFile(url))
                                            .foregroundStyle(colorForFile(url))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(url.lastPathComponent)
                                                .font(.subheadline)
                                            if let fileSize = fileSize(for: url) {
                                                Text(fileSize)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        Spacer()

                                        Button {
                                            selectedFiles.removeAll { $0 == url }
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.secondary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.vertical, 4)
                                }

                                Button {
                                    selectFiles()
                                } label: {
                                    Label("파일 추가", systemImage: "plus.circle.fill")
                                }
                            }
                        }
                        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                            handleDrop(providers: providers)
                            return true
                        }
                    }
                }
                }
                .formStyle(.grouped)
            }

            Divider()

            // 저장 버튼
            HStack {
                Spacer()
                Button("저장") {
                    saveRecord()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
    }

    private func saveRecord() {
        let finalNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes
        let finalLocation = location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location

        let record = person.addInteractionRecord(
            type: interactionType,
            date: date,
            notes: finalNotes,
            duration: nil,
            location: finalLocation,
            relatedMeetingRecord: nil
        )

        // 첨부파일 추가
        for fileURL in selectedFiles {
            if let fileData = try? Data(contentsOf: fileURL) {
                let fileType = AttachmentFileType.from(fileName: fileURL.lastPathComponent)
                let attachment = AttachmentFile(
                    fileName: fileURL.lastPathComponent,
                    fileType: fileType,
                    fileData: fileData
                )
                context.insert(attachment)
                record.addAttachment(attachment)
            }
        }

        do {
            try context.save()
            print("✅ 새 상호작용 기록 생성 (첨부파일 \(selectedFiles.count)개)")
            dismiss()
        } catch {
            print("❌ 상호작용 기록 생성 실패: \(error)")
        }
    }

    private func selectFiles() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.message = "첨부할 파일을 선택하세요"

        panel.begin { response in
            if response == .OK {
                selectedFiles.append(contentsOf: panel.urls)
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                if let url = url {
                    DispatchQueue.main.async {
                        // 이미 추가된 파일인지 확인
                        if !selectedFiles.contains(url) {
                            selectedFiles.append(url)
                        }
                    }
                }
            }
        }
        return true
    }

    private func iconForFile(_ url: URL) -> String {
        let fileType = AttachmentFileType.from(fileName: url.lastPathComponent)
        return fileType.icon
    }

    private func colorForFile(_ url: URL) -> Color {
        let fileType = AttachmentFileType.from(fileName: url.lastPathComponent)
        return fileType.color
    }

    private func fileSize(for url: URL) -> String? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}
