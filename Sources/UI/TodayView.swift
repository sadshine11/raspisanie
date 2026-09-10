import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var homework: HomeworkStore
    @Binding var selectedTab: RootTab

    @State private var now = Date()
    /// Прошедшие занятия свёрнуты: день кончился, они уже не нужны —
    /// но иногда хочется свериться, что именно было.
    @State private var showFinishedLessons = false
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var plan: DayPlan? {
        guard let schedule = store.schedule else { return nil }
        return Planner.plan(for: now, schedule: schedule, subgroup: store.subgroup)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header

                    if let schedule = store.schedule {
                        let available = Planner.availableSubgroups(in: schedule)
                        if available.count > 1 {
                            SubgroupPicker(available: available)
                        }
                    }

                    if let error = store.state.errorText {
                        StatusBanner(text: error, icon: "wifi.exclamationmark", tint: .orange)
                    }

                    if store.unseenCount > 0 {
                        changesBanner
                    }

                    if let plan {
                        if plan.isEmpty {
                            freeDay
                        } else if Planner.isDayFinished(plan.lessons, at: now) {
                            finishedDay(plan)
                        } else {
                            lessons(plan)
                        }
                    } else if store.state.isLoading {
                        LoadingBlock()
                    } else {
                        EmptyBlock(
                            icon: "calendar.badge.exclamationmark",
                            title: "Расписание не загружено",
                            message: "Потяните вниз, чтобы обновить."
                        )
                    }

                    footer
                }
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh() }
        }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: - Шапка

    private var header: some View {
        ScreenHeader(title: "Сегодня", subtitle: subtitle) {
            if let plan {
                Chip(text: "\(plan.weekIndex)-я неделя", icon: "calendar", style: .accent)
            }
        }
    }

    private var subtitle: String {
        "\(now.dayAndMonthRussian), \(weekdayName) · \(store.selectedGroup.name)"
    }

    private var weekdayName: String {
        Weekday.name(for: now, calendar: Planner.calendar).lowercased()
    }

    // MARK: - Занятия

    private func lessons(_ plan: DayPlan) -> some View {
        let current = Planner.currentLesson(in: plan.lessons, at: now)
        let minutesNow = Planner.minutesSinceMidnight(now)

        return VStack(alignment: .leading, spacing: 10) {
            SectionBlock(title: "Расписание",
                         detail: statusText(plan),
                         badge: "\(remainingCount(plan))")

            ForEach(plan.lessons) { lesson in
                LessonRow(
                    lesson: lesson,
                    isNow: lesson.id == current?.id,
                    progress: lesson.id == current?.id ? Planner.progress(of: lesson, at: now) : 0,
                    isPast: (lesson.endMinutes ?? 0) <= minutesNow,
                    homework: homework.items(for: lesson, on: plan.date)
                )
            }
        }
    }

    /// «идёт 2-я пара» / «следующая через 25 мин» — то, что раньше занимало
    /// отдельную карточку, теперь одна подпись в шапке раздела.
    private func statusText(_ plan: DayPlan) -> String {
        let minutesNow = Planner.minutesSinceMidnight(now)
        if let current = Planner.currentLesson(in: plan.lessons, at: now) {
            return "идёт \(current.pair.lowercased())"
        }
        if let next = Planner.nextLesson(in: plan.lessons, at: now) {
            let wait = max(0, (next.startMinutes ?? 0) - minutesNow)
            return "следующая через \(minutesText(wait))"
        }
        return "занятия закончились"
    }

    private func minutesText(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) мин" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
    }

    // MARK: - День закончился

    /// Когда последняя пара отзвенела, сегодняшний список сворачивается,
    /// а ниже показывается ближайший учебный день целиком.
    private func finishedDay(_ plan: DayPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionBlock(title: "Сегодня",
                         detail: "занятия закончились",
                         badge: "\(plan.lessons.count)",
                         isExpanded: showFinishedLessons) {
                withAnimation(.easeInOut(duration: 0.22)) { showFinishedLessons.toggle() }
            }
            .accessibilityHint("Показать занятия, которые уже прошли")

            if showFinishedLessons {
                ForEach(plan.lessons) { lesson in
                    LessonRow(lesson: lesson,
                              isPast: true,
                              homework: homework.items(for: lesson, on: plan.date))
                }
            }

            nextDay
        }
    }

    private var freeDay: some View {
        VStack(alignment: .leading, spacing: 10) {
            EmptyBlock(icon: "sun.max.fill",
                       title: "Сегодня занятий нет",
                       message: "Свободный день.")
            nextDay
        }
    }

    private var nextDay: some View {
        Group {
            if let schedule = store.schedule,
               let day = Planner.nextTeachingDay(from: now, schedule: schedule,
                                                 subgroup: store.subgroup) {
                VStack(alignment: .leading, spacing: 10) {
                    SectionBlock(title: nextDayTitle(day),
                                 detail: "\(day.weekIndex)-я неделя",
                                 badge: "\(day.lessons.count)")

                    ForEach(day.lessons) { lesson in
                        LessonRow(lesson: lesson,
                                  homework: homework.items(for: lesson, on: day.date))
                    }
                }
                .padding(.top, 2)
            } else {
                EmptyBlock(icon: "moon.zzz.fill", title: "Дальше занятий нет")
            }
        }
    }

    /// «Завтра · среда» либо «Понедельник, 7 сент.», если завтра выходной.
    private func nextDayTitle(_ day: DayPlan) -> String {
        Planner.calendar.isDateInTomorrow(day.date)
            ? "Завтра · \(day.dayName.lowercased())"
            : "\(day.dayName), \(day.date.shortRussian)"
    }

    // MARK: - Баннеры и подвал

    private var changesBanner: some View {
        Button {
            selectedTab = .changes
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Расписание изменилось")
                        .font(Theme.rounded(15, .semibold))
                        .foregroundColor(.white)
                    Text(declension(store.unseenCount))
                        .font(Theme.rounded(13))
                        .foregroundColor(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(Theme.cardPadding)
            .card(tint: Theme.accent)
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        Group {
            if let checked = store.lastCheckedAt {
                HStack(spacing: 6) {
                    if store.state.isLoading {
                        ProgressView().scaleEffect(0.7)
                    } else {
                        Image(systemName: "checkmark.circle")
                    }
                    Text(store.state.isLoading
                         ? "Проверяем расписание…"
                         : "Сверено с сайтом \(checked.checkedAtDescription)")
                }
                .font(Theme.rounded(12))
                .foregroundColor(Theme.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Счёт

    private func remainingCount(_ plan: DayPlan) -> Int {
        let minutesNow = Planner.minutesSinceMidnight(now)
        return plan.lessons.filter { ($0.endMinutes ?? 0) > minutesNow }.count
    }

    private func declension(_ count: Int) -> String {
        let tail = count % 100
        let last = count % 10
        let word: String
        if (11...14).contains(tail)      { word = "изменений" }
        else if last == 1                { word = "изменение" }
        else if (2...4).contains(last)   { word = "изменения" }
        else                             { word = "изменений" }
        return "\(count) \(word) — посмотреть"
    }
}

// MARK: - Вспомогательные блоки

struct StatusBanner: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(tint)
            Text(text)
                .font(Theme.rounded(14))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .card()
    }
}

struct EmptyBlock: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(Theme.textSecondary.opacity(0.7))
            Text(title)
                .font(Theme.rounded(17, .semibold))
                .foregroundColor(.white)
            if let message {
                Text(message)
                    .font(Theme.rounded(14))
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, 18)
        .card()
    }
}

struct LoadingBlock: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Загружаем расписание…")
                .font(Theme.rounded(14))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .card()
    }
}
