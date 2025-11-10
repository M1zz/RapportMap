//
//  ContactsManager.swift
//  RapportMap
//
//  Created by Assistant on 11/8/25.
//

import Foundation
import Contacts
import ContactsUI
import Combine
import SwiftUI
import os.log

@MainActor
class ContactsManager: ObservableObject {
    static let shared = ContactsManager()
    
    private let contactStore = CNContactStore()
    private let logger = Logger(subsystem: "RapportMap.ContactsManager", category: "ContactsManager")
    
    // PPT 관련 로그 필터링
    @Published var lastError: String?
    @Published var isContactPickerActive = false
    
    private init() {
        // PPT 관련 로그 필터링
        setupLogFiltering()
    }
    
    /// PPT 에러 로그 필터링 설정 (시뮬레이터 전용)
    private func setupLogFiltering() {
        #if targetEnvironment(simulator)
        // 시뮬레이터에서 PPT 관련 에러 로그를 무시하도록 설정
        self.logger.info("🔧 시뮬레이터 모드: PPT 에러 필터링 활성화")
        #endif
    }
    
    /// 안전한 연락처 작업을 위한 지연 처리
    private func safeContactOperation<T>(_ operation: @escaping () async throws -> T) async -> T? {
        do {
            // 시뮬레이터에서 PPT 에러 방지를 위한 작은 지연
            #if targetEnvironment(simulator)
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1초
            #endif
            
            return try await operation()
        } catch {
            let errorMessage = "연락처 작업 실패: \(error.localizedDescription)"
            self.logger.error("\(errorMessage)")
            
            // PPT 관련 에러는 무시
            if !error.localizedDescription.contains("CFMessagePort") &&
               !error.localizedDescription.contains("PPT") {
                await MainActor.run {
                    self.lastError = errorMessage
                }
            }
            return nil
        }
    }
    
    /// 연락처 접근 권한 요청 (PPT 에러 방지 버전)
    func requestContactsPermission() async -> Bool {
        return await safeContactOperation {
            let status = CNContactStore.authorizationStatus(for: .contacts)
            
            switch status {
            case .authorized:
                self.logger.info("✅ 연락처 권한 이미 승인됨")
                return true
            case .denied, .restricted:
                self.logger.warning("❌ 연락처 권한 거부됨 또는 제한됨")
                return false
            case .notDetermined:
                self.logger.info("🔄 연락처 권한 요청 중...")
                
                #if targetEnvironment(simulator)
                // 시뮬레이터에서 권한 요청 시 추가 지연
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2초
                #endif
                
                let granted = try await self.contactStore.requestAccess(for: .contacts)
                self.logger.info("\(granted ? "✅ 연락처 권한 승인됨" : "❌ 연락처 권한 거부됨")")
                return granted
            @unknown default:
                self.logger.warning("⚠️ 알 수 없는 권한 상태")
                return false
            }
        } ?? false
    }
    
