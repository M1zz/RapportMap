//
//  MeetingRecord.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation
import SwiftData

@Model
final class MeetingRecord {
    var id: UUID
    var date: Date
    var meetingType: MeetingType
    var audioFileURL: String?  // 음성 파일 경로
    var transcribedText: String  // 음성 → 텍스트 변환 결과
    var summary: String  // 요약
    var duration: TimeInterval  // 녹음 길이
    
    // 관계
    var person: Person?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        meetingType: MeetingType = .general,
        audioFileURL: String? = nil,
        transcribedText: String = "",
        summary: String = "",
        duration: TimeInterval = 0
    ) {
        self.id = id
        self.date = date
        self.meetingType = meetingType
        self.audioFileURL = audioFileURL
        self.transcribedText = transcribedText
        self.summary = summary
        self.duration = duration
    }
}

// MARK: - Helpers
extension MeetingRecord {
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var hasAudio: Bool {
        audioFileURL != nil
    }
}

enum MeetingType: String, Codable, CaseIterable {
    case mentoring = "멘토링"
    case meal = "식사"
    case coffee = "커피"
    case general = "일반 대화"
    case presentation = "발표/회의"
    case oneOnOne = "1:1 미팅"
    
    var emoji: String {
        switch self {
        case .mentoring: return "🧑‍🏫"
        case .meal: return "🍱"
        case .coffee: return "☕️"
        case .general: return "💬"
        case .presentation: return "📊"
        case .oneOnOne: return "👥"
        }
    }
}
