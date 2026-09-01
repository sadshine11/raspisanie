import Foundation

enum ChangeKind: String, Codable, Hashable {
    case added, removed, modified

    var title: String {
        switch self {
        case .added:    return "Добавлено"
        case .removed:  return "Убрано"
        case .modified: return "Изменено"
        }
    }

    var symbol: String {
        switch self {
        case .added:    return "plus.circle.fill"
        case .removed:  return "minus.circle.fill"
        case .modified: return "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}

struct ScheduleChange: Codable, Hashable, Identifiable {
    var day: String
    var weekIndex: Int
    var kind: ChangeKind
    var before: Lesson?
    var after: Lesson?

    var id: String { "\(day)|\(weekIndex)|\(slotKey)|\(kind.rawValue)" }
    var slotKey: String { (after ?? before)?.slotKey ?? "?" }
    var lesson: Lesson? { after ?? before }

    /// Человекочитаемое описание — что именно поменялось внутри слота.
    var details: [String] {
        guard kind == .modified, let a = before, let b = after else { return [] }
        var out: [String] = []
        if a.name != b.name       { out.append("Предмет: \(a.name) → \(b.name)") }
        if a.kind != b.kind       { out.append("Вид: \(a.kind ?? "—") → \(b.kind ?? "—")") }
        if a.room != b.room       { out.append("Кабинет: \(a.room ?? "—") → \(b.room ?? "—")") }
        if a.teacher != b.teacher { out.append("Преподаватель: \(a.teacher ?? "—") → \(b.teacher ?? "—")") }
        return out
    }
}

/// Одна зафиксированная проверка, в которой нашлись отличия.
struct ChangeRecord: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var detectedAt: Date
    var changes: [ScheduleChange]
    var isSeen: Bool = false
}

enum ScheduleDiffer {
    /// Сравнивает два снимка расписания по позициям в сетке.
    /// Ключ — день + номер недели + пара + подгруппа: если в одном слоте
    /// оказался другой предмет, это `modified`, а не пара «убрано/добавлено».
    static func diff(from old: Schedule, to new: Schedule) -> [ScheduleChange] {
        var result: [ScheduleChange] = []
        let dayNames = orderedDays(old: old, new: new)

        for dayName in dayNames {
            let weekIndices = Set(
                (old.day(named: dayName)?.weeks.map(\.index) ?? []) +
                (new.day(named: dayName)?.weeks.map(\.index) ?? [])
            ).sorted()

            for weekIndex in weekIndices {
                let oldSlots = slots(old.day(named: dayName)?.week(weekIndex))
                let newSlots = slots(new.day(named: dayName)?.week(weekIndex))

                for key in Set(oldSlots.keys).union(newSlots.keys).sorted(by: slotOrder) {
                    switch (oldSlots[key], newSlots[key]) {
                    case let (nil, .some(after)):
                        result.append(.init(day: dayName, weekIndex: weekIndex, kind: .added, before: nil, after: after))
                    case let (.some(before), nil):
                        result.append(.init(day: dayName, weekIndex: weekIndex, kind: .removed, before: before, after: nil))
                    case let (.some(before), .some(after)) where before.payload != after.payload:
                        result.append(.init(day: dayName, weekIndex: weekIndex, kind: .modified, before: before, after: after))
                    default:
                        break
                    }
                }
            }
        }
        return result
    }

    private static func slots(_ week: WeekBlock?) -> [String: Lesson] {
        guard let week else { return [:] }
        return Dictionary(week.lessons.map { ($0.slotKey, $0) }, uniquingKeysWith: { a, _ in a })
    }

    /// Дни в естественном порядке недели, а не в порядке появления в HTML.
    private static func orderedDays(old: Schedule, new: Schedule) -> [String] {
        let present = Set(old.days.map(\.name)).union(new.days.map(\.name))
        let known = Weekday.names.filter(present.contains)
        return known + present.subtracting(known).sorted()
    }

    private static func slotOrder(_ a: String, _ b: String) -> Bool {
        let na = Int(a.prefix(while: \.isNumber)) ?? 0
        let nb = Int(b.prefix(while: \.isNumber)) ?? 0
        return na == nb ? a < b : na < nb
    }
}
