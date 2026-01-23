import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

@Model
final class AttachmentFile {
    var id: UUID
    var fileName: String
    var fileType: AttachmentFileType
    var createdDate: Date

    @Attribute(.externalStorage)
    var fileData: Data

    @Attribute(.externalStorage)
    var thumbnailData: Data? // 이미지/비디오의 경우 썸네일

    @Relationship(deleteRule: .nullify, inverse: \InteractionRecord.attachments)
    var interactionRecord: InteractionRecord?

    init(
        id: UUID = UUID(),
        fileName: String,
        fileType: AttachmentFileType,
        fileData: Data,
        thumbnailData: Data? = nil,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.fileName = fileName
        self.fileType = fileType
        self.fileData = fileData
        self.thumbnailData = thumbnailData
        self.createdDate = createdDate
    }
}

enum AttachmentFileType: String, Codable {
    case image = "image"
    case audio = "audio"
    case video = "video"
    case pdf = "pdf"
    case document = "document"
    case other = "other"

    var icon: String {
        switch self {
        case .image:
            return "photo"
        case .audio:
            return "waveform"
        case .video:
            return "video"
        case .pdf:
            return "doc.text"
        case .document:
            return "doc"
        case .other:
            return "doc.fill"
        }
    }

    var color: Color {
        switch self {
        case .image:
            return .blue
        case .audio:
            return .purple
        case .video:
            return .red
        case .pdf:
            return .orange
        case .document:
            return .green
        case .other:
            return .gray
        }
    }

    static func from(fileName: String) -> AttachmentFileType {
        let ext = (fileName as NSString).pathExtension.lowercased()

        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "heif":
            return .image
        case "mp3", "m4a", "wav", "aac":
            return .audio
        case "mp4", "mov", "avi":
            return .video
        case "pdf":
            return .pdf
        case "doc", "docx", "txt", "rtf", "pages":
            return .document
        default:
            return .other
        }
    }
}

extension AttachmentFile {
    var fileSize: String {
        let bytes = fileData.count
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: createdDate)
    }
}
