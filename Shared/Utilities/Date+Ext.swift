//
//  Date+Ext.swift
//  RapportMap
//
//  Created by Leeo on 11/7/25.
//

import Foundation

extension Date {
    func relative() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: .now)
    }
}