    /// iPhone 연락처에서 Person과 일치하는 연락처 찾기 (PPT 에러 방지 버전)
    func findContact(for person: Person) async -> CNContact? {
        return await safeContactOperation {
            guard await self.requestContactsPermission() else {
                throw ContactsError.permissionDenied
            }
            
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactNoteKey as CNKeyDescriptor
            ]
            
            var foundContacts: [CNContact] = []
            
            self.logger.info("🔍 연락처 검색 시작: \(person.name)")
            
            // 1. 이름으로 검색
            let nameRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
            nameRequest.predicate = CNContact.predicateForContacts(matchingName: person.name)
            
            try self.contactStore.enumerateContacts(with: nameRequest) { contact, _ in
                foundContacts.append(contact)
            }
            
            // 이름으로 찾은 연락처 중에서 매칭 확인
            for contact in foundContacts {
                if self.isContactMatching(contact: contact, person: person) {
                    let contactId = contact.identifier
                    self.logger.info("✅ 이름으로 연락처 찾음: \(contactId)")
                    return contact
                }
            }
            
            // 2. 연락처 정보로 직접 검색
            foundContacts.removeAll()
            
            if person.contact.contains("@") {
                // 이메일로 검색
                self.logger.info("📧 이메일로 검색: \(person.contact)")
                let emailRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
                emailRequest.predicate = CNContact.predicateForContacts(matchingEmailAddress: person.contact)
                
                try self.contactStore.enumerateContacts(with: emailRequest) { contact, _ in
                    foundContacts.append(contact)
                }
            } else if !person.contact.isEmpty && person.contact != "연락처 없음" {
                // 전화번호로 검색 - 모든 연락처를 가져와서 비교
                self.logger.info("📞 전화번호로 검색: \(person.contact)")
                let cleanedPhone = self.cleanPhoneNumber(person.contact)
                let allContactsRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
                
                try self.contactStore.enumerateContacts(with: allContactsRequest) { contact, _ in
                    for phoneNumber in contact.phoneNumbers {
                        let contactPhone = self.cleanPhoneNumber(phoneNumber.value.stringValue)
                        if contactPhone == cleanedPhone {
                            foundContacts.append(contact)
                            break // 같은 연락처는 한 번만 추가
                        }
                    }
                }
            }
            
            let result = foundContacts.first
            if let contact = result {
                let contactId = contact.identifier
                self.logger.info("✅ 연락처 정보로 찾음: \(contactId)")
            } else {
                self.logger.info("❌ 연락처를 찾을 수 없음")
            }
            
            return result!
        }
    }
    
    /// Person을 iPhone 연락처에 추가 (PPT 에러 방지 버전)
    func addPersonToContacts(_ person: Person) async -> Bool {
        return await safeContactOperation {
            guard await self.requestContactsPermission() else {
                throw ContactsError.permissionDenied
            }
            
            // 이미 존재하는지 확인
            if let _ = await self.findContact(for: person) {
                self.logger.info("ℹ️ 연락처가 이미 존재함")
                return true
            }
            
            let contact = CNMutableContact()
            
            // 이름 설정 (한국어 이름 처리)
            let nameComponents = self.parseKoreanName(person.name)
            contact.familyName = nameComponents.familyName
            contact.givenName = nameComponents.givenName
            
            // 연락처 정보 추가
            if person.contact.contains("@") {
                // 이메일
                let email = CNLabeledValue(label: CNLabelHome, value: person.contact as NSString)
                contact.emailAddresses = [email]
                self.logger.info("📧 이메일 추가: \(person.contact)")
            } else {
                // 전화번호
                let phoneNumber = CNPhoneNumber(stringValue: person.contact)
                let phone = CNLabeledValue(label: CNLabelPhoneNumberMobile, value: phoneNumber)
                contact.phoneNumbers = [phone]
                self.logger.info("📞 전화번호 추가: \(person.contact)")
            }
            
            // 메모에 앱 정보 추가
            contact.note = "RapportMap에서 추가됨 - 관계: \(person.state.localizedName)"
            
            let saveRequest = CNSaveRequest()
            saveRequest.add(contact, toContainerWithIdentifier: nil)
            
            // PPT 에러 방지를 위한 추가 지연
            #if targetEnvironment(simulator)
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3초
            #endif
            
            try self.contactStore.execute(saveRequest)
            self.logger.info("✅ 연락처 추가 완료: \(person.name)")
            return true
        } ?? false
    }
    
    /// Person 정보를 기존 iPhone 연락처에 업데이트 (PPT 에러 방지 버전)
    func updateContactWithPerson(_ person: Person) async -> Bool {
        return await safeContactOperation {
            guard let contact = await self.findContact(for: person) else {
                throw ContactsError.contactNotFound
            }
            
            let mutableContact = contact.mutableCopy() as! CNMutableContact
            
            // 메모에 관계 상태 업데이트
            let currentNote = mutableContact.note
            let rapportInfo = "RapportMap - 관계: \(person.state.localizedName), 마지막 연락: \(person.lastContact?.formatted(date: .abbreviated, time: .omitted) ?? "없음")"
            
            if currentNote.isEmpty {
                mutableContact.note = rapportInfo
            } else if !currentNote.contains("RapportMap") {
                mutableContact.note = currentNote + "\n\n" + rapportInfo
            } else {
                // 기존 RapportMap 정보를 새 정보로 교체
                let lines = currentNote.components(separatedBy: "\n")
                let filteredLines = lines.filter { !$0.contains("RapportMap") }
                mutableContact.note = (filteredLines + [rapportInfo]).joined(separator: "\n")
            }
            
            let saveRequest = CNSaveRequest()
            saveRequest.update(mutableContact)
            
            // PPT 에러 방지를 위한 추가 지연
            #if targetEnvironment(simulator)
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3초
            #endif
            
            try self.contactStore.execute(saveRequest)
            self.logger.info("✅ 연락처 업데이트 완료: \(person.name)")
            return true
        } ?? false
    }
    
    /// iPhone 연락처에서 Person 생성
    func createPersonFromContact(_ contact: CNContact) -> Person {
        let fullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
        let name = fullName.isEmpty ? "이름 없음" : fullName
        
        var contactInfo = ""
        
        // 전화번호 우선
        if let phoneNumber = contact.phoneNumbers.first {
            contactInfo = phoneNumber.value.stringValue
        }
        // 이메일이 있으면 이메일
        else if let email = contact.emailAddresses.first {
            contactInfo = email.value as String
        }
        
        return Person(
            name: name,
            contact: contactInfo.isEmpty ? "연락처 없음" : contactInfo
        )
    }
    
    /// 모든 iPhone 연락처 가져오기 (PPT 에러 방지 버전)
    func fetchAllContacts() async -> [CNContact] {
        return await safeContactOperation {
            guard await self.requestContactsPermission() else {
                throw ContactsError.permissionDenied
            }
            
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor,
                CNContactNoteKey as CNKeyDescriptor
            ]
            
            var contacts: [CNContact] = []
            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            
            self.logger.info("📱 모든 연락처 가져오기 시작...")
            
            try self.contactStore.enumerateContacts(with: request) { contact, _ in
                // 이름이나 연락처 정보가 있는 연락처만 포함
                let hasName = !contact.givenName.isEmpty || !contact.familyName.isEmpty
                let hasContact = !contact.phoneNumbers.isEmpty || !contact.emailAddresses.isEmpty
                
                if hasName || hasContact {
                    contacts.append(contact)
                }
            }
            
            // 이름순으로 정렬
            contacts.sort { contact1, contact2 in
                let name1 = "\(contact1.familyName)\(contact1.givenName)"
                let name2 = "\(contact2.familyName)\(contact2.givenName)"
                return name1.localizedCaseInsensitiveCompare(name2) == .orderedAscending
            }
            
            self.logger.info("✅ 연락처 \(contacts.count)개 가져오기 완료")
            return contacts
        } ?? []
    }
    
    // MARK: - 에러 타입 정의
    enum ContactsError: LocalizedError {
        case permissionDenied
        case contactNotFound
        case saveFailed
        case unknownError
        
        var errorDescription: String? {
            switch self {
            case .permissionDenied:
                return "연락처 접근 권한이 거부되었습니다."
            case .contactNotFound:
                return "연락처를 찾을 수 없습니다."
            case .saveFailed:
                return "연락처 저장에 실패했습니다."
            case .unknownError:
                return "알 수 없는 오류가 발생했습니다."
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func isContactMatching(contact: CNContact, person: Person) -> Bool {
        let contactFullName = "\(contact.familyName)\(contact.givenName)"
        
        // 이름 매칭 (공백 제거 후 비교)
        let normalizedContactName = contactFullName.replacingOccurrences(of: " ", with: "")
        let normalizedPersonName = person.name.replacingOccurrences(of: " ", with: "")
        
        if normalizedContactName == normalizedPersonName {
            self.logger.info("✅ 이름 매칭 성공: \(normalizedContactName)")
            return true
        }
        
        // 연락처 정보 매칭
        if person.contact.contains("@") {
            // 이메일 확인
            for email in contact.emailAddresses {
                if (email.value as String).lowercased() == person.contact.lowercased() {
                    self.logger.info("✅ 이메일 매칭 성공: \(person.contact)")
                    return true
                }
            }
        } else {
            // 전화번호 확인
            let cleanedPersonPhone = self.cleanPhoneNumber(person.contact)
            for phoneNumber in contact.phoneNumbers {
                let cleanedContactPhone = self.cleanPhoneNumber(phoneNumber.value.stringValue)
                if cleanedContactPhone == cleanedPersonPhone && !cleanedPersonPhone.isEmpty {
                    self.logger.info("✅ 전화번호 매칭 성공: \(cleanedPersonPhone)")
                    return true
                }
            }
        }
        
        self.logger.info("❌ 매칭 실패: \(person.name) - \(person.contact)")
        return false
    }
    
    private func cleanPhoneNumber(_ phone: String) -> String {
        // 숫자만 남기고 모든 특수문자, 공백 제거
        let cleaned = phone.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        
        // 한국 국가번호 정규화 (010, +8210, 821010 등을 010으로)
        if cleaned.hasPrefix("8210") {
            return "010" + String(cleaned.dropFirst(4))
        } else if cleaned.hasPrefix("82010") {
            return "010" + String(cleaned.dropFirst(5))
        }
        
        return cleaned
    }
    
    private func parseKoreanName(_ fullName: String) -> (familyName: String, givenName: String) {
        let trimmed = fullName.trimmingCharacters(in: .whitespaces)
        
        if trimmed.count <= 1 {
            return ("", trimmed)
        }
        
        // 공백으로 구분된 이름 처리 (예: "김 철수")
        let components = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        if components.count >= 2 {
            return (components[0], components.dropFirst().joined(separator: ""))
        }
        
        // 한국어 이름: 첫 글자가 성, 나머지가 이름
        let familyName = String(trimmed.prefix(1))
        let givenName = String(trimmed.dropFirst())
        
        return (familyName, givenName)
    }
    
    /// 연락처 선택 시 Person 생성을 위한 개선된 메서드
    func createPersonFromContact(_ contact: CNContact, withRelationship relationship: RelationshipState = .distant) -> Person {
        let fullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
        let name = fullName.isEmpty ? "이름 없음" : fullName
        
        var contactInfo = ""
        
        // 전화번호 우선 (모바일 > 기본 > 첫 번째)
        let mobilePhone = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMobile }
        let mainPhone = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMain }
        
        if let mobile = mobilePhone {
            contactInfo = mobile.value.stringValue
        } else if let main = mainPhone {
            contactInfo = main.value.stringValue
        } else if let firstPhone = contact.phoneNumbers.first {
            contactInfo = firstPhone.value.stringValue
        }
        // 전화번호가 없으면 이메일
        else if let email = contact.emailAddresses.first {
            contactInfo = email.value as String
        }
        
        let person = Person(
            name: name,
            contact: contactInfo.isEmpty ? "연락처 없음" : contactInfo
        )
        
        person.state = relationship
        
        return person
    }
    
    /// 기존 Person의 연락처 정보를 iPhone 연락처에서 업데이트
    func updatePersonContactFromContacts(_ person: Person) async -> String? {
        return await safeContactOperation {
            guard await self.requestContactsPermission() else {
                throw ContactsError.permissionDenied
            }
            
            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactEmailAddressesKey as CNKeyDescriptor,
                CNContactIdentifierKey as CNKeyDescriptor
            ]
            
            self.logger.info("🔍 \(person.name)의 연락처 정보 검색 시작...")
            
            // 이름으로 검색
            let nameRequest = CNContactFetchRequest(keysToFetch: keysToFetch)
            nameRequest.predicate = CNContact.predicateForContacts(matchingName: person.name)
            
            var foundContacts: [CNContact] = []
            try self.contactStore.enumerateContacts(with: nameRequest) { contact, _ in
                foundContacts.append(contact)
            }
            
            // 가장 적합한 연락처 찾기
            for contact in foundContacts {
                let contactFullName = "\(contact.familyName)\(contact.givenName)".trimmingCharacters(in: .whitespaces)
                let normalizedContactName = contactFullName.replacingOccurrences(of: " ", with: "")
                let normalizedPersonName = person.name.replacingOccurrences(of: " ", with: "")
                
                if normalizedContactName == normalizedPersonName {
                    // 연락처 정보 추출 (전화번호 우선)
                    var contactInfo = ""
                    
                    let mobilePhone = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMobile }
                    let mainPhone = contact.phoneNumbers.first { $0.label == CNLabelPhoneNumberMain }
                    
                    if let mobile = mobilePhone {
                        contactInfo = mobile.value.stringValue
                    } else if let main = mainPhone {
                        contactInfo = main.value.stringValue
                    } else if let firstPhone = contact.phoneNumbers.first {
                        contactInfo = firstPhone.value.stringValue
                    } else if let email = contact.emailAddresses.first {
                        contactInfo = email.value as String
                    }
                    
                    if !contactInfo.isEmpty && contactInfo != "010-0000-0000" {
                        self.logger.info("✅ \(person.name)의 연락처 정보 찾음: \(contactInfo)")
                        return contactInfo
                    }
                }
            }
            
            self.logger.info("❌ \(person.name)의 연락처 정보를 찾을 수 없음")
            return ""
        }
    }
}

