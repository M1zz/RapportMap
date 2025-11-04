//
//  DataSeeder.swift
//  RapportMap
//
//  Created by hyunho lee on 11/3/25.
//

import Foundation
import SwiftData

@MainActor
class DataSeeder {
    
    /// 기본 액션이 없으면 30개를 생성
    static func seedDefaultActionsIfNeeded(context: ModelContext) {
        let descriptor = FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.isDefault == true }
        )
        
        do {
            let existingActions = try context.fetch(descriptor)
            
            // 이미 기본 액션들이 있으면 스킵
            if !existingActions.isEmpty {
                print("✅ 기본 액션들이 이미 존재합니다 (\(existingActions.count)개)")
                return
            }
            
            // 기본 액션 30개 생성
            let defaultActions = RapportAction.createDefaultActions()
            for action in defaultActions {
                context.insert(action)
            }
            
            try context.save()
            print("✅ 기본 액션 30개를 생성했습니다")
            
        } catch {
            print("❌ 기본 액션 생성 실패: \(error)")
        }
    }
    
    /// 새로운 Person을 생성할 때 해당 Person의 액션 인스턴스들도 함께 생성
    static func createPersonActionsForNewPerson(person: Person, context: ModelContext) {
        let descriptor = FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        do {
            let allActions = try context.fetch(descriptor)
            
            for action in allActions {
                let personAction = PersonAction(
                    person: person,
                    action: action
                )
                context.insert(personAction)
            }
            
            try context.save()
            print("✅ \(person.name)님의 액션 \(allActions.count)개를 생성했습니다")
            
        } catch {
            print("❌ Person 액션 생성 실패: \(error)")
        }
    }
}
