//
//  QuickMemoArchive.swift
//  RapportMap
//
//  아카이브된 빠른 메모 모델
//

import Foundation
import SwiftData

/// 아카이브된 빠른 메모
/// 사용자가 대화 후 작성한 메모를 저장하고 나중에 다시 볼 수 있도록 함
@Model
final class QuickMemoArchive {
    var id: UUID
    var content: String
    var createdDate: Date

    /// 이 메모와 연관된 사람
    var person: Person?

    init(content: String, createdDate: Date = Date()) {
        self.id = UUID()
        self.content = content
        self.createdDate = createdDate
    }
}
