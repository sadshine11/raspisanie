import Foundation

struct DayPlan {
    var date: Date
    var dayName: String
    var weekIndex: Int
    var lessons: [Lesson]

    var isEmpty: Bool { lessons.isEmpty }
}

enum Planner {

    /// Календарь с понедельником как началом недели — иначе чередование
    /// 1-й и 2-й недели съедет на воскресенье.
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        return c
    }()

    /// Какая учебная неделя (1 или 2) приходится на указанную дату.
    /// Точка отсчёта — неделя, которую сервер пометил как текущую.
    static func weekIndex(for date: Date, schedule: Schedule, now: Date = Date()) -> Int {
        let base = schedule.currentWeekIndex
        let startOfNow = startOfWeek(for: now)
        let startOfTarget = startOfWeek(for: date)
        let days = calendar.dateComponents([.day], from: startOfNow, to: startOfTarget).day ?? 0
        let weeks = Int((Double(days) / 7.0).rounded())
        let shifted = (base - 1 + weeks) % 2
        return (shifted + 2) % 2 + 1
    }

    static func startOfWeek(for date: Date) -> Date {
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? calendar.startOfDay(for: date)
    }

    /// План на конкретный день с учётом выбранной подгруппы.
    static func plan(for date: Date, schedule: Schedule, subgroup: String?, now: Date = Date()) -> DayPlan {
        let dayName = Weekday.name(for: date, calendar: calendar)
        let week = weekIndex(for: date, schedule: schedule, now: now)
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
    static func nextTeachingDay(from date: Date, schedule: Schedule, subgroup: String?, now: Date = Date()) -> DayPlan? {
        for offset in 1...14 {
            guard let candidate = calendar.date(byAdding: .day, value: offset, to: date) else { continue }
            let plan = plan(for: candidate, schedule: schedule, subgroup: subgroup, now: now)
            if !plan.isEmpty { return plan }
        }
        return nil
    }
}
