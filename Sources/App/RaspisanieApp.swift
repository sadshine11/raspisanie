import SwiftUI

@main
struct RaspisanieApp: App {
    @StateObject private var store = ScheduleStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Color(red: 0.29, green: 0.45, blue: 0.94))
                .environment(\.locale, Locale(identifier: "ru_RU"))
        }
    }
}
