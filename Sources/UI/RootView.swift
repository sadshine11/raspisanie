import SwiftUI

enum RootTab: Hashable {
    case today, week, changes, settings
}

struct RootView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: RootTab = .today
    @State private var didStart = false

    var body: some View {
        TabView(selection: $tab) {
            TodayView(selectedTab: $tab)
                .tabItem { Label("Сегодня", systemImage: "sun.max") }
                .tag(RootTab.today)

            WeekView()
                .tabItem { Label("Неделя", systemImage: "calendar") }
                .tag(RootTab.week)

            ChangesView()
                .tabItem { Label("Изменения", systemImage: "arrow.triangle.2.circlepath") }
                .tag(RootTab.changes)
                .badge(store.unseenCount)

            SettingsView()
                .tabItem { Label("Настройки", systemImage: "gearshape") }
                .tag(RootTab.settings)
        }
        .task {
            guard !didStart else { return }
            didStart = true
            await store.bootstrap()
        }
        .onChange(of: scenePhase) { phase in
            // Возврат в приложение — повод свериться с сайтом заново.
            guard phase == .active, didStart else { return }
            Task { await store.refresh() }
        }
    }
}
