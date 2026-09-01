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

    /// Первая неделя — та, в которую попало 1 сентября. В 2026 году это
    /// вторник, значит неделя началась ещё 31 августа и всё равно первая.
    func testWeekContainingFirstSeptemberIsFirst() throws {
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 31, month: 8)), 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 1)), 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 6)), 1)
    }

    func testWeekAlternatesEverySevenDays() throws {
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 1)), 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 8)), 2)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 15)), 1)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 22)), 2)
    }

    /// Начало месяца счёт не обнуляет: 30 ноября 2026 отстоит от 31 августа
    /// ровно на 13 недель, поэтому 1 декабря — вторая неделя, а не первая.
    func testMonthStartDoesNotResetAlternation() throws {
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 30, month: 11)), 2)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 1, month: 12)), 2)
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 7, month: 12)), 1)
    }

    /// Через сентябрь отсчёт начинается заново, а конец августа ещё
    /// относится к прошлому учебному году.
    func testAcademicYearRollover() throws {
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 1, year: 2025)), 1)  // понедельник
        XCTAssertEqual(Planner.weekIndex(for: try date(day: 1, year: 2027)), 1)  // среда
        XCTAssertEqual(Planner.academicYearStart(for: try date(day: 1)),
                       try date(day: 31, month: 8))
        XCTAssertEqual(Planner.academicYearStart(for: try date(day: 30, month: 8)),
                       try date(day: 1, year: 2025))
    }

    /// Дни одной календарной недели должны попадать в одну учебную неделю,
    /// включая воскресенье — ради этого календарь начинается с понедельника.
    func testDaysOfSameWeekShareWeekIndex() throws {
        let monday = try date(day: 7)
        let expected = Planner.weekIndex(for: monday)
        XCTAssertEqual(expected, 2)
        for offset in 0...6 {
            let day = try XCTUnwrap(calendar.date(byAdding: .day, value: offset, to: monday))
            XCTAssertEqual(Planner.weekIndex(for: day), expected,
                           "сдвиг \(offset) дней от понедельника попал в другую неделю")
        }
    }

    // MARK: - План дня

    func testPlanPicksLessonsOfCorrectWeek() throws {
        let today = try date(day: 1)
        let s = schedule(currentWeek: 1,
                         tuesdayWeek1: [lesson(1, "08:30-10:05", name: "Первая неделя")],
                         tuesdayWeek2: [lesson(1, "08:30-10:05", name: "Вторая неделя")])

        let now = Planner.plan(for: today, schedule: s, subgroup: nil)
        XCTAssertEqual(now.dayName, "Вторник")
        XCTAssertEqual(now.weekIndex, 1)
        XCTAssertEqual(now.lessons.first?.name, "Первая неделя")

        let later = Planner.plan(for: try date(day: 8), schedule: s, subgroup: nil)
        XCTAssertEqual(later.weekIndex, 2)
        XCTAssertEqual(later.lessons.first?.name, "Вторая неделя")
    }

    /// Сервер пометил текущей вторую неделю, но по календарю 1 сентября —
    /// первая, и план дня обязан взять её пары, а не серверные.
    func testPlanIgnoresServerCurrentWeek() throws {
        let s = schedule(currentWeek: 2,
                         tuesdayWeek1: [lesson(1, "08:30-10:05", name: "Первая неделя")],
                         tuesdayWeek2: [lesson(1, "08:30-10:05", name: "Вторая неделя")])
        XCTAssertEqual(s.currentWeekIndex, 2)

        let plan = Planner.plan(for: try date(day: 1), schedule: s, subgroup: nil)
        XCTAssertEqual(plan.weekIndex, 1)
        XCTAssertEqual(plan.lessons.first?.name, "Первая неделя")
    }

    func testPlanIsEmptyForDayWithoutLessons() throws {
        let plan = Planner.plan(for: try date(day: 5), schedule: schedule(), subgroup: nil)
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
        let next = try XCTUnwrap(Planner.nextTeachingDay(from: today, schedule: s, subgroup: nil))
        XCTAssertEqual(next.dayName, "Вторник")
        XCTAssertEqual(next.weekIndex, 2)
    }

    func testNextTeachingDayReturnsNilWhenScheduleEmpty() throws {
        let today = try date(day: 1)
        XCTAssertNil(Planner.nextTeachingDay(from: today, schedule: schedule(), subgroup: nil))
    }
}
