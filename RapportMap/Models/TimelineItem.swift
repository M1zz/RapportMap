//
//  TimelineItem.swift
//  RapportMap
//
//  Created by Claude on 12/13/25.
//

import Foundation
import SwiftUI

/// 타임라인에 표시할 수 있는 모든 기록 타입을 통합하는 Enum
/// InteractionRecord, MeetingRecord, ConversationRecord, QuickMemoArchive, PersonAction을 하나의 인터페이스로 제공
enum TimelineItemType {
    case interaction(InteractionRecord)
    case meeting(MeetingRecord)
    case conversation(ConversationRecord)
    case memo(QuickMemoArchive)
    case action(PersonAction)

    /// 각 타입에서 날짜 추출 (타임라인 정렬에 사용)
    var date: Date {
        switch self {
        case .interaction(let record):
            return record.date
        case .meeting(let record):
            return record.date
        case .conversation(let record):
            return record.date  // createdDate가 아닌 date 사용
        case .memo(let archive):
            return archive.createdDate
        case .action(let action):
            // 우선순위: completedDate > lastActionDate > reminderDate
            return action.completedDate ?? action.lastActionDate ?? action.reminderDate ?? Date()
        }
    }

    /// 고유 식별자
    var id: UUID {
        switch self {
        case .interaction(let record):
            return record.id
        case .meeting(let record):
            return record.id
        case .conversation(let record):
            return record.id
        case .memo(let archive):
            return archive.id
        case .action(let action):
            return action.id
        }
    }

    /// 타입별 제목
    var title: String {
        switch self {
        case .interaction(let record):
            return record.type.title
        case .meeting(let record):
            return record.meetingType.rawValue
        case .conversation(let record):
            return record.type.title
        case .memo:
            return "빠른 메모"
        case .action(let action):
            return action.action?.title ?? "액션"
        }
    }

    /// SF Symbol 아이콘
    var icon: String {
        switch self {
        case .interaction(let record):
            return record.type.systemImage
        case .meeting:
            return "waveform.circle.fill"
        case .conversation(let record):
            return record.type.systemImage
        case .memo:
            return "note.text"
        case .action:
            return "checkmark.circle"
        }
    }

    /// 이모지 아이콘
    var emoji: String {
        switch self {
        case .interaction(let record):
            return record.type.emoji
        case .meeting(let record):
            return record.meetingType.emoji
        case .conversation(let record):
            return record.type.emoji
        case .memo:
            return "📝"
        case .action(let action):
            return action.action?.type.emoji ?? "✓"
        }
    }

    /// 타입별 색상
    var color: Color {
        switch self {
        case .interaction(let record):
            return record.type.color
        case .meeting:
            return .purple
        case .conversation(let record):
            return record.type.color
        case .memo:
            return .yellow
        case .action(let action):
            return action.action?.type == .critical ? .red : .blue
        }
    }

    /// 미리보기 텍스트 (최대 3줄)
    var previewText: String {
        switch self {
        case .interaction(let record):
            return record.notes ?? record.location ?? ""
        case .meeting(let record):
            return record.summary.isEmpty ? record.transcribedText : record.summary
        case .conversation(let record):
            return record.content
        case .memo(let archive):
            return archive.content
        case .action(let action):
            return action.note
        }
    }

    /// 중요 표시 여부
    var isImportant: Bool {
        switch self {
        case .interaction(let record):
            return record.isImportant
        case .meeting(let record):
            return record.isImportant
        case .conversation(let record):
            return record.isImportant
        case .memo:
            return false
        case .action(let action):
            return action.action?.type == .critical
        }
    }

    /// 카테고리 이름 (뱃지 표시용)
    var categoryName: String {
        switch self {
        case .interaction:
            return "상호작용"
        case .meeting:
            return "미팅"
        case .conversation:
            return "대화"
        case .memo:
            return "메모"
        case .action:
            return "액션"
        }
    }

    // MARK: - 첨부파일 관련

    /// 첨부파일이 있는지 여부
    var hasAttachments: Bool {
        switch self {
        case .interaction(let record):
            return record.hasAttachments || record.hasPhotos
        case .meeting(let record):
            return record.hasAudio
        case .conversation(let record):
            return !(record.imageDataArray?.isEmpty ?? true)
        case .memo(let archive):
            return !(archive.imageDataArray?.isEmpty ?? true)
        case .action:
            return false
        }
    }

    /// 첨부파일 개수
    var attachmentCount: Int {
        switch self {
        case .interaction(let record):
            return record.attachmentCount + record.allPhotosData.count
        case .meeting(let record):
            return record.hasAudio ? 1 : 0
        case .conversation(let record):
            return record.imageDataArray?.count ?? 0
        case .memo(let archive):
            return archive.imageDataArray?.count ?? 0
        case .action:
            return 0
        }
    }

    /// 첨부파일 타입별 아이콘 (최대 3개까지 표시)
    var attachmentIcons: [String] {
        var icons: [String] = []

        switch self {
        case .interaction(let record):
            // 이미지 첨부파일
            if !record.imageAttachments.isEmpty || record.hasPhotos {
                icons.append("photo")
            }
            // 오디오 첨부파일
            if !record.audioAttachments.isEmpty {
                icons.append("waveform")
            }
            // 문서 첨부파일
            if !record.documentAttachments.isEmpty {
                icons.append("doc")
            }
        case .meeting:
            icons.append("waveform")
        case .conversation, .memo:
            icons.append("photo")
        case .action:
            break
        }

        return Array(icons.prefix(3))
    }

    /// 상호작용 레코드의 첨부파일 목록 (InteractionRecord인 경우만)
    var interactionAttachments: [AttachmentFile]? {
        if case .interaction(let record) = self {
            return record.attachments
        }
        return nil
    }

    /// 상호작용 레코드의 사진 데이터 목록
    var photoDataList: [Data]? {
        switch self {
        case .interaction(let record):
            return record.allPhotosData
        case .conversation(let record):
            return record.imageDataArray
        case .memo(let archive):
            return archive.imageDataArray
        default:
            return nil
        }
    }
}

/// 타임라인 아이템 (Identifiable 구현)
struct TimelineItem: Identifiable {
    let id: UUID
    let type: TimelineItemType
    let date: Date

    init(type: TimelineItemType) {
        self.type = type
        self.date = type.date
        self.id = type.id
    }
}
