import Foundation
import SwiftData
import SwiftUI

@Model
final class InteractionRecord {
    var id: UUID
    var date: Date
    var type: InteractionType
    var notes: String?
    var duration: TimeInterval? // 만남의 경우 지속 시간
    var location: String? // 만남 장소
    var isImportant: Bool = false // 중요도 표시
    
    // 상호작용 사진들 (여러 장 저장 가능)
    @Attribute(.externalStorage)
    var photoData: Data? // 레거시 호환용 (단일 사진)
    
    // 여러 장의 사진 저장 (새로운 방식)
    @Attribute(.externalStorage)
    var photosData: [Data] = [] // 여러 장의 사진을 배열로 저장
    
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    // 연관된 미팅 기록 (멘토링 상호작용의 경우 녹음 파일과 연결)
    @Relationship(deleteRule: .nullify)
    var relatedMeetingRecord: MeetingRecord?
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        type: InteractionType,
        notes: String? = nil,
        duration: TimeInterval? = nil,
        location: String? = nil,
        isImportant: Bool = false,
        photoData: Data? = nil,
        photosData: [Data] = [],
        relatedMeetingRecord: MeetingRecord? = nil
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.notes = notes
        self.duration = duration
        self.location = location
        self.isImportant = isImportant
        self.photoData = photoData
        self.photosData = photosData
        self.relatedMeetingRecord = relatedMeetingRecord
    }
}

enum InteractionType: String, Codable, CaseIterable {
    case mentoring = "mentoring"
    case meal = "meal"
    case contact = "contact"
    case meeting = "meeting"
    case call = "call"
    case message = "message"
    
    var title: String {
        switch self {
        case .mentoring: return "멘토링"
        case .meal: return "식사"
        case .contact: return "스몰토크"
        case .meeting: return "만남"
        case .call: return "통화"
        case .message: return "메시지"
        }
    }
    
    var emoji: String {
        switch self {
        case .mentoring: return "🧑‍🏫"
        case .meal: return "🍽️"
        case .contact: return "💬"
        case .meeting: return "🤝"
        case .call: return "📞"
        case .message: return "💌"
        }
    }
    
    var systemImage: String {
        switch self {
        case .mentoring: return "person.badge.clock"
        case .meal: return "fork.knife"
        case .contact: return "bubble.left"
        case .meeting: return "person.2"
        case .call: return "phone"
        case .message: return "message"
        }
    }
    
    var color: Color {
        switch self {
        case .mentoring: return .blue
        case .meal: return .green
        case .contact: return .orange
        case .meeting: return .purple
        case .call: return .red
        case .message: return .pink
        }
    }
}

extension InteractionRecord {
    
    var isRecent: Bool {
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        return daysSince <= 3
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)시간 \(remainingMinutes)분"
        } else {
            return "\(minutes)분"
        }
    }
    
    /// 사진이 있는지 확인 (레거시 photoData 또는 새로운 photosData)
    var hasPhotos: Bool {
        return photoData != nil || !photosData.isEmpty
    }
    
    /// 모든 사진 데이터를 배열로 반환 (레거시와 새 방식 통합)
    var allPhotosData: [Data] {
        var photos: [Data] = []
        
        // 레거시 photoData가 있으면 추가
        if let photoData = photoData {
            photos.append(photoData)
        }
        
        // 새로운 photosData 추가
        photos.append(contentsOf: photosData)
        
        return photos
    }
    
    /// 사진 추가 (새로운 방식으로 저장)
    func addPhoto(_ imageData: Data) {
        photosData.append(imageData)
    }
    
    /// 특정 인덱스의 사진 삭제
    func removePhoto(at index: Int) {
        guard index >= 0 && index < photosData.count else { return }
        photosData.remove(at: index)
    }
    
    /// 모든 사진 삭제
    func removeAllPhotos() {
        photoData = nil
        photosData.removeAll()
    }
    
    /// 레거시 photoData를 새로운 photosData로 마이그레이션
    func migratePhotoToPhotos() {
        if let oldPhotoData = photoData, !photosData.contains(oldPhotoData) {
            photosData.insert(oldPhotoData, at: 0)
            photoData = nil // 마이그레이션 후 레거시 필드는 제거
        }
    }
}
