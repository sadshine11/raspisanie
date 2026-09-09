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
            List {
                if let error = store.state.errorText {
                    Section { StatusRow(text: error, icon: "wifi.exclamationmark", tint: .orange) }
                }

                if store.unseenCount > 0 {
                    Section { changesRow }
                }

                if let plan {
                    if plan.isEmpty {
                        Section {
                            EmptyBlock(icon: "sun.max.fill",
                                       title: "Сегодня занятий нет",
                                       message: "Свободный день.")
                        } header: {
                            Text(headerTitle(plan))
                        }
                    } else {
                        summarySection(plan)
                        if Planner.isDayFinished(plan.lessons, at: now) {
                            finishedSection(plan)
                        } else {
                            lessonsSection(plan)
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

                nextDaySection
                footerSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Сегодня")
            .toolbar { subgroupMenu }
            .refreshable { await store.refresh() }
        }
        .onReceive(ticker) { now = $0 }
    }

    // MARK: - Заголовок и переключатель подгруппы

    private func headerTitle(_ plan: DayPlan) -> String {
        "\(now.longRussian.capitalizedFirst) · \(plan.weekIndex)-я неделя"
    }

    private var subgroupMenu: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            if let schedule = store.schedule {
                let available = Planner.availableSubgroups(in: schedule)
                if available.count > 1 {
                    Menu {
                        Picker("Подгруппа", selection: Binding(
                            get: { store.subgroup ?? "" },
                            set: { store.subgroup = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Все подгруппы").tag("")
                            ForEach(available, id: \.self) { value in
                                Text("\(value)-я подгруппа").tag(value)
                            }
                        }
                    } label: {
                        Text(store.subgroup.map { "\($0)-я п/гр" } ?? "Все")
                    }
                }
            }
        }
    }

    // MARK: - Полоса дня

    /// Заменяет прежнюю карточку «следующая пара»: одна строка состояния
    /// и полоса, на которой видно и окна, и сколько дня осталось.
    private func summarySection(_ plan: DayPlan) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(statusTitle(plan))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    if let detail = statusDetail(plan) {
                        Text(detail)
                            .font(.footnote)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
                DayBar(lessons: plan.lessons, now: now)
            }
            .padding(.vertical, 4)
        } header: {
            Text(headerTitle(plan))
        }
    }

    private func statusTitle(_ plan: DayPlan) -> String {
        if let current = Planner.currentLesson(in: plan.lessons, at: now) {
            return "Идёт \(current.pair.lowercased())"
        }
        if let next = Planner.nextLesson(in: plan.lessons, at: now) {
            return "Следующая — \(next.name)"
        }
        return "Занятия на сегодня закончились"
    }

    private func statusDetail(_ plan: DayPlan) -> String? {
        let minutesNow = Planner.minutesSinceMidnight(now)
        if Planner.currentLesson(in: plan.lessons, at: now) != nil {
            guard let end = plan.lessons.compactMap(\.endMinutes).filter({ $0 > minutesNow }).min() else {
                return nil
            }
            return "осталось \(minutesText(end - minutesNow))"
        }
        if let next = Planner.nextLesson(in: plan.lessons, at: now) {
            return "через \(minutesText(max(0, (next.startMinutes ?? 0) - minutesNow)))"
        }
        return nil
    }

    private func minutesText(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) мин" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "\(h) ч" : "\(h) ч \(m) мин"
    }

    // MARK: - Занятия

    private func lessonsSection(_ plan: DayPlan) -> some View {
        let current = Planner.currentLesson(in: plan.lessons, at: now)
        let minutesNow = Planner.minutesSinceMidnight(now)

        return Section {
            ForEach(plan.lessons) { lesson in
                LessonRow(
                    lesson: lesson,
                    isNow: lesson.id == current?.id,
                    progress: lesson.id == current?.id ? Planner.progress(of: lesson, at: now) : 0,
                    isPast: (lesson.endMinutes ?? 0) <= minutesNow,
                    homework: homework.items(for: lesson, on: plan.date)
                )
            }
        } footer: {
            Text("Осталось занятий сегодня: \(remainingCount(plan))")
        }
    }

    /// Когда последняя пара отзвенела, сегодняшний список уже бесполезен —
    /// он сворачивается, а ниже показывается ближайший учебный день.
    private func finishedSection(_ plan: DayPlan) -> some View {
        Section {
            Button {
                withAnimation { showFinishedLessons.toggle() }
            } label: {
                HStack {
                    Label("Сегодня было пар: \(plan.lessons.count)", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Theme.success)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(showFinishedLessons ? 180 : 0))
                }
            }
            .accessibilityHint("Показать занятия, которые уже прошли")

            if showFinishedLessons {
                ForEach(plan.lessons) { lesson in
                    LessonRow(lesson: lesson,
                              isPast: true,
                              homework: homework.items(for: lesson, on: plan.date))
                }
            }
        }
    }

    // MARK: - Ближайший учебный день

    private var nextDaySection: some View {
        Group {
            if let schedule = store.schedule,
               let plan,
               plan.isEmpty || Planner.isDayFinished(plan.lessons, at: now),
               let nextDay = Planner.nextTeachingDay(from: now, schedule: schedule,
                                                     subgroup: store.subgroup) {
                Section {
                    ForEach(nextDay.lessons) { lesson in
                        CompactLessonRow(lesson: lesson,
                                         homework: homework.items(for: lesson, on: nextDay.date))
                    }
                } header: {
                    Text("\(nextDayTitle(nextDay)) · \(nextDay.weekIndex)-я неделя")
                }
            }
        }
    }

    /// «Завтра · Среда» либо «Понедельник, 7 сент.», если завтра выходной.
    private func nextDayTitle(_ day: DayPlan) -> String {
        Planner.calendar.isDateInTomorrow(day.date)
            ? "Завтра · \(day.dayName)"
            : "\(day.dayName), \(day.date.shortRussian)"
    }

    // MARK: - Изменения и подвал

    private var changesRow: some View {
        Button {
            selectedTab = .changes
        } label: {
            HStack {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Расписание изменилось")
                            .foregroundStyle(.primary)
                        Text(declension(store.unseenCount))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var footerSection: some View {
        Group {
            if let checked = store.lastCheckedAt {
                Section {
                    EmptyView()
                } footer: {
                    HStack(spacing: 6) {
                        if store.state.isLoading { ProgressView().controlSize(.mini) }
                        Text(store.state.isLoading
                             ? "Проверяем расписание…"
                             : "Сверено с сайтом \(checked.checkedAtDescription)")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
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

// MARK: - Вспомогательные строки списка

struct StatusRow: View {
    let text: String
    let icon: String
    let tint: Color

    var body: some View {
        Label {
            Text(text).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: icon).foregroundStyle(tint)
        }
    }
}

struct EmptyBlock: View {
    let icon: String
    let title: String
    var message: String? = nil

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.headline)
            if let message {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}

struct LoadingBlock: View {
    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
            Text("Загружаем расписание…")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }
}
