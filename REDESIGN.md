# RapportMap 재설계: 탐험과 발견

> "세상은 어두운 곳. 지도를 들고 탐험하며 밝혀간다."

---

## 🧭 핵심 컨셉

### Before (멘토링 CRM)
- 언제 만났나? → 미팅/식사/전화 기록
- 뭘 해야 하나? → 약속/질문/피드백 관리
- 소홀하진 않았나? → isNeglected 판정

### After (관계 탐험)
- 이 사람에 대해 뭘 알게 됐나? → Discovery
- 아직 모르는 건 뭐가 있나? → Territory
- 얼마나 깊이 알게 됐나? → 지도가 밝혀지는 정도

---

## 🗺️ 모델 설계

### Territory (탐험 가능한 영역)

미리 정의된 "알아갈 수 있는 것들". 관계가 깊어지면 더 깊은 영역이 열린다.

```swift
enum Territory: String, CaseIterable {
    // 🌅 표면 (Surface) - 처음 만나도 물어볼 수 있는 것
    case nickname       // 이름/닉네임의 이유
    case hobby          // 취미
    case job            // 하는 일
    case hometown       // 고향
    case favorites      // 좋아하는 것들
    
    // 🌆 개인적 (Personal) - 조금 친해지면
    case currentConcern // 요즘 고민
    case goal           // 목표/꿈
    case dailyLife      // 일상/루틴
    case taste          // 취향 (음식, 음악, 영화...)
    case values         // 중요하게 생각하는 것
    
    // 🌃 깊은 (Deep) - 신뢰가 쌓이면
    case family         // 가족 이야기
    case childhood      // 어린 시절
    case turning        // 인생 전환점
    case fear           // 두려움
    case regret         // 후회
    
    // 🌌 내밀한 (Intimate) - 깊은 신뢰 관계
    case trauma         // 상처/트라우마
    case secret         // 비밀
    case vulnerability  // 약한 모습
    case trueself       // 진짜 자기 자신
    
    var depth: RelationshipDepth { ... }
    var icon: String { ... }
    var prompt: String { ... }  // "이 사람의 닉네임은 왜...?"
}
```

### RelationshipDepth (관계 깊이)

```swift
enum RelationshipDepth: Int, CaseIterable {
    case surface = 0    // 🌅 표면적
    case personal = 1   // 🌆 개인적
    case deep = 2       // 🌃 깊은
    case intimate = 3   // 🌌 내밀한
    
    var title: String { ... }
    var color: Color { ... }
    var fogOpacity: Double { ... }  // 지도 안개 농도
}
```

### Discovery (발견)

```swift
@Model
final class Discovery {
    var id: UUID
    var date: Date                    // 알게 된 날짜
    
    var territory: Territory          // 어떤 영역?
    var content: String               // 알게 된 내용
    var context: String?              // 어떤 상황에서? (선택)
    
    var isSignificant: Bool = false   // 특별히 중요한 발견
    var emotion: DiscoveryEmotion?    // 그때 느낌 (선택)
    
    @Relationship
    var person: Person?
}

enum DiscoveryEmotion: String {
    case surprised      // 😮 놀라웠다
    case touched        // 🥹 감동받았다
    case understood     // 🤝 이해하게 됐다
    case closer         // 💙 가까워진 느낌
    case curious        // 🤔 더 알고 싶어졌다
}
```

### Person (간소화)

```swift
@Model
final class Person {
    var id: UUID
    var name: String
    var profileImageData: Data?
    
    var relationshipStartDate: Date   // 관계 시작일
    var currentDepth: RelationshipDepth  // 현재 관계 깊이
    
    var memo: String?                 // 간단한 메모
    
    @Relationship(deleteRule: .cascade)
    var discoveries: [Discovery] = []
    
    // Computed: 밝혀진 영역들
    var exploredTerritories: Set<Territory> { ... }
    
    // Computed: 현재 깊이에서 탐험 가능한 영역들
    var availableTerritories: [Territory] { ... }
    
    // Computed: 아직 미탐험 영역들
    var unexploredTerritories: [Territory] { ... }
    
    // Computed: 탐험 진행률 (0.0 ~ 1.0)
    var explorationProgress: Double { ... }
}
```

---

## 🎨 UX 설계

