import SwiftUI

struct HomeworkView: View {
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
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if homework.items.isEmpty {
                        explainer
                        EmptyBlock(
                            icon: "text.badge.plus",
                            title: "Заданий нет",
                            message: "Запишите, что задали, — задание встанет на ближайшую пару по этому предмету и появится в её карточке на вкладке «Сегодня»."
                        )
                        addButton
                    } else {
                        ForEach(dueSections) { section in
                            sectionView(section)
                        }
                        doneSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .navigationTitle("Домашние задания")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        sheet = .new
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 17, weight: .semibold))
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
        var tint: Color
        var items: [Homework]
        /// Раздел собран не по одной дате — карточки показывают свою.
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
                subtitle: "Пара прошла. Перенесите задание долгим нажатием или отметьте выполненным.",
                tint: .red,
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
                tint: date == today ? Theme.homework : Theme.accent,
                items: sorted(upcoming.filter { $0.dueDate == date })
            ))
        }

        let undated = pending.filter { $0.dueDate == nil }
        if !undated.isEmpty {
            result.append(DueSection(
                id: "undated",
                title: "Без срока",
                subtitle: "Пар по предмету в ближайшие две недели не нашлось.",
                tint: Theme.textSecondary,
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

    private func sectionView(_ section: DueSection) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(section.tint).frame(width: 7, height: 7)
                Text(section.title)
                    .font(Theme.rounded(19, .bold))
                Spacer(minLength: 0)
                Text("\(section.items.count)")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.top, 6)

            if let subtitle = section.subtitle {
                Text(subtitle)
                    .font(Theme.rounded(12))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(section.items) { item in
                HomeworkCard(item: item, tint: section.tint, now: now,
                             showsDate: section.showsDate) {
                    sheet = .edit(item)
                }
            }
        }
    }

    private var doneSection: some View {
        Group {
            if !homework.done.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.22)) { showDone.toggle() }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Theme.color(forKind: "пр"))
                            Text("Выполнено")
                                .font(Theme.rounded(15, .semibold))
                                .foregroundColor(.primary)
                            Text("\(homework.done.count)")
                                .font(Theme.rounded(13, .medium))
                                .foregroundColor(Theme.textSecondary)
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .rotationEffect(.degrees(showDone ? 180 : 0))
                        }
                        .padding(Theme.cardPadding)
                        .card()
                    }
                    .buttonStyle(.plain)

                    if showDone {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(homework.done) { item in
                                HomeworkCard(item: item, tint: Theme.textSecondary, now: now) {
                                    sheet = .edit(item)
                                }
                            }
                            Button(role: .destructive) {
                                withAnimation { homework.deleteCompleted() }
                            } label: {
                                Text("Очистить выполненные")
                                    .font(Theme.rounded(14, .medium))
                            }
                            .padding(.top, 2)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.top, 6)
            }
        }
    }

    private var explainer: some View {
        HStack(spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundColor(Theme.homework)
            Text("Выберите предмет и напишите, что задали: приложение само найдёт ближайшую пару по этому предмету и поставит задание на неё.")
                .font(Theme.rounded(13))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private var addButton: some View {
        Button {
            sheet = .new
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                Text("Добавить задание")
            }
            .font(Theme.rounded(16, .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.homework, Theme.subgroup],
                                         startPoint: .leading, endPoint: .trailing))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Карточка задания

struct HomeworkCard: View {
    @EnvironmentObject private var store: ScheduleStore
    @EnvironmentObject private var homework: HomeworkStore

    let item: Homework
    var tint: Color = Theme.homework
    let now: Date
    /// Показывать дату пары. Нужно там, где раздел её не называет, —
    /// в «Просрочено» лежат задания за разные дни, и «2-я пара · 10:15»
    /// без даты читается как ссылка на пару, которая идёт прямо сейчас.
    var showsDate: Bool = false
    var onEdit: () -> Void

    private var pairLabel: String? {
        guard let pair = item.pair else { return nil }
        guard let start = item.startTime else { return pair }
        return "\(pair) · \(start)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { homework.toggle(item) }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(item.isDone ? Theme.color(forKind: "пр") : tint.opacity(0.75))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isDone ? "Снять отметку" : "Отметить выполненным")

            VStack(alignment: .leading, spacing: 6) {
                Text(item.subject)
                    .font(Theme.rounded(12, .bold))
                    .foregroundColor(item.isDone ? Theme.textSecondary : tint)
                    .fixedSize(horizontal: false, vertical: true)

                Text(item.text)
                    .font(Theme.rounded(16, .medium))
                    .foregroundColor(item.isDone ? Theme.textSecondary : .primary)
                    .strikethrough(item.isDone, color: Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 6) {
                    if showsDate, let due = item.dueDate {
                        Pill(text: due.shortWeekdayAndShortRussian, icon: "calendar",
                             color: item.isDone ? Theme.textSecondary : tint, size: 11)
                    }
                    if let pairLabel {
                        Pill(text: pairLabel, icon: "clock",
                             color: item.isDone ? Theme.textSecondary : tint, size: 11)
                    }
                    if let room = item.room, !room.isEmpty {
                        Pill(text: room, icon: "mappin.and.ellipse",
                             color: Theme.textSecondary, size: 11)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .card(tint: item.isDone ? .clear : tint)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
        .contextMenu {
            Button { onEdit() } label: { Label("Изменить", systemImage: "pencil") }
            Button {
                homework.moveToNextLesson(item, schedule: store.schedule,
                                          subgroup: store.subgroup, now: now)
            } label: {
                Label("Перенести на следующую пару", systemImage: "arrow.uturn.right")
            }
            Button(role: .destructive) {
                homework.delete(item)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
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

    /// Управляющий символ, которого не бывает в названии предмета, — метка
    /// пункта «Другой предмет…» в том же `Picker`, что и предметы из сетки.
    private static let customTag = "\u{1}"

    private var subjects: [String] {
        guard let schedule = store.schedule else { return [] }
        return Planner.subjects(in: schedule, subgroup: store.subgroup)
    }

    private var isCustom: Bool { subjects.isEmpty || subject == Self.customTag }

    private var resolvedSubject: String {
        isCustom ? customSubject.trimmed : subject
    }

    private var target: (date: Date, lesson: Lesson)? {
        guard let schedule = store.schedule, !resolvedSubject.isEmpty else { return nil }
        return Planner.nextLesson(ofSubject: resolvedSubject, from: Date(),
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
            .scrollContentBackground(.hidden)
            .screenBackground()
            .navigationTitle(editing == nil ? "Новое задание" : "Задание")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Готово", action: save)
                        .font(Theme.rounded(16, .semibold))
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: prefill)
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
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(Theme.homework)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(dayTitle(target.date))
                            .font(Theme.rounded(16, .semibold))
                        Text("\(target.lesson.pair) · \(target.lesson.time)")
                            .font(Theme.rounded(13))
                            .foregroundColor(Theme.textSecondary)
                        if let room = target.lesson.room, !room.isEmpty {
                            Text(room)
                                .font(Theme.rounded(13))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(.vertical, 2)
            } else if resolvedSubject.isEmpty {
                Text("Выберите предмет").foregroundColor(Theme.textSecondary)
            } else {
                Text("Пар по этому предмету в ближайшие две недели нет — задание сохранится без срока.")
                    .foregroundColor(Theme.textSecondary)
            }
        } header: {
            Text("Встанет на пару")
        }
    }

    private func dayTitle(_ date: Date) -> String {
        if Planner.calendar.isDateInToday(date) { return "Сегодня" }
        if Planner.calendar.isDateInTomorrow(date) { return "Завтра" }
        return date.weekdayAndShortRussian.capitalizedFirst
    }

    private func prefill() {
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
                            schedule: store.schedule, subgroup: store.subgroup)
        } else {
            homework.add(subject: resolvedSubject, text: text,
                         schedule: store.schedule, subgroup: store.subgroup)
        }
        dismiss()
    }
}
