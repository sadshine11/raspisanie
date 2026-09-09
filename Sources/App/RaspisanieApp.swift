import SwiftUI

@main
struct RaspisanieApp: App {
    @StateObject private var store = ScheduleStore()
    @StateObject private var homework = HomeworkStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(homework)
                .tint(Theme.tint)
                // Приложение всегда тёмное, независимо от настроек системы.
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
