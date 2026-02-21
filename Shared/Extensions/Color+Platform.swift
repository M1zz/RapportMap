//
//  Color+Platform.swift
//  RapportMap
//
//  플랫폼별 색상 호환
//

import SwiftUI

extension Color {
    
    /// 플랫폼별 배경색
    static var secondaryBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    static var tertiaryBackground: Color {
        #if os(iOS)
        return Color(.tertiarySystemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    static var primaryBackground: Color {
        #if os(iOS)
        return Color(.systemBackground)
        #else
        return Color(NSColor.windowBackgroundColor)
        #endif
    }
}