### 메타포: 안개 속 지도

- **미탐험 영역**: 짙은 안개 (fog)로 가려져 있음
- **탐험한 영역**: 안개가 걷히고 밝게 빛남
- **깊이**: 표면 → 개인적 → 깊은 → 내밀한 (동심원처럼)

### 화면 구성

#### 1. 사람 목록 (People List)
```
┌─────────────────────────────────┐
│  🔍 검색                        │
├─────────────────────────────────┤
│                                 │
│  [🌗] 김철수        ████░░ 65%  │
│       3개 영역 탐험             │
│                                 │
│  [🌑] 이영희        █░░░░░ 15%  │
│       아직 표면적               │
│                                 │
│  [🌕] 박지훈        ████████ 92%│
│       깊은 관계                 │
│                                 │
└─────────────────────────────────┘

- 프로필 옆 달 아이콘: 🌑 → 🌒 → 🌓 → 🌔 → 🌕 (관계 깊이)
- 진행률 바: 탐험한 영역 비율
```

#### 2. 지도 뷰 (Map View) - 핵심 화면

```
              ┌─────────────────────────────────┐
              │         [김철수의 지도]          │
              │              🌓                  │
              ├─────────────────────────────────┤
              │                                 │
              │     ░░░░░░░░░░░░░░░░░░░░░░     │
              │   ░░░░░ 🌌 내밀한 ░░░░░░░░     │  ← 안개 (잠김)
              │   ░░░░░░░░░░░░░░░░░░░░░░░░     │
              │   ░░░  ╭─────────────╮  ░░░    │
              │   ░░   │  🌃 깊은    │   ░░    │  ← 흐린 안개
              │   ░░   │  가족 ✨    │   ░░    │
              │   ░    ╰─────────────╯    ░    │
              │        ╭─────────────╮         │
              │        │ 🌆 개인적   │         │  ← 옅은 안개
              │        │ 고민 ✨     │         │
              │        │ 목표        │         │
              │        ╰─────────────╯         │
              │       ╭───────────────╮        │
              │       │  🌅 표면      │        │  ← 밝음
              │       │ 닉네임 ✨     │        │
              │       │ 취미 ✨       │        │
              │       │ 하는 일 ✨    │        │
              │       ╰───────────────╯        │
              │                                 │
              │   [ + 새로운 발견 추가 ]        │
              └─────────────────────────────────┘

✨ = 탐험 완료 (빛남)
░░ = 안개 (미탐험/잠김)
```

#### 3. 영역 상세 (Territory Detail)

```
┌─────────────────────────────────┐
│  ← 지도    닉네임의 이유    ✨   │
├─────────────────────────────────┤
│                                 │
│  "달빛이라는 닉네임은            │
│   밤에 산책하는 걸 좋아해서"     │
│                                 │
│  📅 2024.02.15 알게 됨          │
│  💙 가까워진 느낌               │
│                                 │
│  ─────────────────────────────  │
│                                 │
│  💬 맥락                        │
│  "첫 번째 저녁 식사에서          │
│   왜 그 닉네임인지 물어봤다"     │
│                                 │
│                    [수정] [삭제] │
└─────────────────────────────────┘
```

#### 4. 발견 추가 (Add Discovery)

```
┌─────────────────────────────────┐
│  ×          새로운 발견          │
├─────────────────────────────────┤
│                                 │
│  어떤 영역을 탐험했나요?         │
│                                 │
│  🌅 표면                        │
│  ┌─────┐ ┌─────┐ ┌─────┐       │
│  │닉네임│ │ 취미 │ │하는일│       │
│  └─────┘ └─────┘ └─────┘       │
│  ┌─────┐ ┌─────┐                │
│  │ 고향 │ │좋아함│                │
│  └─────┘ └─────┘                │
│                                 │
│  🌆 개인적 (현재 깊이에서 가능)   │
│  ┌─────┐ ┌─────┐ ┌─────┐       │
│  │ 고민 │ │ 목표 │ │ 일상 │       │
│  └─────┘ └─────┘ └─────┘       │
│                                 │
│  🌃 깊은 🔒 (더 친해지면...)     │
│                                 │
├─────────────────────────────────┤
│  뭘 알게 됐나요?                 │
│  ┌─────────────────────────────┐│
│  │                             ││
│  │                             ││
│  └─────────────────────────────┘│
│                                 │
│  어떤 상황에서? (선택)           │
│  ┌─────────────────────────────┐│
│  │ 저녁 먹으면서...             ││
│  └─────────────────────────────┘│
│                                 │
│  그때 느낌은?                   │
│  😮 😊 🤝 💙 🤔                 │
│                                 │
│         [ ✨ 발견 기록하기 ]     │
└─────────────────────────────────┘
```

