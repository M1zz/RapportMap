//
//  MentoringSession.swift
//  RapportMap
//
//  멘토링 세션 - 음성파일 + 전사 텍스트 + Numbers 링크를 로우데이터로 보존
//

import Foundation
import SwiftData

@Model
final class MentoringSession: Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var title: String = ""              // "1차 멘토링", "커리어 상담" 등

    // MARK: - 로우 데이터
    var transcript: String = ""         // 음성 전사 텍스트
    var audioFileName: String = ""      // 연결된 음성 파일명 (참조용)
    var numbersURL: String?             // 이 세션 관련 Numbers 공유 링크

    // MARK: - 정리된 내용
    var summary: String = ""            // 세션 요약 (직접 작성)

    @Relationship(deleteRule: .nullify)
    var person: Person?

    init(
        title: String = "",
        date: Date = Date(),
        transcript: String = "",
        audioFileName: String = "",
        numbersURL: String? = nil
    ) {
        self.id = UUID()
        self.title = title
        self.date = date
        self.transcript = transcript
        self.audioFileName = audioFileName
        self.numbersURL = numbersURL
    }
}
