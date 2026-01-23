import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            PeopleListView()
                .tabItem {
                    Label("사람", systemImage: "person.2.fill")
                }
                .tag(0)

            MentoringListView()
                .tabItem {
                    Label("멘토링", systemImage: "doc.text.fill")
                }
                .tag(1)
        }
    }
}