#### 5. 타임라인 (Discovery Timeline)

```
┌─────────────────────────────────┐
│  김철수의 발견들                 │
├─────────────────────────────────┤
│                                 │
│  2024.02                        │
│  ├── 15일 ✨ 닉네임의 이유       │
│  │       "달빛 - 밤 산책"       │
│  │                              │
│  ├── 18일 ✨ 요즘 고민          │
│  │       "이직 고민중"          │
│  │                              │
│  └── 22일 ✨ 좋아하는 음식      │
│          "매운 거 못 먹음"      │
│                                 │
│  2024.01                        │
│  └── 05일 ✨ 하는 일            │
│          "스타트업 개발자"      │
│                                 │
└─────────────────────────────────┘
```

---

## 🎭 인터랙션 & 애니메이션

### 1. 안개 걷힘 (Fog Reveal)
- 새로운 발견 저장 시
- 해당 영역의 안개가 서서히 걷히며 ✨ 반짝임

### 2. 달 차오름 (Moon Phase)
- 관계 깊이가 올라갈 때
- 🌑 → 🌒 → 🌓 → 🌔 → 🌕
- 부드러운 glow 애니메이션

### 3. 영역 잠금 해제 (Unlock)
- 깊이가 올라가면 새로운 영역이 잠금 해제
- 자물쇠 → 열림 애니메이션

### 4. 지도 시각화
- 동심원 레이아웃 (중심 = 내밀한, 바깥 = 표면)
- 탐험한 영역은 빛나는 노드
- 미탐험 영역은 흐릿한 점

---

## 🗑️ 제거할 것들

### 모델
- [x] ContactType (미팅/식사/전화/메시지)
- [x] RecordTag (약속/질문/고민/피드백)
- [x] Record 전체 (Discovery로 대체)
- [x] InteractionRecord
- [x] ConversationRecord
- [x] MeetingRecord
- [x] QuickMemoArchive
- [x] MentoringSession
- [x] lastMentoring, lastMeal, lastContact
- [x] isNeglected 로직

### 뷰
- [x] MacPersonRecordsTab (기존 기록 탭)
- [x] AddRecordSheet
- [x] 복잡한 필터 시스템

### 개념
- [x] "소홀함" 판정
- [x] 우선순위 시스템
- [x] 해결/미해결 상태

---

## ✅ 남길 것

### 모델
- Person (간소화)
- PersonTag (그룹핑용)
- PersonContext → Discovery로 진화

### 개념
- ActionPhase → RelationshipDepth로 rename
- 관계 시작일
- 프로필 이미지

---

## 📱 화면별 구현 순서

### Phase 1: 핵심 모델
1. Territory enum
2. RelationshipDepth enum
3. Discovery model
4. Person 간소화

### Phase 2: 지도 뷰 (핵심)
1. MapView - 동심원 레이아웃
2. TerritoryNode - 각 영역 노드
3. FogOverlay - 안개 효과
4. DiscoverySheet - 발견 추가

### Phase 3: 목록 & 상세
1. PeopleListView 재설계
2. PersonDetailView - 탭 구조 변경
3. DiscoveryTimeline

### Phase 4: 애니메이션 & 폴리시
1. 안개 걷힘 효과
2. 달 차오름 애니메이션
3. 잠금 해제 효과

---

## 🎯 성공 지표

- [ ] 앱을 열면 "이 사람에 대해 뭘 모르지?"가 보인다
- [ ] 대화 후 "오늘 뭘 알게 됐지?"를 기록하게 된다
- [ ] 지도가 밝아지는 게 재미있다
- [ ] "관리해야 해" 느낌이 아니라 "탐험하고 싶다" 느낌

---

*마지막 업데이트: 2026-02-21*
