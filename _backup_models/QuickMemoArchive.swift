//
//  QuickMemoArchive.swift
//  RapportMap
//
//  아카이브된 빠른 메모 모델
//

import Foundation
import SwiftData

// MARK: - ⚠️ DEPRECATED
// 이 모델은 Record.swift의 통합 Record 모델로 대체되었습니다.
// 기존 데이터 호환성을 위해 유지되며, DataSeeder.migrateToUnifiedRecords()를 통해
// 데이터가 Record 모델로 마이그레이션됩니다.
// 향후 버전에서 삭제될 예정입니다.

/// 아카이브된 빠른 메모
/// 사용자가 대화 후 작성한 메모를 저장하고 나중에 다시 볼 수 있도록 함
@Model
final class QuickMemoArchive {
    var id: UUID
    var content: String
    var createdDate: Date

    /// 첨부된 이미지 데이터 (여러 장 가능)
    @Attribute(.externalStorage)
    var imageDataArray: [Data]?

    /// 이 메모와 연관된 사람
    var person: Person?

    init(content: String, createdDate: Date = Date(), imageDataArray: [Data]? = nil) {
        self.id = UUID()
        self.content = content
        self.createdDate = createdDate
        self.imageDataArray = imageDataArray
    }
}
