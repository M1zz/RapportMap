//
//  DemoDataSeeder.swift
//  RapportMap
//
//  데모/스크린샷용 더미 데이터 생성
//

import Foundation
import SwiftData

struct DemoDataSeeder {
    
    /// 데모 데이터 생성 (앱 시작 시 호출)
    static func seedDemoData(context: ModelContext) {
        // 이미 데이터가 있으면 스킵
        let descriptor = FetchDescriptor<Person>()
        let existingCount = (try? context.fetchCount(descriptor)) ?? 0
        if existingCount > 0 {
            print("📊 [Demo] 이미 데이터 존재 (\(existingCount)명), 스킵")
            return
        }
        
        print("🌱 [Demo] 데모 데이터 생성 시작...")
        
        // 사람 1: 김민수 (깊은 관계, 많은 발견)
        let minsu = Person(
            name: "김민수",
            depth: .deep,
            memo: "대학 동기, 10년 지기"
        )
        context.insert(minsu)
        
        // 발견들
        minsu.addDiscovery(
            territory: .nickname,
            content: "'민수'라는 이름은 할아버지가 지어주셨대. 민첩할 민, 빼어날 수.",
            context: "졸업 후 첫 만남에서",
            emotion: .touched
        )
        minsu.addDiscovery(
            territory: .hobby,
            content: "요즘 러닝에 빠졌음. 매일 아침 5km씩 뛴대.",
            emotion: .surprised
        )
        minsu.addDiscovery(
            territory: .job,
            content: "스타트업 CTO. 팀 15명 이끄는 중.",
            context: "LinkedIn에서 봤음"
        )
        minsu.addDiscovery(
            territory: .currentConcern,
            content: "투자 유치 고민중. 시리즈A 준비하고 있대.",
            emotion: .understood,
            isSignificant: true
        )
        minsu.addDiscovery(
            territory: .goal,
            content: "3년 안에 100명 규모 회사 만들고 싶대.",
            emotion: .respectful
        )
        minsu.addDiscovery(
            territory: .family,
            content: "아버지가 편찮으셔서 주말마다 병원 다님.",
            emotion: .closer,
            isSignificant: true
        )
        minsu.addDiscovery(
            territory: .childhood,
            content: "부산에서 자랐음. 바다를 정말 좋아함.",
            emotion: .warm
        )
        
        // 사람 2: 이서연 (개인적 관계)
        let seoyeon = Person(
            name: "이서연",
            depth: .personal,
            memo: "디자인 스터디에서 만남"
        )
        context.insert(seoyeon)
        
        seoyeon.addDiscovery(
            territory: .nickname,
            content: "서연이라는 이름, 부모님이 '맑은 연못'에서 따왔대.",
            emotion: .touched
        )
        seoyeon.addDiscovery(
            territory: .hobby,
            content: "수채화 그리기. 주말마다 한강에서 그림 그림.",
            emotion: .curious
        )
        seoyeon.addDiscovery(
            territory: .favorites,
            content: "커피는 무조건 아이스 아메리카노. 연하게.",
            context: "카페에서"
        )
        seoyeon.addDiscovery(
            territory: .currentConcern,
            content: "프리랜서 전환 고민중. 회사 생활이 안 맞대.",
            emotion: .understood
        )
        seoyeon.addDiscovery(
            territory: .taste,
            content: "미니멀한 스타일 좋아함. 옷은 흰색/검정만.",
            emotion: .curious
        )
        
        // 사람 3: 박준혁 (표면적 관계)
        let junhyuk = Person(
            name: "박준혁",
            depth: .surface,
            memo: "헬스장에서 만난 사람"
        )
        context.insert(junhyuk)
        
        junhyuk.addDiscovery(
            territory: .hobby,
            content: "헬스 3년째. 대회 나가는 게 목표래.",
            emotion: .surprised
        )
        junhyuk.addDiscovery(
            territory: .job,
            content: "은행 다님. 여의도 쪽.",
            context: "운동 중 잡담에서"
        )
        
        // 사람 4: 최유진 (개인적 관계)
        let yujin = Person(
            name: "최유진",
            depth: .personal,
            memo: "독서 모임 멤버"
        )
        context.insert(yujin)
        
        yujin.addDiscovery(
            territory: .nickname,
            content: "유진이라는 이름, 유니크하게 진취적인 사람이 되라고.",
            emotion: .touched
        )
        yujin.addDiscovery(
            territory: .hobby,
            content: "한 달에 책 5권 이상 읽음. 주로 에세이.",
            emotion: .respectful
        )
        yujin.addDiscovery(
            territory: .hometown,
            content: "제주도 출신. 서울 올라온 지 7년.",
            emotion: .curious
        )
        yujin.addDiscovery(
            territory: .goal,
            content: "언젠가 작은 서점 차리고 싶대.",
            emotion: .closer
        )
        yujin.addDiscovery(
            territory: .values,
            content: "느리게 사는 삶을 중요하게 생각함.",
            emotion: .understood
        )
        
        // 사람 5: 정하늘 (표면적)
        let haneul = Person(
            name: "정하늘",
            depth: .surface,
            memo: "동네 카페에서 자주 마주침"
        )
        context.insert(haneul)
        
        haneul.addDiscovery(
            territory: .job,
            content: "프리랜서 작가. 카페에서 주로 작업함.",
            context: "노트북 보고 물어봄"
        )
        
        do {
            try context.save()
            print("✅ [Demo] 데모 데이터 생성 완료 (5명, 발견 다수)")
        } catch {
            print("❌ [Demo] 저장 실패: \(error)")
        }
    }
    
    /// 모든 데이터 삭제 (리셋용)
    static func clearAllData(context: ModelContext) {
        do {
            try context.delete(model: Discovery.self)
            try context.delete(model: Person.self)
            try context.save()
            print("🗑️ [Demo] 모든 데이터 삭제 완료")
        } catch {
            print("❌ [Demo] 삭제 실패: \(error)")
        }
    }
}
