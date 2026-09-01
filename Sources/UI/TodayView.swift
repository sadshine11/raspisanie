import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: ScheduleStore
    @Binding var selectedTab: RootTab

    @State private var now = Date()
    private let ticker = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    private var plan: DayPlan? {
        guard let schedule = store.schedule else { return nil }
        return Planner.plan(for: now, schedule: schedule, subgroup: store.subgroup)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
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
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Сегодня")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
        }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: - Шапка

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(now.longRussian.capitalizedFirst)
                .font(Theme.rounded(26, .bold))

            HStack(spacing: 8) {
                Text(store.selectedGroup.name)
                    .font(Theme.rounded(14, .medium))
                    .foregroundColor(.secondary)

                if let plan {
                    Text("·").foregroundColor(.secondary)
                    Text("\(plan.weekIndex)-я неделя")
                        .font(Theme.rounded(13, .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.accentColor.opacity(0.14)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: - Занятия

    private func lessons(_ plan: DayPlan) -> some View {
        let current = Planner.currentLesson(in: plan.lessons, at: now)
        let next = Planner.nextLesson(in: plan.lessons, at: now)

        return VStack(alignment: .leading, spacing: 10) {
            if current == nil, let next {
                UpNextCard(lesson: next, minutesLeft: minutes(until: next))
            }

            ForEach(plan.lessons) { lesson in
                LessonRow(
                    lesson: lesson,
                    isNow: lesson.id == current?.id,
                    progress: lesson.id == current?.id ? Planner.progress(of: lesson, at: now) : 0
                )
            }

            if current != nil || next != nil {
                Text("Осталось занятий сегодня: \(remainingCount(plan))")
                    .font(Theme.rounded(13))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }
        }
    }

    private var freeDay: some View {
        VStack(alignment: .leading, spacing: 12) {
            EmptyBlock(
                icon: "sun.max.fill",
                title: "Сегодня занятий нет",
                message: "Свободный день."
            )

            if let schedule = store.schedule,
               let nextDay = Planner.nextTeachingDay(from: now, schedule: schedule,
                                                     subgroup: store.subgroup) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ближайший учебный день")
                        .font(Theme.rounded(13, .semibold))
                        .foregroundColor(.secondary)
                    Text("\(nextDay.dayName), \(nextDay.date.shortRussian) · \(nextDay.weekIndex)-я неделя")
                        .font(Theme.rounded(15, .semibold))
                    ForEach(nextDay.lessons.prefix(3)) { lesson in
                        HStack(spacing: 8) {
                            Text(lesson.time.split(separator: "-").first.map(String.init) ?? "")
                                .font(Theme.rounded(13, .medium))
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                            Text(lesson.name)
                                .font(Theme.rounded(14))
                                .lineLimit(1)
                        }
                    }
                    if nextDay.lessons.count > 3 {
                        Text("и ещё \(nextDay.lessons.count - 3)")
                            .font(Theme.rounded(13))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.cardPadding)
                .card()
            }
        }
    }

    // MARK: - Баннеры и подвал

    private var changesBanner: some View {
        Button {
            selectedTab = .changes
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Расписание изменилось")
                        .font(Theme.rounded(15, .semibold))
                        .foregroundColor(.primary)
                    Text(declension(store.unseenCount))
                        .font(Theme.rounded(13))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(Theme.cardPadding)
            .card(tint: .orange)
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
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
            }
        }
    }

    // MARK: - Счёт

    private func minutes(until lesson: Lesson) -> Int {
        max(0, (lesson.startMinutes ?? 0) - Planner.minutesSinceMidnight(now))
    }

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

// MARK: - Карточка «дальше»

struct UpNextCard: View {
    let lesson: Lesson
    let minutesLeft: Int

    private var accent: Color { Theme.color(forKind: lesson.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.checkmark")
                Text("Следующая пара")
            }
            .font(Theme.rounded(12, .bold))
            .foregroundColor(accent)

            Text(lesson.name)
                .font(Theme.rounded(19, .bold))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Text(lesson.time)
                    .font(Theme.rounded(14, .medium))
                    .monospacedDigit()
                if let room = lesson.room {
                    Text("· \(room)").font(Theme.rounded(14))
                }
            }
            .foregroundColor(.secondary)

            if minutesLeft > 0 {
                Text(timeLeftText)
                    .font(Theme.rounded(13, .semibold))
                    .foregroundColor(accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .card(tint: accent)
    }

    private var timeLeftText: String {
        if minutesLeft >= 60 {
            let h = minutesLeft / 60
            let m = minutesLeft % 60
            return m == 0 ? "начнётся через \(h) ч" : "начнётся через \(h) ч \(m) мин"
        }
        return "начнётся через \(minutesLeft) мин"
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
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .card(tint: tint)
    }
}

struct EmptyBlock: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 34))
                .foregroundColor(.secondary.opacity(0.7))
            Text(title)
                .font(Theme.rounded(17, .semibold))
            if let message {
                Text(message)
                    .font(Theme.rounded(14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .card()
    }
}

struct LoadingBlock: View {
    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Загружаем расписание…")
                .font(Theme.rounded(14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
        .card()
    }
}

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}
