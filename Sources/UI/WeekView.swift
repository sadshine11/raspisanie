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
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenHeader(title: "Неделя", subtitle: store.selectedGroup.name)

                    weekPicker

                    if let schedule = store.schedule {
                        let available = Planner.availableSubgroups(in: schedule)
                        if available.count > 1 {
                            SubgroupPicker(available: available)
                        }
                    }

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
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh() }
        }
        .onAppear {
            guard !didSyncWeek else { return }
            week = currentWeek
            didSyncWeek = true
        }
    }

    // MARK: - Переключатель недель

    /// Те же чипы, что и у подгруппы: выбранный — белая пилюля.
    private var weekPicker: some View {
        HStack(spacing: 8) {
            weekChip(1)
            weekChip(2)
            Spacer(minLength: 0)
            if week == currentWeek {
                Chip(text: "текущая", style: .accent, size: 13)
            }
        }
    }

    private func weekChip(_ index: Int) -> some View {
        let isSelected = week == index
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { week = index }
        } label: {
            Chip(text: "\(index)-я неделя", style: isSelected ? .solid : .quiet, size: 13)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
        VStack(alignment: .leading, spacing: 10) {
            SectionBlock(title: day.name,
                         detail: detail(for: day),
                         badge: "\(day.lessons.count)")

            ForEach(day.lessons) { lesson in
                LessonRow(lesson: lesson,
                          homework: day.date.map { homework.items(for: lesson, on: $0) } ?? [])
            }
        }
        .padding(.top, 2)
    }

    private func detail(for day: DayEntry) -> String? {
        var parts: [String] = []
        if let date = day.date { parts.append(date.shortRussian) }
        if day.name == today && week == currentWeek { parts.append("сегодня") }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
