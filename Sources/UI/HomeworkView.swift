import SwiftUI

struct HomeworkView: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var homework: HomeworkStore

    @State private var now = Date()
    @State private var sheet: Sheet?
    @State private var showDone = false
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    private enum Sheet: Identifiable {
        case new
        case edit(Homework)

        var id: String {
            switch self {
            case .new:            return "new"
            case .edit(let item): return item.id.uuidString
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if homework.items.isEmpty {
                    Section {
                        EmptyBlock(icon: "text.badge.plus", title: "Заданий нет")
                        Button {
                            sheet = .new
                        } label: {
                            Label("Добавить задание", systemImage: "plus")
                        }
                    } footer: {
                        Text("Выберите предмет и напишите, что задали: приложение само найдёт ближайшую пару по этому предмету и поставит задание на неё.")
                    }
                } else {
                    ForEach(dueSections) { section in
                        dueSectionView(section)
                    }
                    doneSection
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Задания")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sheet = .new
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Добавить задание")
                }
            }
            .sheet(item: $sheet) { which in
                switch which {
                case .new:            HomeworkEditor(editing: nil)
                case .edit(let item): HomeworkEditor(editing: item)
                }
            }
        }
        .onReceive(ticker) { now = $0 }
        .onAppear { now = Date() }
    }

    // MARK: - Разбивка по срокам

    private struct DueSection: Identifiable {
        var id: String
        var title: String
        var subtitle: String?
        var items: [Homework]
        /// Раздел собран не по одной дате — строки показывают свою.
        var showsDate: Bool = false
    }

    private var dueSections: [DueSection] {
        let today = Planner.calendar.startOfDay(for: now)
        let pending = homework.pending
        var result: [DueSection] = []

        let overdue = pending.filter { $0.isOverdue(at: now) }
        if !overdue.isEmpty {
            result.append(DueSection(
                id: "overdue",
                title: "Просрочено",
                subtitle: "Смахните задание вправо, чтобы перенести его на следующую пару по этому предмету.",
                items: sorted(overdue),
                showsDate: true
            ))
        }

        let upcoming = pending.filter { ($0.dueDate ?? .distantPast) >= today }
        for date in Set(upcoming.compactMap(\.dueDate)).sorted() {
            result.append(DueSection(
                id: "day-\(date.timeIntervalSince1970)",
                title: title(for: date),
                subtitle: nil,
                items: sorted(upcoming.filter { $0.dueDate == date })
            ))
        }

        let undated = pending.filter { $0.dueDate == nil }
        if !undated.isEmpty {
            result.append(DueSection(
                id: "undated",
                title: "Без срока",
                subtitle: "Пар по предмету в ближайшие две недели не нашлось.",
                items: sorted(undated)
            ))
        }
        return result
    }

    private func sorted(_ items: [Homework]) -> [Homework] {
        items.sorted {
            $0.pairNumber == $1.pairNumber ? $0.createdAt < $1.createdAt
                                           : $0.pairNumber < $1.pairNumber
        }
    }

    /// «Сегодня» / «Завтра» / «Вторник, 15 сент.»
    private func title(for date: Date) -> String {
        if Planner.calendar.isDate(date, inSameDayAs: now) { return "Сегодня" }
        if Planner.calendar.isDateInTomorrow(date) { return "Завтра" }
        return date.weekdayAndShortRussian.capitalizedFirst
    }

    // MARK: - Секции

    private func dueSectionView(_ section: DueSection) -> some View {
        Section {
            ForEach(section.items) { item in
                row(item, showsDate: section.showsDate)
            }
        } header: {
            HStack {
                Text(section.title)
                Spacer()
                Text("\(section.items.count)")
            }
        } footer: {
            if let subtitle = section.subtitle {
                Text(subtitle)
            }
        }
    }

    private func row(_ item: Homework, showsDate: Bool) -> some View {
        HomeworkRow(item: item, showsDate: showsDate, now: now)
            .contentShape(Rectangle())
            .onTapGesture { sheet = .edit(item) }
            .swipeActions(edge: .trailing) {
                Button(role: .destructive) {
                    homework.delete(item)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
            .swipeActions(edge: .leading) {
                Button {
                    homework.moveToNextLesson(item, schedule: store.schedule,
                                              subgroup: store.subgroup, now: now)
                } label: {
                    Label("Перенести", systemImage: "arrow.uturn.right")
                }
                .tint(Theme.tint)
            }
    }

    private var doneSection: some View {
        let done = homework.done
        return Group {
            if !done.isEmpty {
                Section {
                    Button {
                        withAnimation { showDone.toggle() }
                    } label: {
                        HStack {
                            Text("Выполненные")
                                .foregroundStyle(.primary)
                            Spacer()
                            Text("\(done.count)")
                                .foregroundStyle(.secondary)
                            Image(systemName: "chevron.down")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(showDone ? 180 : 0))
                        }
                    }

                    if showDone {
                        ForEach(done) { item in
                            row(item, showsDate: false)
                        }
                        Button(role: .destructive) {
                            withAnimation { homework.deleteCompleted() }
                        } label: {
                            Text("Очистить выполненные")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Строка задания

/// Строка как в Напоминаниях: кружок отметки слева, задание, под ним предмет
/// и пара. Цвет предмета — тот же, что у вида занятия в расписании.
struct HomeworkRow: View {
    @EnvironmentObject private var homework: HomeworkStore

    let item: Homework
    /// Показывать дату пары. Нужно там, где раздел её не называет, —
    /// в «Просрочено» лежат задания за разные дни.
    var showsDate: Bool
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation { homework.toggle(item) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(item.isDone ? Theme.tint : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Снять отметку" : "Отметить выполненным")

            VStack(alignment: .leading, spacing: 2) {
                Text(item.subject)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(item.isDone ? Color.secondary : Theme.color(forKind: item.kind))

                Text(item.text)
                    .font(.body)
                    .foregroundStyle(item.isDone ? .secondary : .primary)
                    .strikethrough(item.isDone)
                    .fixedSize(horizontal: false, vertical: true)

                if let meta {
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(isOverdue ? Theme.overdue : Color.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var isOverdue: Bool { item.isOverdue(at: now) }

    /// «Пн, 7 сент. · 2-я пара, 10:15 · А108»
    private var meta: String? {
        var parts: [String] = []
        if showsDate, let due = item.dueDate {
            parts.append(due.shortWeekdayAndShortRussian.capitalizedFirst)
        }
        if let pair = item.pair {
            parts.append([pair, item.startTime].compactMap { $0 }.joined(separator: ", "))
        }
        if let room = item.room, !room.isEmpty { parts.append(room) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

// MARK: - Ввод задания

struct HomeworkEditor: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var homework: HomeworkStore
    @Environment(\.dismiss) private var dismiss

    /// `nil` — создаётся новая запись.
    let editing: Homework?

    @State private var subject = ""
    @State private var customSubject = ""
    @State private var text = ""

    /// Список предметов и момент отсчёта снимаются один раз при открытии.
    /// Пересчитывать их в теле нельзя: `Planner.subjects` обходит всю сетку
    /// расписания, а тело перерисовывается на каждое нажатие клавиши. К тому же
    /// показанная здесь пара должна совпасть с той, которую выберет `save()`, —
    /// а не разойтись с ней, если пара началась, пока набирали текст.
    @State private var subjects: [String] = []
    @State private var now = Date()

    /// Управляющий символ, которого не бывает в названии предмета, — метка
    /// пункта «Другой предмет…» в том же `Picker`, что и предметы из сетки.
    private static let customTag = "\u{1}"

    private var isCustom: Bool { subjects.isEmpty || subject == Self.customTag }

    private var resolvedSubject: String {
        isCustom ? customSubject.trimmed : subject
    }

    private var target: (date: Date, lesson: Lesson)? {
        guard let schedule = store.schedule, !resolvedSubject.isEmpty else { return nil }
        return Planner.nextLesson(ofSubject: resolvedSubject, from: now,
                                  schedule: schedule, subgroup: store.subgroup)
    }

    private var canSave: Bool { !resolvedSubject.isEmpty && !text.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                subjectSection
                taskSection
                targetSection
            }
            .navigationTitle(editing == nil ? "Новое задание" : "Задание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", action: save).disabled(!canSave)
                }
            }
            .onAppear(perform: prepare)
        }
    }

    private var subjectSection: some View {
        Section {
            if subjects.isEmpty {
                TextField("Название предмета", text: $customSubject)
            } else {
                Picker("Предмет", selection: $subject) {
                    Text("Не выбран").tag("")
                    ForEach(subjects, id: \.self) { name in
                        Text(name).tag(name)
                    }
                    Text("Другой предмет…").tag(Self.customTag)
                }
                .pickerStyle(.navigationLink)

                if subject == Self.customTag {
                    TextField("Название предмета", text: $customSubject)
                }
            }
        } header: {
            Text("Предмет")
        } footer: {
            if subjects.isEmpty {
                Text("Расписание ещё не загрузилось — впишите название вручную. Срок проставится, как только расписание появится.")
            }
        }
    }

    private var taskSection: some View {
        Section("Что задали") {
            TextField("Например: §14, задачи 3–7", text: $text, axis: .vertical)
                .lineLimit(3...8)
        }
    }

    private var targetSection: some View {
        Section {
            if let target {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(dayTitle(target.date))
                        Text("\(target.lesson.pair), \(target.lesson.time)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let room = target.lesson.room, !room.isEmpty {
                            Text(room)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(Theme.tint)
                }
            } else if resolvedSubject.isEmpty {
                Text("Выберите предмет").foregroundStyle(.secondary)
            } else {
                Text("Пар по этому предмету в ближайшие две недели нет — задание сохранится без срока.")
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Встанет на пару")
        } footer: {
            Text("Ближайшая пара по этому предмету. Сегодняшние пары считаются, только пока не начались.")
        }
    }

    private func dayTitle(_ date: Date) -> String {
        if Planner.calendar.isDateInToday(date) { return "Сегодня" }
        if Planner.calendar.isDateInTomorrow(date) { return "Завтра" }
        return date.weekdayAndShortRussian.capitalizedFirst
    }

    private func prepare() {
        now = Date()
        subjects = store.schedule.map { Planner.subjects(in: $0, subgroup: store.subgroup) } ?? []
        guard let editing, subject.isEmpty, customSubject.isEmpty, text.isEmpty else { return }
        text = editing.text
        let needle = Planner.normalizedSubject(editing.subject)
        if let known = subjects.first(where: { Planner.normalizedSubject($0) == needle }) {
            subject = known
        } else {
            subject = Self.customTag
            customSubject = editing.subject
        }
    }

    private func save() {
        guard canSave else { return }
        if let editing {
            homework.update(editing, subject: resolvedSubject, text: text,
                            schedule: store.schedule, subgroup: store.subgroup, now: now)
        } else {
            homework.add(subject: resolvedSubject, text: text,
                         schedule: store.schedule, subgroup: store.subgroup, now: now)
        }
        dismiss()
    }
}
