import XCTest
@testable import Raspisanie

/// Хранилище заданий пишет на диск, поэтому каждому тесту выдаётся своя
/// временная папка: иначе тесты читали бы и затирали настоящие данные
/// пользователя в Application Support.
final class HomeworkStoreTests: XCTestCase {

    private var calendar: Calendar { Planner.calendar }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("HomeworkStoreTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// Учебный год считается от недели с 1 сентября 2026 года (вторник).
    private func date(day: Int, hour: Int = 0) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour)))
    }

    private func lesson(_ pair: Int, _ time: String, _ name: String,
                        room: String = "А229") -> Lesson {
        Lesson(pair: "\(pair)-я пара", time: time, subgroup: nil,
               room: room, kind: "Лек", name: name,
               teacher: "Иванов И.И.", teacherId: "1", courseURL: nil)
    }

    /// Физика — только на второй неделе, матанализ — на обеих.
    private func schedule() -> Schedule {
        Schedule(
            groupTitle: "56-1",
            semester: "Осень",
            days: [
                DaySchedule(name: "Вторник", weeks: [
                    WeekBlock(label: "1-я неделя", isCurrent: false,
                              lessons: [lesson(3, "13:00-14:35", "Математический анализ")]),
                    WeekBlock(label: "2-я неделя", isCurrent: true,
                              lessons: [lesson(1, "08:30-10:05", "Физика", room: "А108"),
                                        lesson(4, "14:45-16:20", "Математический анализ")]),
                ]),
            ],
            scheduleId: 116, groupId: 3281, fetchedAt: Date()
        )
    }

    // MARK: - Запись и чтение

    @MainActor
    func testAddAttachesToNearestLessonAndSurvivesRestart() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "физика", text: "  задачи 3–7  ",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))

        let item = try XCTUnwrap(store.items.first)
        XCTAssertEqual(store.items.count, 1)
        XCTAssertEqual(item.subject, "Физика")
        XCTAssertEqual(item.text, "задачи 3–7")
        XCTAssertEqual(item.dueDate, try date(day: 8))
        XCTAssertEqual(item.pair, "1-я пара")
        XCTAssertEqual(item.room, "А108")

        let reopened = HomeworkStore(storage: Storage(directory: directory))
        XCTAssertEqual(reopened.items.first?.id, item.id)
        XCTAssertEqual(reopened.items.first?.text, "задачи 3–7")
    }

    @MainActor
    func testEmptyTextIsNotSaved() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "   ",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))
        XCTAssertTrue(store.items.isEmpty)
    }

    // MARK: - Отметка о выполнении

    @MainActor
    func testToggleMarksDoneAndBack() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))

        store.toggle(try XCTUnwrap(store.items.first))
        XCTAssertEqual(store.pendingCount, 0)
        XCTAssertEqual(store.done.count, 1)
        XCTAssertNotNil(store.items.first?.doneAt)

        store.toggle(try XCTUnwrap(store.items.first))
        XCTAssertEqual(store.pendingCount, 1)
        XCTAssertNil(store.items.first?.doneAt)
    }

    // MARK: - Правка

    /// Правка опечатки в тексте не должна перебрасывать задание на следующую
    /// неделю, если пара уже прошла.
    @MainActor
    func testEditingTextKeepsTheDueDate() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))
        let before = try XCTUnwrap(store.items.first)

        store.update(before, subject: "Физика", text: "задачи 3–7",
                     schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 12))

        XCTAssertEqual(store.items.first?.text, "задачи 3–7")
        XCTAssertEqual(store.items.first?.dueDate, before.dueDate)
        XCTAssertEqual(store.items.first?.pair, "1-я пара")
    }

    @MainActor
    func testChangingSubjectRecalculatesTheDueDate() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))
        let before = try XCTUnwrap(store.items.first)

        store.update(before, subject: "Математический анализ", text: "задачи",
                     schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))

        XCTAssertEqual(store.items.first?.subject, "Математический анализ")
        XCTAssertEqual(store.items.first?.pair, "4-я пара")
        XCTAssertEqual(store.items.first?.dueDate, try date(day: 8))
    }

    // MARK: - Перенос

    /// Если пары по предмету в сетке больше нет, «перенести» не может молча
    /// ничего не сделать: задание уходит в «Без срока».
    @MainActor
    func testMoveDropsTheDueDateWhenSubjectHasNoLessons() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))
        let item = try XCTUnwrap(store.items.first)
        XCTAssertNotNil(item.dueDate)

        let withoutPhysics = Schedule(groupTitle: "56-1", semester: "Осень", days: [],
                                      scheduleId: 116, groupId: 3281, fetchedAt: Date())
        store.moveToNextLesson(item, schedule: withoutPhysics, subgroup: nil,
                               now: try date(day: 9, hour: 10))

        XCTAssertNil(store.items.first?.dueDate)
        XCTAssertNil(store.items.first?.pair)
        XCTAssertNil(store.items.first?.room)
    }

    @MainActor
    func testMoveGoesToTheNextOccurrence() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))
        store.moveToNextLesson(try XCTUnwrap(store.items.first),
                               schedule: schedule(), subgroup: nil,
                               now: try date(day: 9, hour: 10))

        // Физика стоит только на второй неделе — следующая через две недели.
        XCTAssertEqual(store.items.first?.dueDate, try date(day: 22))
    }

    // MARK: - Догрузка расписания

    /// Задание могли записать до того, как расписание пришло из сети.
    @MainActor
    func testDueDateIsFilledWhenScheduleArrives() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: nil, subgroup: nil, now: try date(day: 8, hour: 7))
        XCTAssertNil(store.items.first?.dueDate)

        store.fillMissingDueDates(schedule: schedule(), subgroup: nil,
                                  now: try date(day: 8, hour: 7))
        XCTAssertEqual(store.items.first?.dueDate, try date(day: 8))
        XCTAssertEqual(store.items.first?.pair, "1-я пара")
    }

    // MARK: - Привязка к занятию

    @MainActor
    func testItemsMatchTheirOwnLessonOnly() throws {
        let directory = temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = HomeworkStore(storage: Storage(directory: directory))
        store.add(subject: "Физика", text: "задачи",
                  schedule: schedule(), subgroup: nil, now: try date(day: 8, hour: 7))

        let physics = lesson(1, "08:30-10:05", "Физика", room: "А108")
        let maths = lesson(4, "14:45-16:20", "Математический анализ")

        XCTAssertEqual(store.items(for: physics, on: try date(day: 8, hour: 9)).count, 1)
        XCTAssertTrue(store.items(for: maths, on: try date(day: 8, hour: 9)).isEmpty)
        XCTAssertTrue(store.items(for: physics, on: try date(day: 9, hour: 9)).isEmpty)

        // Выполненное задание в карточке занятия больше не висит.
        store.toggle(try XCTUnwrap(store.items.first))
        XCTAssertTrue(store.items(for: physics, on: try date(day: 8, hour: 9)).isEmpty)
    }
}
