//
//  SharedDocument.swift
//  RapportMap
//
//  멘티와 공유하는 문서 링크 (iCloud Numbers, Google Sheets 등)
//

import Foundation

/// 공유 문서 타입
enum SharedDocumentType: String, Codable, CaseIterable {
    case numbers = "numbers"        // iCloud Numbers
    case pages = "pages"            // iCloud Pages
    case keynote = "keynote"        // iCloud Keynote
    case googleSheets = "gsheets"   // Google Sheets
    case googleDocs = "gdocs"       // Google Docs
    case notion = "notion"          // Notion
    case other = "other"            // 기타
    
    var title: String {
        switch self {
        case .numbers: return "Numbers"
        case .pages: return "Pages"
        case .keynote: return "Keynote"
        case .googleSheets: return "Google Sheets"
        case .googleDocs: return "Google Docs"
        case .notion: return "Notion"
        case .other: return "기타"
        }
    }
    
    var icon: String {
        switch self {
        case .numbers: return "tablecells"
        case .pages: return "doc.text"
        case .keynote: return "play.rectangle"
        case .googleSheets: return "tablecells.badge.ellipsis"
        case .googleDocs: return "doc.text.fill"
        case .notion: return "note.text"
        case .other: return "link"
        }
    }
    
    /// URL에서 문서 타입 자동 감지
    static func detect(from url: String) -> SharedDocumentType {
        let lowercased = url.lowercased()
        
        if lowercased.contains("icloud.com/numbers") {
            return .numbers
        } else if lowercased.contains("icloud.com/pages") {
            return .pages
        } else if lowercased.contains("icloud.com/keynote") {
            return .keynote
        } else if lowercased.contains("docs.google.com/spreadsheets") {
            return .googleSheets
        } else if lowercased.contains("docs.google.com/document") {
            return .googleDocs
        } else if lowercased.contains("notion.so") || lowercased.contains("notion.site") {
            return .notion
        } else {
            return .other
        }
    }
}

/// 공유 문서 정보
struct SharedDocument: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var title: String
    var url: String
    var type: SharedDocumentType
    var createdDate: Date
    var lastAccessedDate: Date?
    var notes: String?
    
    init(
        id: UUID = UUID(),
        title: String,
        url: String,
        type: SharedDocumentType? = nil,
        createdDate: Date = Date(),
        lastAccessedDate: Date? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.title = title
        self.url = url
        self.type = type ?? SharedDocumentType.detect(from: url)
        self.createdDate = createdDate
        self.lastAccessedDate = lastAccessedDate
        self.notes = notes
    }
}

// MARK: - Person Extension for Shared Documents

extension Person {
    /// 공유 문서 목록 가져오기
    var sharedDocuments: [SharedDocument] {
        get {
            sharedDocumentLinks.compactMap { jsonString in
                guard let data = jsonString.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(SharedDocument.self, from: data)
            }
        }
        set {
            sharedDocumentLinks = newValue.compactMap { doc in
                guard let data = try? JSONEncoder().encode(doc) else { return nil }
                return String(data: data, encoding: .utf8)
            }
        }
    }
    
    /// 공유 문서 추가
    func addSharedDocument(title: String, url: String, notes: String? = nil) {
        var docs = sharedDocuments
        let newDoc = SharedDocument(title: title, url: url, notes: notes)
        docs.append(newDoc)
        sharedDocuments = docs
    }
    
    /// 공유 문서 제거
    func removeSharedDocument(id: UUID) {
        var docs = sharedDocuments
        docs.removeAll { $0.id == id }
        sharedDocuments = docs
    }
    
    /// 공유 문서 업데이트
    func updateSharedDocument(_ document: SharedDocument) {
        var docs = sharedDocuments
        if let index = docs.firstIndex(where: { $0.id == document.id }) {
            docs[index] = document
            sharedDocuments = docs
        }
    }
    
    /// 문서 접근 시간 업데이트
    func markDocumentAccessed(id: UUID) {
        var docs = sharedDocuments
        if let index = docs.firstIndex(where: { $0.id == id }) {
            var doc = docs[index]
            doc.lastAccessedDate = Date()
            docs[index] = doc
            sharedDocuments = docs
        }
    }
}
