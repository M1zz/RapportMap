//
//  MainTabView.swift
//  RapportMap
//
//  메인 탭 뷰 - 대시보드, 관계지도, 멘토링
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // 🆕 대시보드 탭 (첫 화면)
            DashboardView(selectedTab: $selectedTab)
                .tabItem {
                    Label("대시보드", systemImage: "square.grid.2x2.fill")
                }
                .tag(0)
            
            // 관계 지도 탭
            PeopleListView()
                .tabItem {
                    Label("관계지도", systemImage: "person.2.fill")
                }
                .tag(1)

            // 멘토링 탭
            MentoringListView()
                .tabItem {
                    Label("멘토링", systemImage: "doc.text.fill")
                }
                .tag(2)
        }
    }
}

#Preview {
    MainTabView()
}
