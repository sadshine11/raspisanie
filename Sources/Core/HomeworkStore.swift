import Foundation

@MainActor
final class HomeworkStore: ObservableObject {

    @Published private(set) var items: [Homework] = []

    private let storage: Storage

    init(storage: Storage = .shared) {
        self.storage = storage
        items = storage.load([Homework].self, from: Storage.homeworkKey) ?? []
    }

    // MARK: - Срезы

    var pending: [Homework] { items.filter { !$0.isDone } }
    var done: [Homework] { items.filter(\.isDone).sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) } }
    var pendingCount: Int { pending.count }

    /// Задания к конкретному занятию в конкретный день.
    ///
    /// Пара сверяется, только если она известна и у занятия совпадает: иначе
    /// два занятия одного предмета в один день получили бы одно и то же ДЗ.
    func items(for lesson: Lesson, on date: Date) -> [Homework] {
        let day = Planner.calendar.startOfDay(for: date)
        let needle = Planner.normalizedSubject(lesson.name)
        return items.filter { item in
            !item.isDone
                && item.dueDate == day
                && Planner.normalizedSubject(item.subject) == needle
                && (item.pair == nil || item.pair == lesson.pair)
        }
    }

    // MARK: - Изменения

    func add(subject: String, text: String, schedule: Schedule?, subgroup: String?, now: Date = Date()) {
        let item = Homework.make(subject: subject, text: text,
                                 schedule: schedule, subgroup: subgroup, now: now)
        guard !item.subject.isEmpty, !item.text.isEmpty else { return }
        items.append(item)
        persist()
    }

    /// Меняет предмет и текст. Срок пересчитывается только при смене предмета:
    /// иначе правка опечатки в тексте молча перебрасывала бы задание на
    /// следующую неделю, если пара уже прошла.
    func update(_ item: Homework, subject: String, text: String,
                schedule: Schedule?, subgroup: String?, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let subjectChanged = Planner.normalizedSubject(subject) != Planner.normalizedSubject(item.subject)
        items[index].subject = subject.trimmed
        items[index].text = text.trimmed
        if subjectChanged {
            items[index].detachFromLesson()
            items[index].attachToNearestLesson(schedule: schedule, subgroup: subgroup, now: now)
        }
        persist()
    }

    func toggle(_ item: Homework) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        items[index].doneAt = items[index].isDone ? Date() : nil
        persist()
    }

    func delete(_ item: Homework) {
        items.removeAll { $0.id == item.id }
        persist()
    }

    func deleteCompleted() {
        items.removeAll(where: \.isDone)
        persist()
    }

    /// Переносит задание на следующую пару по тому же предмету.
    /// Нужно просроченным: пара прошла, задание не сдано — пусть висит
    /// на ближайшей следующей, а не в «просрочено» до конца семестра.
    func moveToNextLesson(_ item: Homework, schedule: Schedule?, subgroup: String?, now: Date = Date()) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        if !items[index].attachToNearestLesson(schedule: schedule, subgroup: subgroup, now: now) {
            // Молча оставить старый срок нельзя: пользователь нажал «перенести»
            // и должен увидеть результат. Задание уходит в «Без срока».
            items[index].detachFromLesson()
        }
        persist()
    }

    /// Проставляет срок записям, которые его не получили: задание могли
    /// добавить до того, как расписание догрузилось.
    func fillMissingDueDates(schedule: Schedule, subgroup: String?, now: Date = Date()) {
        var changed = false
        for index in items.indices where items[index].dueDate == nil && !items[index].isDone {
            items[index].attachToNearestLesson(schedule: schedule, subgroup: subgroup, now: now)
            if items[index].dueDate != nil { changed = true }
        }
        if changed { persist() }
    }

    private func persist() {
        storage.save(items, to: Storage.homeworkKey)
    }
}
