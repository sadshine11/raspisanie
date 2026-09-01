import Foundation

struct DayPlan {
    var date: Date
    var dayName: String
    var weekIndex: Int
    var lessons: [Lesson]

    var isEmpty: Bool { lessons.isEmpty }
}

enum Planner {

    /// Часовой пояс учебного заведения. Абакан живёт по красноярскому времени (UTC+7),
    /// и расписание привязано именно к нему, а не к настройкам телефона: иначе на
    /// устройстве с московским поясом «идёт сейчас» съедет на четыре часа.
    static let timeZone: TimeZone = TimeZone(identifier: "Asia/Krasnoyarsk")
        ?? TimeZone(secondsFromGMT: 7 * 3600)
        ?? .gmt

    /// Календарь с понедельником как началом недели — иначе чередование
    /// 1-й и 2-й недели съедет на воскресенье.
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.timeZone = Planner.timeZone
        return c
    }()

    /// Первое сентября указанного года.
    private static func septemberFirst(_ year: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: 9, day: 1)) ?? .distantPast
    }

    /// Понедельник недели, с которой начинается учебный год для этой даты.
    /// Первой считается неделя, в которую попало 1 сентября, — даже когда само
    /// 1-е число выпало на середину недели и неделя началась ещё в августе.
    static func academicYearStart(for date: Date) -> Date {
        let year = calendar.component(.year, from: date)
        let thisYear = startOfWeek(for: septemberFirst(year))
        return date >= thisYear ? thisYear : startOfWeek(for: septemberFirst(year - 1))
    }

    /// Какая учебная неделя (1 или 2) приходится на указанную дату.
    ///
    /// Отсчёт ведётся от календаря, а не от пометки «текущая» на сайте: та
    /// приходит из последнего ответа сервера и врёт на каникулах и на
    /// закешированном расписании, утаскивая за собой всю сетку.
    /// Неделя с 1 сентября — первая, дальше чередование идёт без сброса
    /// до конца учебного года; начало месяца счёт не обнуляет.
    static func weekIndex(for date: Date) -> Int {
        let days = calendar.dateComponents([.day],
                                           from: academicYearStart(for: date),
                                           to: startOfWeek(for: date)).day ?? 0
        let weeks = Int((Double(days) / 7.0).rounded())
        return ((weeks % 2) + 2) % 2 == 0 ? 1 : 2
    }

    static func startOfWeek(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// План на конкретный день с учётом выбранной подгруппы.
    static func plan(for date: Date, schedule: Schedule, subgroup: String?) -> DayPlan {
        let dayName = Weekday.name(for: date, calendar: calendar)
        let week = weekIndex(for: date)
        let lessons = schedule.day(named: dayName)?.week(week)?.lessons ?? []
        return DayPlan(date: date, dayName: dayName, weekIndex: week,
                       lessons: filter(lessons, subgroup: subgroup))
    }

    /// Занятия всей группы плюс занятия выбранной подгруппы.
    static func filter(_ lessons: [Lesson], subgroup: String?) -> [Lesson] {
        let kept = lessons.filter { lesson in
            guard let lessonSubgroup = lesson.subgroup, !lessonSubgroup.isEmpty else { return true }
            guard let subgroup, !subgroup.isEmpty else { return true }
            return lessonSubgroup == subgroup
        }
        return kept.sorted {
            $0.pairNumber == $1.pairNumber ? ($0.subgroup ?? "") < ($1.subgroup ?? "")
                                           : $0.pairNumber < $1.pairNumber
        }
    }

    /// Все подгруппы, которые встречаются в расписании группы.
    static func availableSubgroups(in schedule: Schedule) -> [String] {
        var found = Set<String>()
        for day in schedule.days {
            for week in day.weeks {
                for lesson in week.lessons {
                    if let s = lesson.subgroup, !s.isEmpty { found.insert(s) }
                }
            }
        }
        return found.sorted()
    }

    // MARK: - Что идёт сейчас

    static func minutesSinceMidnight(_ date: Date) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }

    /// Все занятия дня уже закончились по времени.
    /// Пустой день не считается закончившимся — там просто нечему кончаться.
    static func isDayFinished(_ lessons: [Lesson], at date: Date = Date()) -> Bool {
        guard !lessons.isEmpty else { return false }
        let now = minutesSinceMidnight(date)
        return lessons.allSatisfy { ($0.endMinutes ?? 0) <= now }
    }

    static func currentLesson(in lessons: [Lesson], at date: Date = Date()) -> Lesson? {
        let now = minutesSinceMidnight(date)
        return lessons.first { lesson in
            guard let start = lesson.startMinutes, let end = lesson.endMinutes else { return false }
            return now >= start && now < end
        }
    }

    static func nextLesson(in lessons: [Lesson], at date: Date = Date()) -> Lesson? {
        let now = minutesSinceMidnight(date)
        return lessons
            .filter { ($0.startMinutes ?? 0) > now }
            .min { ($0.startMinutes ?? 0) < ($1.startMinutes ?? 0) }
    }

    /// Доля пройденного времени пары, 0…1.
    static func progress(of lesson: Lesson, at date: Date = Date()) -> Double {
        guard let start = lesson.startMinutes, let end = lesson.endMinutes, end > start else { return 0 }
        let now = Double(minutesSinceMidnight(date))
        return min(max((now - Double(start)) / Double(end - start), 0), 1)
    }

    /// Ближайший учебный день начиная с указанной даты (максимум на две недели вперёд).
    static func nextTeachingDay(from date: Date, schedule: Schedule, subgroup: String?) -> DayPlan? {
        for offset in 1...14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let plan = plan(for: candidate, schedule: schedule, subgroup: subgroup)
            if !plan.isEmpty { return plan }
        }
        return nil
    }
}
