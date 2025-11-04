# RapportMap - 음성 녹음 권한 설정

## 필수 권한 설정

음성 녹음 기능을 사용하려면 Info.plist에 다음 권한을 추가해야 합니다.

### Xcode에서 설정하는 방법:

1. **프로젝트 Navigator**에서 프로젝트 파일 선택
2. **Targets** → **RapportMap** 선택
3. **Info** 탭 선택
4. **Custom iOS Target Properties** 섹션에서 `+` 버튼 클릭
5. 다음 키들을 추가:

#### 마이크 권한 (필수)
```
Privacy - Microphone Usage Description
```
**Value:** `만남을 음성으로 기록하기 위해 마이크 접근이 필요합니다`

#### 음성 인식 권한 (필수)
```
Privacy - Speech Recognition Usage Description
```
**Value:** `음성을 텍스트로 변환하기 위해 음성 인식 권한이 필요합니다`

### 또는 Info.plist XML 직접 편집:

Info.plist 파일에 다음 내용을 추가:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>만남을 음성으로 기록하기 위해 마이크 접근이 필요합니다</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>음성을 텍스트로 변환하기 위해 음성 인식 권한이 필요합니다</string>
```

## 기능 설명

### 음성 녹음
- PersonDetailView에서 "오늘의 만남 기록하기" 버튼 클릭
- 녹음 시작/중지
- 만남 타입 선택 (멘토링, 식사, 커피, 일반 대화 등)

### 음성 → 텍스트 변환
- 녹음 종료 시 자동으로 한국어 음성 인식
- 변환된 텍스트는 MeetingRecord에 저장

### 음성 파일 공유
- 녹음된 음성 파일(.m4a)을 다른 앱으로 공유 가능
- 외부 분석 프레임워크로 전송 가능

## 문제 해결

### 권한이 거부되었을 때
1. 설정 앱 열기
2. RapportMap 앱 찾기
3. 마이크 및 음성 인식 권한 활성화

### 음성 인식이 작동하지 않을 때
- 인터넷 연결 확인 (음성 인식은 온라인 필요)
- 한국어 음성 인식이 설정되어 있는지 확인
- 디바이스 설정 → Siri 및 검색 → 언어 확인
