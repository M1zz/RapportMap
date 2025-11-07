//
//  AddPersonSheet.swift
//  RapportMap
//
//  Created by Leeo on 11/7/25.
//

import SwiftUI

// MARK: - AddPersonSheet
struct AddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var contact = ""
    var onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $name)
                    TextField("연락처 (선택)", text: $contact)
                }
            }
            .navigationTitle("새로운 사람 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        onAdd(name, contact)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
