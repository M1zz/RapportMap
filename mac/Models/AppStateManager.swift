//
//  AppStateManager.swift
//  RapportMap
//
//  Created by hyunho lee on 11/5/25.
//

import Foundation
import SwiftData

@MainActor
@Observable
class AppStateManager {
    static let shared = AppStateManager()
    
    // 현재 선택된 Person의 ID
    var selectedPersonID: UUID? {
        didSet {
            // UserDefaults에 저장
            if let id = selectedPersonID {
                UserDefaults.standard.set(id.uuidString, forKey: "selectedPersonID")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedPersonID")
            }
        }
    }
    
    // 앱 시작 시 PersonDetailView를 표시할지 여부
    var shouldShowPersonDetail: Bool = false
    
    // 선택된 Person 객체 (실제 데이터)
    var selectedPerson: Person?
    
    private init() {
        loadSelectedPersonID()
    }
    
    private func loadSelectedPersonID() {
        if let idString = UserDefaults.standard.string(forKey: "selectedPersonID"),
           let id = UUID(uuidString: idString) {
            selectedPersonID = id
            shouldShowPersonDetail = true
        }
    }
    
    func selectPerson(_ person: Person) {
        selectedPersonID = person.id
        selectedPerson = person
        shouldShowPersonDetail = true
    }
    
    func clearSelection() {
        selectedPersonID = nil
        selectedPerson = nil
        shouldShowPersonDetail = false
    }
    
    // ModelContext를 받아서 실제 Person 객체를 찾는 메서드
    func findSelectedPerson(in context: ModelContext) -> Person? {
        guard let id = selectedPersonID else { return nil }
        
        let descriptor = FetchDescriptor<Person>(
            predicate: #Predicate<Person> { person in
                person.id == id
            }
        )
        
        do {
            let people = try context.fetch(descriptor)
            let person = people.first
            selectedPerson = person
            return person
        } catch {
            print("❌ 선택된 Person 찾기 실패: \(error)")
            clearSelection() // 찾지 못한 경우 선택 해제
            return nil
        }
    }
}