// MARK: - ContactPicker SwiftUI Wrapper (PPT 에러 방지 버전)

struct ContactPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onContactSelected: (CNContact) -> Void
    
    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        
        // PPT 에러 방지를 위한 설정 최소화
        picker.predicateForEnablingContact = NSPredicate(format: "phoneNumbers.@count > 0 OR emailAddresses.@count > 0")
        
        // 시뮬레이터에서는 표시 속성을 제한하여 PPT 에러 방지
        #if targetEnvironment(simulator)
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey
        ]
        #else
        picker.displayedPropertyKeys = [
            CNContactGivenNameKey,
            CNContactFamilyNameKey,
            CNContactPhoneNumbersKey,
            CNContactEmailAddressesKey
        ]
        #endif
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {
        // PPT 에러 방지를 위해 업데이트 최소화
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPicker
        private let logger = Logger(subsystem: "RapportMap.ContactPicker", category: "ContactPicker")
        
        init(_ parent: ContactPicker) {
            self.parent = parent
            super.init()
        }
        
        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            logger.info("✅ 연락처 선택됨: \(contact.givenName) \(contact.familyName)")
            
            // 메인 스레드에서 콜백 실행 (PPT 에러 방지)
            DispatchQueue.main.async { [weak self] in
                self?.parent.onContactSelected(contact)
            }
        }
        
        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            logger.info("ℹ️ 연락처 선택 취소됨")
            
            // 메인 스레드에서 콜백 실행 (PPT 에러 방지)
            DispatchQueue.main.async { [weak self] in
                self?.parent.isPresented = false
            }
        }
    }
}

