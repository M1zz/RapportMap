//
//  PersonContext.swift
//  RapportMap
//
//  Created by hyunho lee on 11/6/25.
//

import Foundation
import SwiftData

@Model
final class PersonContext {
    var id: UUID
    var category: ContextCategory
    var label: String
    var value: String
    var date: Date? // importantDates용
    var reminderEnabled: Bool
    var order: Int
    
    @Relationship(deleteRule: .nullify)
    var person: Person?
    
    init(
        id: UUID = UUID(),
        category: ContextCategory,
        label: String,
        value: String,
        date: Date? = nil,
        reminderEnabled: Bool = false,
        order: Int = 0
    ) {
        self.id = id
        self.category = category
        self.label = label
        self.value = value
        self.date = date
        self.reminderEnabled = reminderEnabled
        self.order = order
    }
}

enum ContextCategory: String, Codable, CaseIterable, Identifiable {
    case interest = "관심사"
    case preference = "취향/선호"
    case importantDate = "중요한 날짜"
    case workStyle = "업무 스타일"
    case background = "배경 정보"
    case custom = "기타"
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .interest: return "🎯"
        case .preference: return "⭐️"
        case .importantDate: return "📅"
        case .workStyle: return "💼"
        case .background: return "📚"
        case .custom: return "📝"
        }
    }
    
    var systemImage: String {
        switch self {
        case .interest: return "star.circle.fill"
        case .preference: return "heart.circle.fill"
        case .importantDate: return "calendar.circle.fill"
        case .workStyle: return "briefcase.circle.fill"
        case .background: return "book.circle.fill"
        case .custom: return "doc.circle.fill"
        }
    }
    
    var description: String {
        switch self {
        case .interest:
            return "취미, 좋아하는 것, 관심 분야"
        case .preference:
            return "좋아하는 것/싫어하는 것, 선호하는 방식"
        case .importantDate:
            return "생일, 기념일, 중요한 이벤트 날짜"
        case .workStyle:
            return "업무 방식, 소통 스타일, 일하는 패턴"
        case .background:
            return "학력, 경력, 출신, 배경 정보"
        case .custom:
            return "기타 메모하고 싶은 정보"
        }
    }
}

// MARK: - Default Context Templates
extension PersonContext {
    /// 새로운 Person 생성 시 기본 컨텍스트 템플릿 생성
    static func createDefaultContextsForPerson(person: Person, context: ModelContext) {
        let defaultContexts: [(ContextCategory, String, String)] = [
            // 관심사
            (.interest, "취미", ""),
            (.interest, "관심 분야", ""),
            
            // 취향/선호
            (.preference, "선호 호칭", ""),
            (.preference, "커피/음료", ""),
            (.preference, "음식 취향", ""),
            (.preference, "연락 가능 시간", ""),
            
            // 중요한 날짜
            (.importantDate, "생일", ""),
            (.importantDate, "입사 기념일", ""),
            
            // 업무 스타일
            (.workStyle, "출근 시간", ""),
            (.workStyle, "소통 방식", ""),
            (.workStyle, "업무 성향", ""),
            
            // 배경 정보
            (.background, "학력", ""),
            (.background, "경력", ""),
            (.background, "출신", "")
        ]
        
        for (index, contextData) in defaultContexts.enumerated() {
            let personContext = PersonContext(
                category: contextData.0,
                label: contextData.1,
                value: contextData.2,
                order: index
            )
            personContext.person = person
            context.insert(personContext)
        }
    }
}

// MARK: - Helper Extensions
extension PersonContext {
    var isEmpty: Bool {
        return value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var formattedDate: String? {
        guard let date = date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    var isUpcoming: Bool {
        guard let date = date else { return false }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetDate = calendar.startOfDay(for: date)
        let daysUntil = calendar.dateComponents([.day], from: today, to: targetDate).day ?? 0
        return daysUntil >= 0 && daysUntil <= 30 // 30일 이내
    }
}
