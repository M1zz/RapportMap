//
//  PersonTag.swift
//  RapportMap
//
//  Created by hyunho lee on 2/19/26.
//
//  멘티/사람들을 그룹으로 분류할 수 있는 태그 시스템
//

import Foundation
import SwiftData
import SwiftUI

/// 사람들을 그룹화하기 위한 태그 모델
/// 기수, 상태, 분야 등 다양한 분류 기준으로 활용 가능
@Model
final class PersonTag {
    // MARK: - Properties
    
    var id: UUID = UUID()
    var name: String = ""              // "1기", "개발", "위험"
    var color: String = "#007AFF"      // 색상 hex (예: "#FF5733")
    var icon: String?                   // SF Symbol 이름 (예: "star.fill")
    var order: Int = 0                  // 정렬 순서
    var createdDate: Date = Date()
    var category: TagCategory = TagCategory.custom // 태그 카테고리 (기수, 상태, 분야 등)

    // MARK: - Relationships

    /// 이 태그가 붙은 사람들 (Many-to-Many) — CloudKit requires optional to-many relationships
    @Relationship(deleteRule: .nullify)
    var people: [Person]?
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        name: String,
        color: String = "#007AFF",
        icon: String? = nil,
        order: Int = 0,
        category: TagCategory = .custom,
        createdDate: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.order = order
        self.category = category
        self.createdDate = createdDate
    }
}

// MARK: - TagCategory Enum

/// 태그 카테고리 - 태그를 그룹화하여 관리
enum TagCategory: String, Codable, CaseIterable, Identifiable {
    case cohort = "기수"           // 1기, 2기, 3기 등
    case status = "상태"           // 활발, 정체, 위험
    case field = "분야"            // 개발, 디자인, PM, 기획
    case priority = "우선순위"      // 높음, 중간, 낮음
    case custom = "사용자 정의"     // 사용자가 직접 만든 태그
    
    var id: String { rawValue }
    
    var emoji: String {
        switch self {
        case .cohort: return "🎓"
        case .status: return "📊"
        case .field: return "💼"
        case .priority: return "⚡️"
        case .custom: return "🏷️"
        }
    }
    
    var systemImage: String {
        switch self {
        case .cohort: return "person.3.fill"
        case .status: return "chart.bar.fill"
        case .field: return "briefcase.fill"
        case .priority: return "flag.fill"
        case .custom: return "tag.fill"
        }
    }
    
    var description: String {
        switch self {
        case .cohort: return "멘토링 기수 또는 그룹"
        case .status: return "관계 상태 및 활동 수준"
        case .field: return "전문 분야 또는 직군"
        case .priority: return "관리 우선순위"
        case .custom: return "사용자 정의 분류"
        }
    }
}

// MARK: - Color Helpers

extension PersonTag {
    /// hex 문자열을 Color로 변환
    var swiftUIColor: Color {
        Color(hex: color)
    }
    
    #if canImport(UIKit)
    /// hex 문자열을 UIColor로 변환
    var uiColor: UIColor {
        UIColor(hex: color) ?? .systemBlue
    }
    #endif
    
    #if canImport(AppKit)
    /// hex 문자열을 NSColor로 변환
    var nsColor: NSColor {
        NSColor(hex: color) ?? .systemBlue
    }
    #endif
}


#if canImport(UIKit)
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif

#if canImport(AppKit)
extension NSColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif

// MARK: - Preset Colors

extension PersonTag {
    /// 프리셋 색상들
    static let presetColors: [(name: String, hex: String)] = [
        ("빨강", "#FF3B30"),
        ("주황", "#FF9500"),
        ("노랑", "#FFCC00"),
        ("초록", "#34C759"),
        ("민트", "#00C7BE"),
        ("하늘", "#32ADE6"),
        ("파랑", "#007AFF"),
        ("남색", "#5856D6"),
        ("보라", "#AF52DE"),
        ("분홍", "#FF2D55"),
        ("갈색", "#A2845E"),
        ("회색", "#8E8E93")
    ]
    
