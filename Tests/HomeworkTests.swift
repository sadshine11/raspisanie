import XCTest
@testable import Raspisanie

/// Домашнее задание встаёт на ближайшую пару по своему предмету —
/// здесь проверяется именно этот поиск, потому что ошибиться в нём легко:
/// сетка расписания чередуется через неделю и не знает про календарь.
final class HomeworkTests: XCTestCase {

    private var calendar: Calendar { Planner.calendar }

    /// Учебный год считается от недели с 1 сентября 2026 года (вторник),
    /// поэтому неделя 7–13 сентября — вторая, 14–20 сентября — первая.
    private func date(day: Int, month: Int = 9, year: Int = 2026,
                      hour: Int = 0, minute: Int = 0) throws -> Date {
        let comps = DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
        return try XCTUnwrap(calendar.date(from: comps))
    }

    private func lesson(_ pair: Int, _ time: String, _ name: String,
                        subgroup: String? = nil, room: String = "А229") -> Lesson {
        Lesson(pair: "\(pair)-я пара", time: time, subgroup: subgroup,
               room: room, kind: "Лек", name: name,
               teacher: "Иванов И.И.", teacherId: "1", courseURL: nil)
    }

    private func day(_ name: String, week1: [Lesson] = [], week2: [Lesson] = []) -> DaySchedule {
        DaySchedule(name: name, weeks: [
            WeekBlock(label: "1-я неделя", isCurrent: false, lessons: week1),
            WeekBlock(label: "2-я неделя", isCurrent: true, lessons: week2),
        ])
    }

    /// Матанализ стоит на обеих неделях, физика — только на второй,
    /// химия — только у первой подгруппы.
    private func schedule() -> Schedule {
        Schedule(
            groupTitle: "56-1",
            semester: "Осень",
            days: [
                day("Вторник",
                    week1: [lesson(3, "13:00-14:35", "Математический анализ")],
                    week2: [lesson(1, "08:30-10:05", "Физика"),
                            lesson(4, "14:45-16:20", "Математический анализ")]),
                day("Среда",
                    week2: [lesson(2, "10:15-11:50", "Химия", subgroup: "1")]),
                day("Пятница",
                    week2: [lesson(2, "10:15-11:50", "Физика")]),
            ],
            scheduleId: 116, groupId: 3281, fetchedAt: Date()
        )
    }

    private func next(_ subject: String, from moment: Date,
                      subgroup: String? = nil) -> (date: Date, lesson: Lesson)? {
        Planner.nextLesson(ofSubject: subject, from: moment,
                           schedule: schedule(), subgroup: subgroup)
    }

    // MARK: - Поиск ближайшей пары

    /// Утром вторника физика ещё впереди — задание встаёт на сегодня.
    func testFindsLessonLaterToday() throws {
        let tuesdayMorning = try date(day: 8, hour: 7)
        let found = try XCTUnwrap(next("Физика", from: tuesdayMorning))
        XCTAssertEqual(found.date, try date(day: 8))
        XCTAssertEqual(found.lesson.pair, "1-я пара")
    }

    /// Пара уже началась — записанное на ней задание летит на следующую
    /// встречу с предметом, а не остаётся на той, с которой человек вышел.
    func testSkipsLessonThatAlreadyStarted() throws {
        let tuesdayNoon = try date(day: 8, hour: 12)
        let found = try XCTUnwrap(next("Физика", from: tuesdayNoon))
        XCTAssertEqual(found.date, try date(day: 11))
        XCTAssertEqual(found.lesson.pair, "2-я пара")
    }

    /// Если сегодня по предмету есть ещё одна пара позже — берётся она.
    func testPicksLaterPairOnTheSameDay() throws {
        let tuesdayNoon = try date(day: 8, hour: 12)
        let found = try XCTUnwrap(next("Математический анализ", from: tuesdayNoon))
        XCTAssertEqual(found.date, try date(day: 8))
        XCTAssertEqual(found.lesson.pair, "4-я пара")
    }

    /// Ближайшая пара может оказаться на другой неделе чередования:
    /// со среды второй недели матанализ находится только во вторник первой.
    func testCrossesIntoTheOtherWeekOfTheCycle() throws {
        let wednesday = try date(day: 9, hour: 10)
        let found = try XCTUnwrap(next("Математический анализ", from: wednesday))
        XCTAssertEqual(found.date, try date(day: 15))
        XCTAssertEqual(found.lesson.pair, "3-я пара")
        XCTAssertEqual(Planner.weekIndex(for: found.date), 1)
    }

    /// Название с сайта и введённое руками отличаются регистром и «ё».
    func testMatchesSubjectIgnoringCase() throws {
        let morning = try date(day: 8, hour: 7)
        XCTAssertNotNil(next("  физика  ", from: morning))
    }

