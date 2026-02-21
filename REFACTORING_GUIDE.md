# RapportMap 리팩토링 가이드

## 📁 새로운 폴더 구조

```
RapportMap/
├── Shared/                        ← 공통 코드 (새로 생성됨)
│   ├── Models/                    ← 통합된 모델 (20개 파일)
│   │   ├── Person.swift           ← iOS/macOS 플랫폼 분기 포함
│   │   ├── MeetingRecord.swift
│   │   ├── InteractionRecord.swift
│   │   ├── ConversationRecord.swift
│   │   ├── PersonAction.swift
│   │   ├── RapportAction.swift
│   │   ├── QuickMemoArchive.swift ← iOS 버전 (imageDataArray 포함)
│   │   ├── TimelineItem.swift     ← iOS 버전 (이미지 지원)
│   │   └── ... (총 20개)
│   │
│   ├── Services/                  ← 통합된 서비스 (4개 파일)
│   │   ├── CalendarManager.swift  ← iOS/macOS 통합 (#if os 분기)
│   │   ├── CloudKitManager.swift
│   │   ├── MentoringManager.swift
│   │   └── RelationshipStateManager.swift
│   │
│   └── Utilities/
│       └── Date+Ext.swift
│
├── iOS/                           ← iOS 전용 코드 (새로 생성됨)
│   ├── Views/                     ← RapportMap/Views 복사본
│   │   ├── PersonDetailView.swift ← 69KB (분할 필요!)
│   │   ├── PeopleListView.swift
│   │   ├── VoiceRecorder/
│   │   ├── Timeline/
│   │   └── ...
│   └── iOSApp.swift
│
├── macOS/                         ← macOS 전용 코드 (새로 생성됨)
│   ├── Views/
│   │   ├── MacPersonInfoTab.swift
│   │   ├── MacPersonRecordsTab.swift
│   │   └── ...
│   ├── MacPersonDetailView.swift
│   ├── MacPeopleListView.swift
│   └── macApp.swift
│
├── RapportMap/                    ← 기존 iOS 폴더 (유지됨 - 삭제하지 않음)
│   ├── Models/                    ← 기존 모델들 (Shared로 통합됨)
│   ├── Manager/                   ← 기존 서비스 (Shared로 통합됨)
│   └── Views/                     ← 기존 뷰들 (iOS로 복사됨)
│
└── mac/                           ← 기존 macOS 폴더 (유지됨 - 삭제하지 않음)
    ├── Models/
    ├── Manager/
    └── Views/
```

## ✅ 완료된 작업

### 1. Shared 폴더 생성 및 Models 통합
- iOS와 macOS Models 비교 완료
- 통합 버전 생성:
  - `Person.swift`: macOS 기반 + iOS 호환 (BadgeDetail에 Identifiable, Color/NSColor 분기)
  - `QuickMemoArchive.swift`: iOS 버전 (imageDataArray 포함)
  - `TimelineItem.swift`: iOS 버전 (이미지 첨부 지원)
  - 기타 모델: macOS 버전 기준 (동일하거나 더 완전함)

### 2. Services 통합
- `CalendarManager.swift`: #if os(iOS/macOS) 분기 처리 완료
- 나머지 서비스들: 동일하여 macOS 버전 복사

### 3. 플랫폼별 폴더 생성
- `iOS/Views/`: RapportMap/Views에서 복사
- `macOS/Views/`: mac/Views에서 복사

## 🔧 Xcode에서 해야 할 작업

### 1단계: Shared 타겟 설정
1. Xcode에서 프로젝트 열기
2. File > New > Group > "Shared" (이미 생성됨)
3. Shared 그룹에 파일들 드래그 (Finder에서 Xcode로)
4. Target Membership에서 iOS와 macOS 둘 다 체크

### 2단계: 기존 파일 참조 업데이트
1. 기존 `RapportMap/Models/` 파일들의 Target Membership에서 iOS 체크 해제
2. 기존 `mac/Models/` 파일들의 Target Membership에서 macOS 체크 해제
3. 대신 `Shared/Models/` 파일들이 양쪽 타겟에 포함되도록 설정

### 3단계: iOS/macOS 전용 뷰 설정
1. `iOS/Views/` 파일들은 iOS 타겟만
2. `macOS/Views/` 파일들은 macOS 타겟만

## ⚠️ 추가 작업 필요

### PersonDetailView 분할 (권장)
현재 `iOS/Views/PersonDetailView.swift`가 69KB, 1813줄로 너무 큽니다.

**추천 분할 구조:**
```
iOS/Views/PersonDetail/
├── PersonDetailView.swift           ← 메인 뷰 (State, body, 탭 전환)
├── PersonDetailView+Records.swift   ← 기록 탭 섹션들
├── PersonDetailView+Timeline.swift  ← 타임라인 탭
├── PersonDetailView+Activities.swift← 활동 탭 (캘린더, 녹음)
├── PersonDetailView+Info.swift      ← 정보 탭
└── Components/
    ├── BadgeCard.swift
    ├── NotificationBadgeRow.swift
    └── ImportantRecordRows.swift
```

### iOS 전용 파일 확인
- `ShareSheet.swift`: UIKit 의존 (iOS 전용)
- `EditConversationRecordSheet.swift`: iOS Views에 있어야 함
- `ImagePicker.swift`, `ContactsManager.swift`: iOS 전용

## 📝 변경된 주요 파일들

| 파일 | 변경 내용 |
|------|----------|
| `Shared/Models/Person.swift` | BadgeDetail에 Identifiable 추가, Color/NSColor #if 분기, tabIndex 플랫폼별 값 |
| `Shared/Services/CalendarManager.swift` | iOS/macOS 권한 체크 통합 (#if os 분기) |
| `Shared/Models/QuickMemoArchive.swift` | imageDataArray 속성 포함 (iOS 기능) |
| `Shared/Models/TimelineItem.swift` | 이미지 첨부 지원 (iOS 기능) |

## 🚫 삭제하지 않은 파일들

기존 `RapportMap/`, `mac/` 폴더는 그대로 유지됩니다.
Xcode에서 파일 참조를 새 구조로 변경한 후, 확인이 끝나면 삭제하세요.

## 💡 팁

```swift
// 플랫폼별 코드 작성 시
#if os(iOS)
// iOS 전용 코드
#elseif os(macOS)
// macOS 전용 코드
#endif

// 또는 canImport 사용
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif
```
