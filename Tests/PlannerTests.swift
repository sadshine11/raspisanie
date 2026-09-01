import XCTest
@testable import Raspisanie

final class PlannerTests: XCTestCase {

    private var calendar: Calendar { Planner.calendar }

    /// 1 сентября 2026 года — вторник.
    private func date(day: Int, month: Int = 9, year: Int = 2026,
                      hour: Int = 0, minute: Int = 0) throws -> Date {
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return try XCTUnwrap(calendar.date(from: comps))
    }

    private func lesson(_ pair: Int, _ time: String, subgroup: String? = nil, name: String = "Предмет") -> Lesson {
        Lesson(pair: "\(pair)-я пара", time: time, subgroup: subgroup,
               room: "А100", kind: "Лек", name: name,
               teacher: "Иванов И.И.", teacherId: "1", courseURL: nil)
    }

    private func schedule(currentWeek: Int = 1,
                          tuesdayWeek1: [Lesson] = [],
                          tuesdayWeek2: [Lesson] = []) -> Schedule {
        Schedule(groupTitle: "56-1", semester: "Осень",
                 days: [DaySchedule(name: "Вторник", weeks: [
                     WeekBlock(label: "1-я неделя\(currentWeek == 1 ? " (текущая)" : "")",
                               isCurrent: currentWeek == 1, lessons: tuesdayWeek1),
                     WeekBlock(label: "2-я неделя\(currentWeek == 2 ? " (текущая)" : "")",
                               isCurrent: currentWeek == 2, lessons: tuesdayWeek2),
                 ])],
                 scheduleId: 116, groupId: 3281, fetchedAt: Date())
    }

    // MARK: - Часовой пояс

    /// Расписание считается по времени Абакана, а не по настройкам телефона.
    func testCalendarIsPinnedToKrasnoyarskTime() {
        XCTAssertEqual(Planner.timeZone.secondsFromGMT(), 7 * 3600)
        XCTAssertEqual(Planner.calendar.timeZone, Planner.timeZone)
        XCTAssertEqual(Planner.calendar.firstWeekday, 2)
    }

