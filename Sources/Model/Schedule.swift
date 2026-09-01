import Foundation

/// Одно занятие в сетке расписания.
struct Lesson: Codable, Hashable, Identifiable {
    var pair: String            // «1-я пара»
    var time: String            // «08:30-10:05»
    var subgroup: String?       // «1» / «2» / nil, если на всю группу
    var room: String?           // «А229», «Спортивный зал №2»
    var kind: String?           // Лек / Пр / Лаб
    var name: String            // название предмета
    var teacher: String?
    var teacherId: String?
    var courseURL: String?      // ссылка на курс в Moodle СФУ, если задана

    /// Ключ позиции в сетке. Не включает содержание занятия —
    /// именно поэтому по нему ловится замена предмета в том же слоте.
    var slotKey: String { "\(pair)|\(subgroup ?? "-")" }

    var id: String { "\(slotKey)|\(name)" }

    /// Содержательная часть — то, что сравнивается при поиске изменений.
    var payload: String { "\(name)|\(kind ?? "")|\(room ?? "")|\(teacher ?? "")" }

    var pairNumber: Int {
        Int(pair.prefix(while: \.isNumber)) ?? 0
    }

    var startMinutes: Int? { Lesson.minutes(from: time, endIndex: 0) }
    var endMinutes: Int? { Lesson.minutes(from: time, endIndex: 1) }

    private static func minutes(from time: String, endIndex: Int) -> Int? {
        let halves = time.split(separator: "-")
        guard halves.count == 2 else { return nil }
        let parts = halves[endIndex].split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return h * 60 + m
    }
}

/// Блок «1-я неделя» / «2-я неделя» внутри одного дня.
struct WeekBlock: Codable, Hashable {
    var label: String           // «1-я неделя (текущая)»
    var isCurrent: Bool         // сервер пометил её как текущую
    var lessons: [Lesson]

    var index: Int { Int(label.prefix(while: \.isNumber)) ?? 1 }
}

struct DaySchedule: Codable, Hashable {
    var name: String            // «Понедельник»
    var weeks: [WeekBlock]

    func week(_ index: Int) -> WeekBlock? { weeks.first { $0.index == index } }
}

struct Schedule: Codable, Hashable {
    var groupTitle: String
    var semester: String
    var days: [DaySchedule]
    var scheduleId: Int
    var groupId: Int
    var fetchedAt: Date

    /// Номер недели, которую сервер считает текущей (1 или 2).
    var currentWeekIndex: Int {
        for day in days {
            if let w = day.weeks.first(where: { $0.isCurrent }) { return w.index }
        }
        return 1
    }

    var lessonCount: Int {
        days.reduce(0) { $0 + $1.weeks.reduce(0) { $0 + $1.lessons.count } }
    }

    func day(named name: String) -> DaySchedule? { days.first { $0.name == name } }
}

enum Weekday {
    static let names = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    static let short = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    /// Индекс 0…6 (понедельник = 0) для даты.
    static func index(for date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    static func name(for date: Date, calendar: Calendar = .current) -> String {
        names[index(for: date, calendar: calendar)]
    }
}
