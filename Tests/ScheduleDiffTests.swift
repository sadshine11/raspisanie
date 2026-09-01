import XCTest
@testable import Raspisanie

final class ScheduleDiffTests: XCTestCase {

    // MARK: - Конструкторы

    private func lesson(_ pair: Int,
                        name: String,
                        room: String = "А100",
                        kind: String = "Лек",
                        teacher: String = "Иванов И.И.",
                        subgroup: String? = nil) -> Lesson {
        Lesson(pair: "\(pair)-я пара",
               time: "08:30-10:05",
               subgroup: subgroup,
               room: room,
               kind: kind,
               name: name,
               teacher: teacher,
               teacherId: "1",
               courseURL: nil)
    }

    private func schedule(monday week1: [Lesson], week2: [Lesson] = []) -> Schedule {
        Schedule(groupTitle: "56-1",
                 semester: "Осень",
                 days: [DaySchedule(name: "Понедельник", weeks: [
                     WeekBlock(label: "1-я неделя (текущая)", isCurrent: true, lessons: week1),
                     WeekBlock(label: "2-я неделя", isCurrent: false, lessons: week2),
                 ])],
                 scheduleId: 116,
                 groupId: 3281,
                 fetchedAt: Date())
    }

    // MARK: - Тесты

    func testIdenticalSchedulesProduceNoChanges() {
        let a = schedule(monday: [lesson(1, name: "Математика"), lesson(2, name: "История")])
        XCTAssertTrue(ScheduleDiffer.diff(from: a, to: a).isEmpty)
    }

    func testDetectsChangedRoom() throws {
        let before = schedule(monday: [lesson(1, name: "Математика", room: "А100")])
        let after  = schedule(monday: [lesson(1, name: "Математика", room: "А305")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.count, 1)
        let change = try XCTUnwrap(changes.first)
        XCTAssertEqual(change.kind, .modified)
        XCTAssertEqual(change.day, "Понедельник")
        XCTAssertEqual(change.weekIndex, 1)
        XCTAssertEqual(change.details, ["Кабинет: А100 → А305"])
    }

    func testDetectsChangedTeacherAndKind() throws {
        let before = schedule(monday: [lesson(1, name: "Физика", kind: "Лек", teacher: "Иванов И.И.")])
        let after  = schedule(monday: [lesson(1, name: "Физика", kind: "Лаб", teacher: "Петров П.П.")])

        let change = try XCTUnwrap(ScheduleDiffer.diff(from: before, to: after).first)
        XCTAssertEqual(change.kind, .modified)
        XCTAssertEqual(change.details, ["Вид: Лек → Лаб", "Преподаватель: Иванов И.И. → Петров П.П."])
    }

    /// Замена предмета в том же слоте — это одно изменение,
    /// а не пара «убрали одно, добавили другое».
    func testSubstitutionInSameSlotIsOneModification() throws {
        let before = schedule(monday: [lesson(3, name: "Физкультура")])
        let after  = schedule(monday: [lesson(3, name: "Высшая математика")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.count, 1)
        let change = try XCTUnwrap(changes.first)
        XCTAssertEqual(change.kind, .modified)
        XCTAssertEqual(change.before?.name, "Физкультура")
        XCTAssertEqual(change.after?.name, "Высшая математика")
        XCTAssertTrue(change.details.contains("Предмет: Физкультура → Высшая математика"))
    }

    func testDetectsAddedLesson() throws {
        let before = schedule(monday: [lesson(1, name: "Математика")])
        let after  = schedule(monday: [lesson(1, name: "Математика"), lesson(2, name: "История")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .added)
        XCTAssertEqual(changes.first?.after?.name, "История")
    }

    func testDetectsRemovedLesson() throws {
        let before = schedule(monday: [lesson(1, name: "Математика"), lesson(2, name: "История")])
        let after  = schedule(monday: [lesson(1, name: "Математика")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.kind, .removed)
        XCTAssertEqual(changes.first?.before?.name, "История")
    }

    /// Занятия разных подгрупп на одной паре не должны считаться заменой друг друга.
    func testSubgroupsAreTrackedSeparately() {
        let before = schedule(monday: [
            lesson(4, name: "Лаба", subgroup: "1"),
            lesson(4, name: "Лаба", subgroup: "2"),
        ])
        let after = schedule(monday: [
            lesson(4, name: "Лаба", subgroup: "1"),
            lesson(4, name: "Лаба", room: "А999", subgroup: "2"),
        ])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.lesson?.subgroup, "2")
    }

    func testWeeksAreTrackedSeparately() {
        let before = schedule(monday: [lesson(1, name: "Математика")],
                              week2: [lesson(1, name: "История")])
        let after  = schedule(monday: [lesson(1, name: "Математика")],
                              week2: [lesson(1, name: "Философия")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.count, 1)
        XCTAssertEqual(changes.first?.weekIndex, 2)
    }

    func testChangesAreOrderedByDayThenPair() {
        let before = schedule(monday: [lesson(1, name: "А"), lesson(5, name: "Б")])
        let after  = schedule(monday: [lesson(1, name: "А2"), lesson(5, name: "Б2")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(changes.compactMap { $0.lesson?.pairNumber }, [1, 5])
    }

    func testChangeIdentifiersAreUnique() {
        let before = schedule(monday: [lesson(1, name: "А"), lesson(2, name: "Б"), lesson(3, name: "В")])
        let after  = schedule(monday: [lesson(1, name: "А1"), lesson(2, name: "Б1")])

        let changes = ScheduleDiffer.diff(from: before, to: after)
        XCTAssertEqual(Set(changes.map(\.id)).count, changes.count)
    }
}
