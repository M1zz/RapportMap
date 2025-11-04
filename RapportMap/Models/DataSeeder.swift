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
        print("🔧 [DataSeeder] createPersonActionsForNewPerson 시작 - \(person.name)")
        
        // 이미 PersonAction이 있으면 스킵 (중복 방지)
        if !person.actions.isEmpty {
            print("🔧 [DataSeeder] 이미 PersonAction이 존재함 (\(person.actions.count)개) - 스킵")
            return
        }
        
        let descriptor = FetchDescriptor<RapportAction>(
            predicate: #Predicate { $0.isActive == true }
        )
        
        do {
            let allActions = try context.fetch(descriptor)
            print("🔧 [DataSeeder] 활성 액션 \(allActions.count)개 발견")
            
            if allActions.isEmpty {
                print("🔧 [DataSeeder] 활성 액션이 없음 - 기본 액션 먼저 생성")
                seedDefaultActionsIfNeeded(context: context)
                
                // 다시 시도
                let retryAllActions = try context.fetch(descriptor)
                print("🔧 [DataSeeder] 재시도 후 활성 액션 \(retryAllActions.count)개 발견")
                
                for action in retryAllActions {
                    let personAction = PersonAction(
                        person: person,
                        action: action,
                        isVisibleInDetail: false // 기본적으로 PersonDetailView에 표시하지 않음
                    )
                    context.insert(personAction)
                }
            } else {
                for action in allActions {
                    let personAction = PersonAction(
                        person: person,
                        action: action,
                        isVisibleInDetail: false // 기본적으로 PersonDetailView에 표시하지 않음
                    )
                    context.insert(personAction)
                }
            }
            
            try context.save()
            print("✅ \(person.name)님의 액션 \(allActions.count)개를 생성했습니다")
            
        } catch {
            print("❌ Person 액션 생성 실패: \(error)")
            
            // 에러가 발생해도 기본 액션들은 시도해보자
            do {
                seedDefaultActionsIfNeeded(context: context)
                try context.save()
                print("🔄 기본 액션 생성 후 재시도")
                // 재귀 호출 (무한루프 방지를 위해 한번만)
                createPersonActionsForNewPerson(person: person, context: context)
            } catch {
                print("❌ 재시도도 실패: \(error)")
            }
        }
    }
}
