import SwiftUI

@main
struct RaspisanieApp: App {
    @StateObject private var store = ScheduleStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
                // Приложение всегда тёмное, независимо от настроек системы.
                .preferredColorScheme(.dark)
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
