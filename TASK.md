# RapportMap — 지도 디자인 + 프로필 사진 구현

## 프로젝트 경로
/Users/leeo/Documents/workspace/code/RapportMap

## 작업 1: PersonMapView.swift — 중세 왕국 지도 스타일

현재: 동심원(Circle) 기반 디자인
목표: 파치먼트(양피지) 배경의 중세 왕국 지도 스타일

### 지형 레이어 (SwiftUI Path로 구현)
- **배경**: RadialGradient(#f8edd0 → #e8d098 → #c89050) 파치먼트 느낌
- **격자**: 연한 갈색 선 (rgba(100,60,10,.05)) 56pt 간격
- **표면(surface) 존**: 전체 배경, 황금 평야 색상 (#dfc870, opacity 0.55)
- **개인(personal) 존**: 8각형 Path, 초록 숲 (#6a9e3c, opacity 0.88)  
  포인트: (0.16,0.16) (0.5,0.11) (0.84,0.16) (0.89,0.5) (0.84,0.84) (0.5,0.89) (0.16,0.84) (0.11,0.5) (비율, 560×560 기준)
- **깊은(deep) 존**: 6각형(불규칠) Path, 회청 산악 (#7a8a96, opacity 0.92)
  포인트: (0.32,0.27) (0.5,0.23) (0.69,0.28) (0.74,0.5) (0.68,0.73) (0.5,0.77) (0.31,0.73) (0.26,0.5)
- **내밀한(intimate) 존**: 육각형 Path, 어두운 성채 (#3e3028, opacity 1.0)
  포인트: (0.38,0.37) (0.62,0.37) (0.64,0.5) (0.61,0.63) (0.38,0.63) (0.36,0.5)

### 경계선
각 존의 Path를 동일 포인트로 stroke만 그리기:
- 표면 경계: rgba(40,25,5,.65) stroke width 2
- 개인 경계: rgba(30,25,18,.8) stroke width 2.5
- 깊은/내밀한 경계: rgba(20,15,8,.95) stroke width 3

### 강 (decorative)
서쪽에서 중앙으로 흐르는 강 Path (SwiftUI Path cubic bezier):
- stroke color: Color(hex: "3878a8"), opacity 0.45, lineWidth 5.5
- 위에 밝은 highlight: Color(hex: "78c0e0"), opacity 0.65, lineWidth 2.5
- 좌표 (560 기준): (0,220) → c(50,215) → (100,240) → c(165,265) → (228,268)

### 안개 오버레이
- 잠긴 영역(deep, intimate)에 흰빛 안개: .blur(radius: 14)
- 깊은 존: fill rgba(208,200,182,.78)
- 내밀한 존: fill rgba(195,185,168,.95) (blur 없이, 불투명)

### 장식 테두리
지도 바깥쪽:
- 첫 번째: stroke #6a3e10, width 3, rounded rect
- 두 번째: dashed stroke rgba(100,64,20,.4), width 1, dash [6,4]
- 코너 다이아몬드: 45도 회전 정사각형 + 원 장식 (Color(hex:"c88020"))

### 나침반 (우상단)
간단한 SwiftUI로: 원 + 4방향 삼각형 + 중앙 원
- 위쪽(N): #c07010 (금색), 아래쪽(S): #7a4e28, 좌우: #8a6030

### 영역 이름 라벨 (지도 각 존에 겹쳐서)
italic Georgia-like font, 매우 작게, 낮은 opacity:
- 북부: "― 북부 평야 ―" (상단 중앙)
- 숲 안: "숲의 북쪽 길목" 등
- 산악/성채는 opacity 매우 낮게

### 영역 노드 (Territory markers)
- 탐험 완료: 금색 원 배경 + 노드 이모지 + 이름, 글로우 효과
- 미탐험/접근가능: 점선 원 + 이모지
- 잠김: 자물쇠 아이콘, 흐릿하게
- 크기: 약 44×44pt (기존 TerritoryNode 활용 가능, 스타일 변경)

### 카르투슈 (지도 하단 중앙)
```
[person.name]의 탐험 지도 · Anno 2025
```
타원형 배경, 양피지 스타일

### 기존 기능 유지
- 핀치 줌 & 드래그 패닝
- 탭으로 영역 선택 (AddDiscovery, DiscoveryDetail 시트)
- 줌 컨트롤 버튼

---

## 작업 2: 프로필 사진 기능

### 위치
PersonMapView 상단 (또는 PeopleListView의 PersonCard)에 프로필 카드 추가

### Person 모델 확인
`Shared/Models/Person.swift`에 이미 `var profileImageData: Data? // 프로필 사진` 있음

### UI 구현
```
┌─────────────────────────────────┐
│  [아바타 52×52]  이름            │
│   [+ 뱃지]      개인적 단계      │
│                 ████░░ 7/22 탐험 │
└─────────────────────────────────┘
```

#### 아바타 컴포넌트
- 크기: 52×52, 원형
- 사진 없을 때: MoonPhase 이모지 (🌓) + 골드 그라디언트 배경
- 사진 있을 때: 실제 이미지 (object-fit: cover)
- 호버/탭 시: 반투명 오버레이 + 👁 아이콘
- 우하단 뱃지(+): 20×20 금색 원, 탭 시 사진 선택

#### 사진 선택 (iOS)
- `.photosPicker` 또는 `PhotosUI.PhotosPicker` 사용
- 선택 후 Data로 변환 → `person.profileImageData = data`
- 저장은 SwiftData context.save() 자동으로

#### 사진 모달 (탭 시 전체화면)
- 아바타 탭 시: 풀스크린 오버레이
- 원형 이미지 크게 (화면 80% 크기)
- 배경: rgba(0,0,0,.88)
- "탭하면 닫힙니다" 힌트 텍스트
- 탭하면 닫힘, macOS는 ESC로도 닫힘

---

## 파일 구조
- `PersonMapView.swift` — 지도 뷰 (메인)
- `PersonProfileCard.swift` — 새 파일: 상단 프로필 카드
- `FogRevealEffect.swift` — 기존 파일 확인 후 활용

## 주의사항
- SwiftUI + SwiftData 프로젝트 (iOS 17+, macOS 14+)
- #Preview 포함
- 컴파일 에러 없도록 기존 모델/타입 확인하며 작업
- `Territory.allCases`, `RelationshipDepth.allCases` 등 기존 enum 활용

## 완료 시 알림
When completely finished, run:
openclaw system event --text "Done: RapportMap 지도 + 프로필 사진 구현 완료" --mode now
