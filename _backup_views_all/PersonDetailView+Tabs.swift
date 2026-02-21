//
//  PersonDetailView+Tabs.swift
//  RapportMap
//
//  분할된 파일: 탭 콘텐츠 뷰들
//
//  탭 구조:
//  - dashboard (0): 개인 대시보드 - PersonDashboardTab.swift
//  - records (1): 기록 - 상호작용, 대화 기록
//  - timeline (2): 타임라인 - PersonTimelineView
//  - relationships (3): 관계도 - RelationshipGraphView.swift
//  - info (4): 정보 - 기본 정보, 태그, 액션 체크리스트
//

import SwiftUI

// MARK: - Tab Content Views
extension PersonDetailView {
    
    /// 기록 탭 - 상호작용 기록, 대화 기록
    @ViewBuilder
    var recordsTabContent: some View {
        // 주의가 필요한 항목 (알림 히스토리 기반)
        if !personNotifications.isEmpty {
            notificationBadgesSection
        }

        // 상호작용 기록
        recentInteractionsSection

        // 대화 기록 (고민/질문/약속)
        Section("대화 기록") {
            ConversationRecordsView(person: person)
        }
        
        // 녹음 섹션
        recordingSection
        
        // 캘린더 일정 섹션
        calendarEventsSection
    }

    /// 타임라인 탭 - 전체 타임라인 뷰
    @ViewBuilder
    var timelineTabContent: some View {
        Section {
            PersonTimelineView(person: person)
                .frame(height: 600)
        }
    }
    
    /// 정보 탭 - 기본 정보, 태그, 체크리스트
    @ViewBuilder
    var infoTabContent: some View {
        // 기본 정보
        basicInfoSection
        
        // 태그 섹션
        tagsSection
        
        // 알게 된 정보
        knowledgeSection
        
        // 액션 체크리스트
        actionChecklistSection
        
        // 놓치면 안되는 것들
        criticalActionsSection
    }
}