    /// Один и тот же момент попадает в нужную пару независимо от того,
    /// какой пояс выставлен в системе: 05:30 UTC — это 12:30 в Красноярске,
    /// то есть середина третьей пары.
    func testCurrentLessonIgnoresSystemTimeZone() throws {
        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = try XCTUnwrap(TimeZone(identifier: "UTC"))
        let moment = try XCTUnwrap(
            utcCalendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 5, minute: 30))
        )

        let lessons = [lesson(3, "12:00-13:35")]
        XCTAssertEqual(Planner.minutesSinceMidnight(moment), 12 * 60 + 30)
        XCTAssertEqual(Planner.currentLesson(in: lessons, at: moment)?.pairNumber, 3)
    }

    // MARK: - Дни недели

    func testWeekdayNameMatchesRealCalendar() throws {
        XCTAssertEqual(Weekday.name(for: try date(day: 1), calendar: calendar), "Вторник")
        XCTAssertEqual(Weekday.name(for: try date(day: 7), calendar: calendar), "Понедельник")
        XCTAssertEqual(Weekday.name(for: try date(day: 6), calendar: calendar), "Воскресенье")
    }

    // MARK: - Чередование недель

    func testWeekAlternatesEverySevenDays() throws {
        let today = try date(day: 1)              // вторник, 1-я неделя
        let s = schedule(currentWeek: 1)

        XCTAssertEqual(Planner.weekIndex(for: today, schedule: s, now: today), 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 8), schedule: s, now: today), 2)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 15), schedule: s, now: today), 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 22), schedule: s, now: today), 2)
    }

    func testWeekAlternatesBackwards() throws {
        let today = try date(day: 15)
        let s = schedule(currentWeek: 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 8), schedule: s, now: today), 2)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 1), schedule: s, now: today), 1)
    }

    func testWeekRespectsServerCurrentWeek() throws {
        let today = try date(day: 1)
        let s = schedule(currentWeek: 2)
        XCTAssertEqual(Planner.weekIndex(for: today, schedule: s, now: today), 2)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 8), schedule: s, now: today), 1)
    }

    /// Дни одной календарной недели должны попадать в одну учебную неделю,
    /// включая воскресенье — ради этого календарь начинается с понедельника.
    func testDaysOfSameWeekShareWeekIndex() throws {
        let monday = try date(day: 7)
        let s = schedule(currentWeek: 1)
        for offset in 0...6 {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: monday))
            XCTAssertEqual(Planner.weekIndex(for: day, schedule: s, now: monday), 1,
                           "сдвиг \(offset) дней от понедельника попал в другую неделю")
        }
    }

    // MARK: - План дня

    func testPlanPicksLessonsOfCorrectWeek() throws {
        let today = try date(day: 1)
        let s = schedule(currentWeek: 1,
                         tuesdayWeek1: [lesson(1, "08:30-10:05", name: "Первая неделя")],
                         tuesdayWeek2: [lesson(1, "08:30-10:05", name: "Вторая неделя")])

        let now = Planner.plan(for: today, schedule: s, subgroup: nil, now: today)
        XCTAssertEqual(now.dayName, "Вторник")
        XCTAssertEqual(now.weekIndex, 1)
        XCTAssertEqual(now.lessons.first?.name, "Первая неделя")

        let later = Planner.plan(for: try date(day: 8), schedule: s, subgroup: nil, now: today)
        XCTAssertEqual(later.weekIndex, 2)
        XCTAssertEqual(later.lessons.first?.name, "Вторая неделя")
    }

    func testPlanIsEmptyForDayWithoutLessons() throws {
        let today = try date(day: 1)
        let plan = Planner.plan(for: try date(day: 5), schedule: schedule(), subgroup: nil, now: today)
        XCTAssertTrue(plan.isEmpty)
    }

    // MARK: - Подгруппы

    func testSubgroupFilterKeepsWholeGroupLessons() {
        let lessons = [
            lesson(1, "08:30-10:05", subgroup: nil, name: "Лекция всем"),
            lesson(2, "10:15-11:50", subgroup: "1", name: "Лаба первой"),
            lesson(2, "10:15-11:50", subgroup: "2", name: "Лаба второй"),
        ]
        let filtered = Planner.filter(lessons, subgroup: "1")
        XCTAssertEqual(filtered.map(\.name), ["Лекция всем", "Лаба первой"])
    }

    func testNoSubgroupSelectedShowsEverything() {
        let lessons = [
            lesson(2, "10:15-11:50", subgroup: "1"),
            lesson(2, "10:15-11:50", subgroup: "2"),
        ]
        XCTAssertEqual(Planner.filter(lessons, subgroup: nil).count, 2)
    }

    func testFilterSortsByPairNumber() {
        let lessons = [lesson(5, "15:55-17:30"), lesson(1, "08:30-10:05"), lesson(3, "12:00-13:35")]
        XCTAssertEqual(Planner.filter(lessons, subgroup: nil).map(\.pairNumber), [1, 3, 5])
    }

    func testAvailableSubgroups() {
        let s = schedule(tuesdayWeek1: [lesson(1, "08:30-10:05", subgroup: "2")],
                         tuesdayWeek2: [lesson(1, "08:30-10:05", subgroup: "1"),
                                        lesson(2, "10:15-11:50", subgroup: nil)])
        XCTAssertEqual(Planner.availableSubgroups(in: s), ["1", "2"])
    }

    // MARK: - Текущая и следующая пара

    func testCurrentLessonDetection() throws {
        let lessons = [lesson(1, "08:30-10:05"), lesson(2, "10:15-11:50")]

        XCTAssertNil(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 8, minute: 0)))
        XCTAssertEqual(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 9, minute: 0))?.pairNumber, 1)
        XCTAssertNil(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 10, minute: 10)))
        XCTAssertEqual(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 11, minute: 49))?.pairNumber, 2)
        XCTAssertNil(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 23, minute: 0)))
    }

    /// Момент окончания пары уже не считается «идёт сейчас».
    func testLessonEndIsExclusive() throws {
        let lessons = [lesson(1, "08:30-10:05")]
        XCTAssertNil(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 10, minute: 5)))
        XCTAssertNotNil(Planner.currentLesson(in: lessons, at: try date(day: 1, hour: 10, minute: 4)))
    }

    func testNextLessonDetection() throws {
        let lessons = [lesson(1, "08:30-10:05"), lesson(2, "10:15-11:50")]
        XCTAssertEqual(Planner.nextLesson(in: lessons, at: try date(day: 1, hour: 7))?.pairNumber, 1)
        XCTAssertEqual(Planner.nextLesson(in: lessons, at: try date(day: 1, hour: 9))?.pairNumber, 2)
        XCTAssertNil(Planner.nextLesson(in: lessons, at: try date(day: 1, hour: 20)))
    }

    func testProgressWithinLesson() throws {
        let l = lesson(1, "08:30-10:05")   // 95 минут
        XCTAssertEqual(Planner.progress(of: l, at: try date(day: 1, hour: 8, minute: 30)), 0, accuracy: 0.001)
        XCTAssertEqual(Planner.progress(of: l, at: try date(day: 1, hour: 10, minute: 5)), 1, accuracy: 0.001)
        XCTAssertEqual(Planner.progress(of: l, at: try date(day: 1, hour: 9, minute: 0)), 30.0 / 95.0, accuracy: 0.001)
        XCTAssertEqual(Planner.progress(of: l, at: try date(day: 1, hour: 6)), 0, accuracy: 0.001)
    }

    // MARK: - Ближайший учебный день

    func testNextTeachingDaySkipsEmptyDays() throws {
        let today = try date(day: 1)  // вторник
        let s = schedule(currentWeek: 1,
                         tuesdayWeek1: [lesson(1, "08:30-10:05")],
                         tuesdayWeek2: [lesson(1, "08:30-10:05")])
        // Следующий день с занятиями — вторник через неделю.
        let next = try XCTUnwrap(Planner.nextTeachingDay(from: today, schedule: s, subgroup: nil, now: today))
        XCTAssertEqual(next.dayName, "Вторник")
        XCTAssertEqual(next.weekIndex, 2)
    }

    func testNextTeachingDayReturnsNilWhenScheduleEmpty() throws {
        let today = try date(day: 1)
        XCTAssertNil(Planner.nextTeachingDay(from: today, schedule: schedule(), subgroup: nil, now: today))
    }
}
