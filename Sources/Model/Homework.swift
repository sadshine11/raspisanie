import Foundation

/// Домашнее задание по предмету.
///
/// Срок хранится датой, а не ссылкой на занятие: сетка расписания
/// повторяется через две недели, и «та самая пара» после перезагрузки
/// расписания перестала бы находиться. Дата же остаётся верной — и
/// позволяет показать просроченное задание, а не молча перенести его
/// на следующую пару по тому же предмету.
struct Homework: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var subject: String
    var text: String
    var createdAt: Date = Date()

    /// Начало дня ближайшей пары по предмету на момент записи.
    /// `nil` — расписание ещё не загрузилось либо пар по предмету нет.
    var dueDate: Date?
    var pair: String?           // «3-я пара»
    var time: String?           // «13:00-14:35»
    var room: String?
    /// Вид занятия — чтобы список заданий красил предмет тем же цветом,
    /// что и сетка расписания.
    var kind: String?

    var isDone: Bool = false
    var doneAt: Date?

    /// Номер пары для сортировки внутри одного дня.
    var pairNumber: Int {
        Int((pair ?? "").prefix(while: \.isNumber)) ?? 0
    }

    /// «13:00» — начало пары, если срок известен.
    var startTime: String? {
        guard let time else { return nil }
        return time.split(separator: "-").first.map(String.init)
    }

    /// Срок прошёл, а задание не отмечено выполненным.
    func isOverdue(at date: Date) -> Bool {
        guard !isDone, let dueDate else { return false }
        return dueDate < Planner.calendar.startOfDay(for: date)
    }

    /// Собирает запись, привязав её к ближайшей паре по предмету.
    ///
    /// Расписания может не быть (первый запуск без сети) — тогда задание
    /// сохраняется без срока, а `HomeworkStore.fillMissingDueDates`
    /// проставит его, как только расписание загрузится.
    static func make(subject: String,
                     text: String,
                     schedule: Schedule?,
                     subgroup: String?,
                     now: Date = Date()) -> Homework {
        var item = Homework(subject: subject.trimmed, text: text.trimmed, createdAt: now)
        item.attachToNearestLesson(schedule: schedule, subgroup: subgroup, now: now)
        return item
    }

    /// Проставляет срок по ближайшей паре этого предмета.
    /// Возвращает , если пары не нашлось, — вызывающий решает,
    /// оставить прежний срок или сбросить его.
    @discardableResult
    mutating func attachToNearestLesson(schedule: Schedule?, subgroup: String?, now: Date = Date()) -> Bool {
        guard let schedule,
              let target = Planner.nextLesson(ofSubject: subject, from: now,
                                              schedule: schedule, subgroup: subgroup) else { return false }
        dueDate = target.date
        pair = target.lesson.pair
        time = target.lesson.time
        room = target.lesson.room
        kind = target.lesson.kind
        // Название берётся из расписания: пользователь мог ввести его руками
        // с другим регистром, а по нему потом ищется занятие в сетке дня.
        subject = target.lesson.name
        return true
    }

    /// Забыть срок: пары по предмету больше нет в сетке.
    mutating func detachFromLesson() {
        dueDate = nil
        pair = nil
        time = nil
        room = nil
        kind = nil
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