    /// 프리셋 아이콘들
    static let presetIcons: [String] = [
        "star.fill",
        "heart.fill",
        "flag.fill",
        "bolt.fill",
        "flame.fill",
        "leaf.fill",
        "drop.fill",
        "snowflake",
        "sun.max.fill",
        "moon.fill",
        "sparkles",
        "person.fill",
        "person.2.fill",
        "person.3.fill",
        "briefcase.fill",
        "book.fill",
        "graduationcap.fill",
        "laptopcomputer",
        "paintbrush.fill",
        "wrench.fill",
        "chart.bar.fill",
        "lightbulb.fill"
    ]
}

// MARK: - Default Tags Creation

extension PersonTag {
    /// 기본 프리셋 태그들 생성
    static func createDefaultTags() -> [PersonTag] {
        var tags: [PersonTag] = []
        var order = 0
        
        // 기수 태그들
        let cohortColors = ["#007AFF", "#5856D6", "#AF52DE"]
        for (index, cohort) in ["1기", "2기", "3기"].enumerated() {
            tags.append(PersonTag(
                name: cohort,
                color: cohortColors[index],
                icon: "person.3.fill",
                order: order,
                category: .cohort
            ))
            order += 1
        }
        
        // 상태 태그들
        let statusData: [(name: String, color: String, icon: String)] = [
            ("활발", "#34C759", "bolt.fill"),
            ("정체", "#FF9500", "pause.fill"),
            ("위험", "#FF3B30", "exclamationmark.triangle.fill")
        ]
        for data in statusData {
            tags.append(PersonTag(
                name: data.name,
                color: data.color,
                icon: data.icon,
                order: order,
                category: .status
            ))
            order += 1
        }
        
        // 분야 태그들
        let fieldData: [(name: String, color: String, icon: String)] = [
            ("개발", "#32ADE6", "laptopcomputer"),
            ("디자인", "#FF2D55", "paintbrush.fill"),
            ("PM", "#5856D6", "chart.bar.fill"),
            ("기획", "#FF9500", "lightbulb.fill")
        ]
        for data in fieldData {
            tags.append(PersonTag(
                name: data.name,
                color: data.color,
                icon: data.icon,
                order: order,
                category: .field
            ))
            order += 1
        }
        
        return tags
    }
}

// MARK: - Tag Badge View Component

/// 태그를 표시하는 뱃지 뷰 (iOS/macOS 공용)
struct TagBadge: View {
    let tag: PersonTag
    var showIcon: Bool = true
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: isCompact ? 2 : 4) {
            if showIcon, let icon = tag.icon {
                Image(systemName: icon)
                    .font(isCompact ? .caption2 : .caption)
            }
            Text(tag.name)
                .font(isCompact ? .caption2 : .caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, isCompact ? 6 : 8)
        .padding(.vertical, isCompact ? 2 : 4)
        .background(
            Capsule()
                .fill(tag.swiftUIColor.opacity(0.2))
        )
        .overlay(
            Capsule()
                .strokeBorder(tag.swiftUIColor.opacity(0.5), lineWidth: 1)
        )
        .foregroundStyle(tag.swiftUIColor)
    }
}

/// 여러 태그를 표시하는 플로우 레이아웃 뷰
struct TagsFlowView: View {
    let tags: [PersonTag]
    var isCompact: Bool = false
    var maxDisplayCount: Int? = nil
    
    private var displayTags: [PersonTag] {
        if let max = maxDisplayCount, tags.count > max {
            return Array(tags.prefix(max))
        }
        return tags
    }
    
    private var remainingCount: Int {
        if let max = maxDisplayCount, tags.count > max {
            return tags.count - max
        }
        return 0
    }
    
    var body: some View {
        FlowLayout(spacing: isCompact ? 4 : 6) {
            ForEach(displayTags) { tag in
                TagBadge(tag: tag, isCompact: isCompact)
            }
            
            if remainingCount > 0 {
                Text("+\(remainingCount)")
                    .font(isCompact ? .caption2 : .caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, isCompact ? 6 : 8)
                    .padding(.vertical, isCompact ? 2 : 4)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(0.2))
                    )
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// FlowLayout이 이미 프로젝트에 있다면 사용, 없으면 아래 구현 사용
#if !os(macOS)
// iOS에서 FlowLayout이 없는 경우를 위한 백업
// 이미 PeopleListView.swift에 FlowLayout이 있을 수 있음
#endif