    func testUnknownSubjectHasNoLesson() throws {
        XCTAssertNil(next("Астрономия", from: try date(day: 8, hour: 7)))
        XCTAssertNil(next("   ", from: try date(day: 8, hour: 7)))
    }

    /// Чужая подгруппа не в счёт: на эту пару человек не ходит.
    func testRespectsSubgroup() throws {
        let morning = try date(day: 8, hour: 7)
        XCTAssertNil(next("Химия", from: morning, subgroup: "2"))
        let found = try XCTUnwrap(next("Химия", from: morning, subgroup: "1"))
        XCTAssertEqual(found.date, try date(day: 9))
    }

    // MARK: - Список предметов и дат

    func testSubjectsAreUniqueAndSorted() {
        let subjects = Planner.subjects(in: schedule(), subgroup: nil)
        XCTAssertEqual(subjects, ["Математический анализ", "Физика", "Химия"])
    }

    func testSubjectsSkipOtherSubgroups() {
        let subjects = Planner.subjects(in: schedule(), subgroup: "2")
        XCTAssertFalse(subjects.contains("Химия"))
    }

    /// «Вторник 1-й недели» со среды 9 сентября — это 15 сентября.
    func testDateOfDayInWeek() throws {
        let found = Planner.date(ofDay: "Вторник", weekIndex: 1, from: try date(day: 9, hour: 10))
        XCTAssertEqual(found, try date(day: 15))
    }

    /// День, уже прошедший на этой неделе, — это дата ЭТОЙ недели, а не
    /// следующего появления через две недели: иначе в сетке «Недели» у
    /// понедельника стояла бы чужая дата, а домашнее задание за него
    /// не показывалось бы вовсе.
    func testDateOfDayLooksBackToTheStartOfTheWeek() throws {
        let wednesday = try date(day: 9, hour: 10)
        XCTAssertEqual(Planner.weekIndex(for: wednesday), 2)
        XCTAssertEqual(Planner.date(ofDay: "Понедельник", weekIndex: 2, from: wednesday),
                       try date(day: 7))
        // Тот же понедельник первой недели — уже вперёд, на следующей неделе.
        XCTAssertEqual(Planner.date(ofDay: "Понедельник", weekIndex: 1, from: wednesday),
                       try date(day: 14))
    }

    // MARK: - Запись задания

    func testHomeworkAttachesToNearestLesson() throws {
        let item = Homework.make(subject: "физика", text: "  §14, задачи 3–7  ",
                                 schedule: schedule(), subgroup: nil,
                                 now: try date(day: 8, hour: 7))
        XCTAssertEqual(item.dueDate, try date(day: 8))
        XCTAssertEqual(item.pair, "1-я пара")
        XCTAssertEqual(item.time, "08:30-10:05")
        XCTAssertEqual(item.room, "А229")
        XCTAssertEqual(item.startTime, "08:30")
        XCTAssertEqual(item.text, "§14, задачи 3–7")
        // Название подменяется на то, что стоит в расписании: по нему
        // задание потом ищется в карточке занятия.
        XCTAssertEqual(item.subject, "Физика")
    }

    /// Без расписания задание сохраняется без срока и ждёт загрузки.
    func testHomeworkWithoutScheduleHasNoDueDate() throws {
        let item = Homework.make(subject: "Физика", text: "читать главу",
                                 schedule: nil, subgroup: nil,
                                 now: try date(day: 8, hour: 7))
        XCTAssertNil(item.dueDate)
        XCTAssertNil(item.pair)
        XCTAssertEqual(item.subject, "Физика")
    }

    func testHomeworkForSubjectWithoutLessonsHasNoDueDate() throws {
        let item = Homework.make(subject: "Астрономия", text: "реферат",
                                 schedule: schedule(), subgroup: nil,
                                 now: try date(day: 8, hour: 7))
        XCTAssertNil(item.dueDate)
    }

    // MARK: - Просрочка

    func testOverdueOnlyWhileUnfinished() throws {
        var item = Homework.make(subject: "Физика", text: "задачи",
                                 schedule: schedule(), subgroup: nil,
                                 now: try date(day: 8, hour: 7))
        XCTAssertFalse(item.isOverdue(at: try date(day: 8, hour: 23)))
        XCTAssertTrue(item.isOverdue(at: try date(day: 9, hour: 1)))

        item.isDone = true
        XCTAssertFalse(item.isOverdue(at: try date(day: 9, hour: 1)))
    }

    func testUndatedHomeworkIsNeverOverdue() throws {
        let item = Homework.make(subject: "Астрономия", text: "реферат",
                                 schedule: schedule(), subgroup: nil,
                                 now: try date(day: 8, hour: 7))
        XCTAssertFalse(item.isOverdue(at: try date(day: 30, hour: 12)))
    }
}
