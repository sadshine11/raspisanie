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
                VStack(alignment: .leading, spacing: 14) {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Неделя")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
        }
        .onAppear {
            guard !didSyncWeek else { return }
            week = currentWeek
            didSyncWeek = true
        }
    }

    // MARK: - Переключатель недель

    /// Свой переключатель вместо `.segmented`: системный сегмент в тёмной теме
    /// рисует светло-серую подложку, которая на фоне карточек выглядит
    /// чужеродной заплаткой.
    private var weekPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                weekTab(1)
                weekTab(2)
            }
            .padding(4)
            .background(
                Capsule().fill(Theme.surface)
                    .overlay(Capsule().strokeBorder(Theme.hairline, lineWidth: 1))
            )

            Text(week == currentWeek
                 ? "Идёт сейчас · \(store.selectedGroup.name)"
                 : "Следующая · \(store.selectedGroup.name)")
                .font(Theme.rounded(12))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.top, 6)
    }

    private func weekTab(_ index: Int) -> some View {
        let isSelected = week == index
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { week = index }
        } label: {
            Text("\(index)-я неделя")
                .font(Theme.rounded(14, .semibold))
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(isSelected
                                   ? AnyShapeStyle(LinearGradient(
                                        colors: [Theme.accent, Theme.subgroup],
                                        startPoint: .leading, endPoint: .trailing))
                                   : AnyShapeStyle(Color.clear))
                )
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
            HStack(spacing: 8) {
                Text(day.name)
                    .font(Theme.rounded(19, .bold))
                if day.name == today && week == currentWeek {
                    Text("сегодня")
                        .font(Theme.rounded(11, .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Theme.accent))
                }
                Spacer()
                if let date = day.date {
                    Text(date.shortRussian)
                        .font(Theme.rounded(12, .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                Text("\(day.lessons.count)")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 6)

            ForEach(day.lessons) { lesson in
                LessonRow(lesson: lesson,
                          homework: day.date.map { homework.items(for: lesson, on: $0) } ?? [])
            }
        }
    }
}