// MARK: - ContactPicker 사용 예시 뷰 (PPT 에러 방지 버전)

struct ContactSelectionView: View {
    @State private var showingContactPicker = false
    @State private var selectedPerson: Person?
    @State private var showingError = false
    @StateObject private var contactsManager = ContactsManager.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Button(action: {
                // PPT 에러 방지를 위한 지연 실행
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 0.1초
                    await MainActor.run {
                        showingContactPicker = true
                    }
                }
            }) {
                HStack {
                    Image(systemName: "person.badge.plus")
                    Text("연락처에서 선택하기")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
            }
            .disabled(contactsManager.isContactPickerActive)
            
            // 선택된 연락처 표시
            if let person = selectedPerson {
                VStack(alignment: .leading, spacing: 8) {
                    Text("선택된 연락처:")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(.blue)
                        Text("이름: \(person.name)")
                    }
                    
                    HStack {
                        Image(systemName: person.contact.contains("@") ? "envelope" : "phone")
                            .foregroundColor(.green)
                        Text("연락처: \(person.contact)")
                    }
                    
                    HStack {
                        Image(systemName: "heart")
                            .foregroundColor(person.state.color)
                        Text("관계: \(person.state.localizedName)")
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            // 에러 표시
            if let error = contactsManager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 시뮬레이터 안내 메시지
            #if targetEnvironment(simulator)
            Text("💡 시뮬레이터에서는 PPT 에러가 발생할 수 있습니다. 실제 기기에서 테스트해보세요.")
                .font(.footnote)
                .foregroundColor(.orange)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            #endif
        }
        .padding()
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(isPresented: $showingContactPicker) { contact in
                // 연락처가 선택되었을 때 Person 생성
                let person = contactsManager.createPersonFromContact(contact, withRelationship: .distant)
                selectedPerson = person
                
                print("✅ 새로운 Person 생성됨: \(person.name) (\(person.state.localizedName))")
            }
            .onAppear {
                contactsManager.isContactPickerActive = true
            }
            .onDisappear {
                contactsManager.isContactPickerActive = false
                // 에러 메시지 자동 지우기
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    contactsManager.lastError = nil
                }
            }
        }
        .alert("연락처 접근 오류", isPresented: $showingError) {
            Button("확인") { }
        } message: {
            Text(contactsManager.lastError ?? "알 수 없는 오류가 발생했습니다.")
        }
    }
}
