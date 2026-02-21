//
//  AddPersonSheet.swift
//  RapportMap
//
//  Created by Leeo on 11/7/25.
//

import SwiftUI
import Contacts

// MARK: - AddPersonSheet
struct AddPersonSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var contact = ""
    @State private var showingContactPicker = false
    @State private var showingAddToContacts = false
    @State private var addToContactsAfterCreation = false
    @State private var isSearchingContact = false
    @State private var contactSearchFailedMessage: String? = nil
    private let contactsManager = ContactsManager.shared
    
    var onAdd: (String, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("기본 정보") {
                    TextField("이름", text: $name)
                    TextField("연락처 (선택)", text: $contact)
                        .keyboardType(contact.contains("@") ? .emailAddress : .phonePad)
                }
                
                Section("연락처 연동") {
                    Button {
                        showingContactPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "person.crop.circle.badge.plus")
                                .foregroundStyle(.blue)
                            Text("iPhone 연락처에서 선택")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 이름이 있고 연락처가 없을 때 자동 찾기 버튼 표시
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && 
                       contact.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            Task {
                                await autoFillContactFromName()
                            }
                        } label: {
                            HStack {
                                if isSearchingContact {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "magnifyingglass.circle")
                                        .foregroundStyle(.orange)
                                }
                                
                                Text(isSearchingContact ? "검색 중..." : "이름으로 자동 찾기")
                                    .foregroundStyle(.orange)
                                
                                Spacer()
                            }
                        }
                        .disabled(isSearchingContact)
                        
                        // 검색 실패 메시지
                        if let failMessage = contactSearchFailedMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                
                                Text(failMessage)
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    
                    if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Toggle("iPhone 연락처에도 추가", isOn: $addToContactsAfterCreation)
                    }
                }
                
                if !name.isEmpty && !contact.isEmpty {
                    Section("미리보기") {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .foregroundStyle(.blue)
                                    .font(.title2)
                                
                                VStack(alignment: .leading) {
                                    Text(name)
                                        .font(.headline)
                                    Text(contact)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                            }
                            
                            if addToContactsAfterCreation {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                        .font(.caption)
                                    Text("iPhone 연락처에도 자동 추가됩니다")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("새로운 사람 추가")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("추가") {
                        addPerson()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showingContactPicker) {
                ContactPicker(isPresented: $showingContactPicker) { contact in
                    fillFromContact(contact)
                }
            }
        }
    }
    
    private func fillFromContact(_ contact: CNContact) {
        // 이름 채우기
        let fullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
        name = fullName.isEmpty ? "이름 없음" : fullName
        
        // 연락처 정보 채우기 (전화번호 우선, 없으면 이메일)
        if let phoneNumber = contact.phoneNumbers.first {
            self.contact = phoneNumber.value.stringValue
        } else if let email = contact.emailAddresses.first {
            self.contact = email.value as String
        }
        
        // 이미 iPhone 연락처에 있으므로 중복 추가 방지
        addToContactsAfterCreation = false
        
        // 성공 시 실패 메시지 초기화
        contactSearchFailedMessage = nil
    }
    
    private func autoFillContactFromName() async {
        isSearchingContact = true
        contactSearchFailedMessage = nil
        
        // 임시 Person 객체 생성 (검색용)
        let tempPerson = Person(name: name.trimmingCharacters(in: .whitespacesAndNewlines), contact: "")
        
        // 이름으로 연락처 찾기
        if let foundContact = await contactsManager.updatePersonContactFromContacts(tempPerson) {
            await MainActor.run {
                self.contact = foundContact
                isSearchingContact = false
                contactSearchFailedMessage = nil
                
                // 이미 iPhone 연락처에 있으므로 중복 추가 방지
                addToContactsAfterCreation = false
            }
        } else {
            await MainActor.run {
                isSearchingContact = false
                contactSearchFailedMessage = "'\(name)' 이름과 일치하는 연락처를 찾을 수 없습니다"
            }
            
            // 3초 후 메시지 자동 제거
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    contactSearchFailedMessage = nil
                }
            }
        }
    }
    
    private func addPerson() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContact = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Person 추가
        onAdd(trimmedName, trimmedContact)
        
        // iPhone 연락처에도 추가 (사용자가 선택한 경우)
        if addToContactsAfterCreation && !trimmedContact.isEmpty {
            Task {
                let tempPerson = Person(name: trimmedName, contact: trimmedContact)
                let success = await contactsManager.addPersonToContacts(tempPerson)
                
                await MainActor.run {
                    if success {
                        print("✅ iPhone 연락처에도 추가 완료: \(trimmedName)")
                    } else {
                        print("❌ iPhone 연락처 추가 실패: \(trimmedName)")
                    }
                }
            }
        }
        
        dismiss()
    }
}
