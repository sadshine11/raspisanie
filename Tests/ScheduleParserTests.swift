import XCTest
@testable import Raspisanie

private final class BundleToken {}

final class ScheduleParserTests: XCTestCase {

    private func fixture(_ name: String) throws -> String {
        let bundle = Bundle(for: BundleToken.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "html"),
                                "Не найдена фикстура \(name).html")
        return try String(contentsOf: url, encoding: .utf8)
    }

    private func parse3281() throws -> Schedule {
        try ScheduleParser.parse(html: fixture("group3281"), scheduleId: 116, groupId: 3281)
    }

    private func parse3284() throws -> Schedule {
        try ScheduleParser.parse(html: fixture("group3284"), scheduleId: 117, groupId: 3284)
    }

    // MARK: - Общая структура

    func testParsesHeader() throws {
        let schedule = try parse3281()
        XCTAssertEqual(schedule.groupTitle, "56-1 (ХБ 26-01)")
        XCTAssertEqual(schedule.semester, "2026-2027, Осень, Очная форма обучения")
        XCTAssertEqual(schedule.groupId, 3281)
        XCTAssertEqual(schedule.scheduleId, 116)
    }

    func testParsesAllDaysInOrder() throws {
        let schedule = try parse3281()
        XCTAssertEqual(schedule.days.map(\.name),
                       ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница"])
    }

    /// Контрольное число: если разметка сайта изменится и часть занятий
    /// потеряется, тест упадёт раньше, чем приложение попадёт на телефон.
    func testParsesEveryLesson() throws {
        XCTAssertEqual(try parse3281().lessonCount, 34)
        XCTAssertEqual(try parse3284().lessonCount, 8)
    }

    func testDetectsCurrentWeek() throws {
        let schedule = try parse3281()
        XCTAssertEqual(schedule.currentWeekIndex, 1)
        let monday = try XCTUnwrap(schedule.day(named: "Понедельник"))
        XCTAssertEqual(monday.weeks.count, 2)
        XCTAssertTrue(try XCTUnwrap(monday.week(1)).isCurrent)
        XCTAssertFalse(try XCTUnwrap(monday.week(2)).isCurrent)
    }

    // MARK: - Поля занятия

    func testParsesLessonFields() throws {
        let schedule = try parse3281()
        let monday = try XCTUnwrap(schedule.day(named: "Понедельник")?.week(1))
        let first = try XCTUnwrap(monday.lessons.first)

        XCTAssertEqual(first.pair, "1-я пара")
        XCTAssertEqual(first.time, "08:30-10:05")
        XCTAssertEqual(first.room, "А229")
        XCTAssertEqual(first.kind, "Лек")
        XCTAssertEqual(first.name, "Информационные системы и технологии")
        XCTAssertEqual(first.teacher, "Кобежиков В.А.")
        XCTAssertEqual(first.teacherId, "153")
        XCTAssertNil(first.subgroup)
        XCTAssertNil(first.courseURL)
        XCTAssertEqual(first.startMinutes, 8 * 60 + 30)
        XCTAssertEqual(first.endMinutes, 10 * 60 + 5)
        XCTAssertEqual(first.pairNumber, 1)
    }

    func testParsesSubgroups() throws {
        let schedule = try parse3281()
        let all = schedule.days.flatMap { $0.weeks.flatMap(\.lessons) }
        XCTAssertEqual(all.filter { $0.subgroup != nil }.count, 16)
        XCTAssertEqual(Set(all.compactMap(\.subgroup)), ["1", "2"])
    }

    /// Строки под rowspan содержат меньше ячеек: пара и время берутся
    /// из предыдущей строки. Без этого терялась заметная часть занятий.
    func testRecoversLessonsUnderRowspan() throws {
        let schedule = try parse3281()
        let mondaySecondWeek = try XCTUnwrap(schedule.day(named: "Понедельник")?.week(2))
        XCTAssertEqual(mondaySecondWeek.lessons.count, 4)
        for lesson in mondaySecondWeek.lessons {
            XCTAssertFalse(lesson.pair.isEmpty, "у занятия потерялся номер пары")
            XCTAssertFalse(lesson.time.isEmpty, "у занятия потерялось время")
        }
    }

    // MARK: - Ссылки на курсы

    /// Название предмета может быть обёрнуто в ссылку и само содержать запятые —
    /// именно поэтому ячейка режется по <b>-сегментам, а не по запятым.
    func testParsesCourseLinkedNamesContainingCommas() throws {
        let schedule = try parse3284()
        let all = schedule.days.flatMap { $0.weeks.flatMap(\.lessons) }
        XCTAssertEqual(all.filter { $0.courseURL != nil }.count, 6)

        let welded = try XCTUnwrap(all.first { $0.name.hasPrefix("Металлические конструкции") })
        XCTAssertEqual(welded.name, "Металлические конструкции, включая сварку")
        XCTAssertEqual(welded.courseURL, "https://e.sfu-kras.ru/course/view.php?id=24180")
        XCTAssertEqual(welded.room, "А219")
        XCTAssertNotNil(welded.teacher)

        let modern = try XCTUnwrap(all.first { $0.name.hasPrefix("Современные материалы") })
        XCTAssertEqual(modern.name, "Современные материалы, конструкции и технологии")
    }

    func testAcceptsNonMoodleLinks() throws {
        let all = try parse3284().days.flatMap { $0.weeks.flatMap(\.lessons) }
        let meet = try XCTUnwrap(all.first { $0.name.hasPrefix("Железобетонные") })
        XCTAssertEqual(meet.courseURL, "https://meet.google.com/cxa-qvdn-zzs")
    }

    // MARK: - Разбор одной ячейки

    func testParsesPlainSubjectCell() {
        let cell = "<b>А229</b>, <b>Лек</b>, История России, <b><a href=\"/viewer/teacher-schedule?id_schedule=116&amp;id_teacher=163\">Медведева Н.Н.</a></b>"
        let s = ScheduleParser.parseSubject(cell)
        XCTAssertEqual(s.room, "А229")
        XCTAssertEqual(s.kind, "Лек")
        XCTAssertEqual(s.name, "История России")
        XCTAssertEqual(s.teacher, "Медведева Н.Н.")
        XCTAssertEqual(s.teacherId, "163")
        XCTAssertNil(s.courseURL)
    }

    func testParsesLinkedSubjectCell() {
        let cell = "<b>А111</b>, <b>Лек</b>, <b><a href=\"https://e.sfu-kras.ru/course/view.php?id=27735\" target=\"_blank\">Теплогазоснабжение и вентиляция</a></b>, <b><a href=\"/viewer/teacher-schedule?id_schedule=117&amp;id_teacher=63\">Логинова Е.В.</a></b>"
        let s = ScheduleParser.parseSubject(cell)
        XCTAssertEqual(s.room, "А111")
        XCTAssertEqual(s.kind, "Лек")
        XCTAssertEqual(s.name, "Теплогазоснабжение и вентиляция")
        XCTAssertEqual(s.teacher, "Логинова Е.В.")
        XCTAssertEqual(s.courseURL, "https://e.sfu-kras.ru/course/view.php?id=27735")
    }

    // MARK: - Текст и ошибки

    func testStripHandlesEntitiesAndWhitespace() {
        XCTAssertEqual(ScheduleParser.strip("  <b>А&nbsp;1</b>\n\t <i>Пр</i>  "), "А 1 Пр")
        XCTAssertEqual(ScheduleParser.strip("Иванов &amp; Петров"), "Иванов & Петров")
        XCTAssertEqual(ScheduleParser.strip("&laquo;Тест&raquo;"), "«Тест»")
        XCTAssertEqual(ScheduleParser.strip(""), "")
    }

    func testThrowsOnUnrelatedPage() {
        XCTAssertThrowsError(
            try ScheduleParser.parse(html: "<html><body>Ничего интересного</body></html>",
                                     scheduleId: 116, groupId: 3281)
        )
    }

    /// Оборванная загрузка не должна ронять приложение: разбирается столько,
    /// сколько успело прийти, остальное просто отсутствует.
    func testDegradesGracefullyOnTruncatedHTML() throws {
        let full = try fixture("group3281")
        let half = String(full.prefix(full.count / 2))
        let schedule = try ScheduleParser.parse(html: half, scheduleId: 116, groupId: 3281)
        XCTAssertGreaterThanOrEqual(schedule.days.count, 2)
        XCTAssertGreaterThan(schedule.lessonCount, 0)
        XCTAssertLessThan(schedule.lessonCount, 34)
    }
}
