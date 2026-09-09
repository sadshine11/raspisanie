import SwiftUI

struct WeekView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var homework: HomeworkStore
    @State private var week: Int = 1
    @State private var didSyncWeek = false

    private var today: String { Weekday.name(for: Date(), calendar: Planner.calendar) }
    private var currentWeek: Int { Planner.weekIndex(for: Date()) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Неделя", selection: $week) {
                        Text("1-я неделя").tag(1)
                        Text("2-я неделя").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                } footer: {
                    Text(week == currentWeek
                         ? "Текущая · \(store.selectedGroup.name)"
                         : "Следующая · \(store.selectedGroup.name)")
                }

                if let schedule = store.schedule {
                    let days = daysWithLessons(schedule)
                    if days.isEmpty {
                        Section {
                            EmptyBlock(icon: "calendar", title: "На этой неделе занятий нет")
                        }
                    } else {
                        ForEach(days, id: \.name) { day in
                            daySection(day)
                        }
                    }
                } else if store.state.isLoading {
                    Section { LoadingBlock() }
                } else {
                    Section {
                        EmptyBlock(icon: "calendar.badge.exclamationmark",
                                   title: "Расписание не загружено",
                                   message: "Потяните вниз, чтобы обновить.")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Неделя")
            .refreshable { await store.refresh() }
        }
        .onAppear {
            guard !didSyncWeek else { return }
            week = currentWeek
            didSyncWeek = true
        }
    }

    // MARK: - День

    private struct DayEntry {
        var name: String
        var lessons: [Lesson]
        /// Календарная дата этого дня — нужна, чтобы подтянуть домашние задания.
        var date: Date?
    }

    private func daysWithLessons(_ schedule: Schedule) -> [DayEntry] {
        let from = Date()
        return Weekday.names.compactMap { name in
            guard let day = schedule.day(named: name),
                  let block = day.week(week) else { return nil }
            let lessons = Planner.filter(block.lessons, subgroup: store.subgroup)
            guard !lessons.isEmpty else { return nil }
            return DayEntry(name: name,
                            lessons: lessons,
                            date: Planner.date(ofDay: name, weekIndex: week, from: from))
        }
    }

    private func daySection(_ day: DayEntry) -> some View {
        Section {
            ForEach(day.lessons) { lesson in
                CompactLessonRow(lesson: lesson,
                                 homework: day.date.map { homework.items(for: lesson, on: $0) } ?? [])
            }
        } header: {
            HStack {
                Text(title(for: day))
                Spacer()
                Text("\(day.lessons.count)")
            }
        }
    }

    private func title(for day: DayEntry) -> String {
        var parts = [day.name]
        if let date = day.date { parts.append(date.shortRussian) }
        if day.name == today && week == currentWeek { parts.append("сегодня") }
        return parts.joined(separator: " · ")
    }
}
