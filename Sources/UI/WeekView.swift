import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var store: ScheduleStore
    @State private var week: Int = 1
    @State private var didSyncWeek = false

    private var today: String { Weekday.name(for: Date(), calendar: Planner.calendar) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    weekPicker

                    if let schedule = store.schedule {
                        let days = daysWithLessons(schedule)
                        if days.isEmpty {
                            EmptyBlock(icon: "calendar", title: "На этой неделе занятий нет")
                        } else {
                            ForEach(days, id: \.name) { day in
                                daySection(day)
                            }
                        }
                    } else if store.state.isLoading {
                        LoadingBlock()
                    } else {
                        EmptyBlock(icon: "calendar.badge.exclamationmark",
                                   title: "Расписание не загружено",
                                   message: "Потяните вниз, чтобы обновить.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Неделя")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
        }
        .onAppear {
            guard !didSyncWeek, let schedule = store.schedule else { return }
            week = schedule.currentWeekIndex
            didSyncWeek = true
        }
    }

    // MARK: - Переключатель недель

    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Неделя", selection: $week) {
                Text("1-я неделя").tag(1)
                Text("2-я неделя").tag(2)
            }
            .pickerStyle(.segmented)

            if let schedule = store.schedule {
                Text(week == schedule.currentWeekIndex
                     ? "Идёт сейчас · \(store.selectedGroup.name)"
                     : "Следующая · \(store.selectedGroup.name)")
                    .font(Theme.rounded(12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 6)
    }

    // MARK: - День

    private struct DayEntry {
        var name: String
        var lessons: [Lesson]
    }

    private func daysWithLessons(_ schedule: Schedule) -> [DayEntry] {
        Weekday.names.compactMap { name in
            guard let day = schedule.day(named: name),
                  let block = day.week(week) else { return nil }
            let lessons = Planner.filter(block.lessons, subgroup: store.subgroup)
            return lessons.isEmpty ? nil : DayEntry(name: name, lessons: lessons)
        }
    }

    private func daySection(_ day: DayEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(day.name)
                    .font(Theme.rounded(19, .bold))
                if day.name == today && week == store.schedule?.currentWeekIndex {
                    Text("сегодня")
                        .font(Theme.rounded(11, .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor))
                }
                Spacer()
                Text("\(day.lessons.count)")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 6)

            ForEach(day.lessons) { lesson in
                LessonRow(lesson: lesson)
            }
        }
    }
}
