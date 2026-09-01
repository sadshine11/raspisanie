import Foundation

enum ParseError: LocalizedError {
    case noDays
    case notSchedulePage

    var errorDescription: String? {
        switch self {
        case .noDays:          return "На странице не нашлось ни одного учебного дня."
        case .notSchedulePage: return "Сервер вернул не страницу расписания."
        }
    }
}

/// Разбор HTML страницы вида /viewer/edu-group-schedule.
///
/// Сайт отдаёт server-rendered разметку Yii2, поэтому структура стабильна:
///   <h2 id="linkN"><b>День</b></h2>
///     <h3 class="panel-title">N-я неделя</h3> <table> строки занятий </table>
///
/// Ячейка предмета выглядит так:
///   <b>КАБИНЕТ</b>, <b>ВИД</b>, НАЗВАНИЕ, <b><a id_teacher=..>ПРЕПОДАВАТЕЛЬ</a></b>
/// но НАЗВАНИЕ может быть обёрнуто в ссылку на курс Moodle и само содержать
/// запятые, поэтому режем по <b>-сегментам, а не по запятым.
enum ScheduleParser {

    static func parse(html: String, scheduleId: Int, groupId: Int, fetchedAt: Date = Date()) throws -> Schedule {
        let source = html as NSString
        let whole = NSRange(location: 0, length: source.length)

        let title = Rx.title.firstGroups(in: source, range: whole).flatMap { $0[1] }.map(strip) ?? ""
        let semester = Rx.semester.firstGroups(in: source, range: whole).flatMap { $0[1] }.map(strip) ?? ""

        let dayMatches = Rx.day.allMatches(in: source, range: whole)
        guard !dayMatches.isEmpty else {
            throw title.isEmpty ? ParseError.notSchedulePage : ParseError.noDays
        }

        var days: [DaySchedule] = []
        for (i, match) in dayMatches.enumerated() {
            guard let dayName = match.groups[2].map(strip), !dayName.isEmpty else { continue }
            let bodyStart = match.range.location + match.range.length
            let bodyEnd = i + 1 < dayMatches.count ? dayMatches[i + 1].range.location : source.length
            let body = NSRange(location: bodyStart, length: max(0, bodyEnd - bodyStart))

            var weeks: [WeekBlock] = []
            for panel in Rx.panel.allMatches(in: source, range: body) {
                guard let rawLabel = panel.groups[1].map(strip), !rawLabel.isEmpty else { continue }
                let tableRange = panel.groupRanges[2] ?? NSRange(location: 0, length: 0)
                weeks.append(WeekBlock(
                    label: rawLabel,
                    isCurrent: rawLabel.contains("текущая"),
                    lessons: lessons(in: source, range: tableRange)
                ))
            }
            days.append(DaySchedule(name: dayName, weeks: weeks))
        }

        return Schedule(groupTitle: title, semester: semester, days: days,
                        scheduleId: scheduleId, groupId: groupId, fetchedAt: fetchedAt)
    }

    // MARK: - Строки таблицы

    private static func lessons(in source: NSString, range: NSRange) -> [Lesson] {
        var out: [Lesson] = []
        // Ячейки «пара» и «время» объединяются через rowspan, поэтому у строки-продолжения
        // колонок меньше — переносим последние известные значения вперёд.
        var lastPair = ""
        var lastTime = ""

        for row in Rx.row.allMatches(in: source, range: range) {
            guard let bodyRange = row.groupRanges[2] else { continue }
            let cells = Rx.cell.allMatches(in: source, range: bodyRange)
                .compactMap { $0.groupRanges[1] }

            let pair: String
            let time: String
            let subgroup: String
            let subjectRange: NSRange

            if cells.count >= 4 {
                pair = strip(source.substring(with: cells[0]))
                time = strip(source.substring(with: cells[1]))
                subgroup = strip(source.substring(with: cells[2]))
                subjectRange = cells[3]
                lastPair = pair
                lastTime = time
            } else if cells.count == 2 {
                pair = lastPair
                time = lastTime
                subgroup = strip(source.substring(with: cells[0]))
                subjectRange = cells[1]
            } else {
                continue
            }

            let subjectHTML = source.substring(with: subjectRange)
            guard !strip(subjectHTML).isEmpty else { continue }

            let parsed = parseSubject(subjectHTML)
            out.append(Lesson(
                pair: pair,
                time: time,
                subgroup: subgroup.isEmpty ? nil : subgroup,
                room: parsed.room,
                kind: parsed.kind,
                name: parsed.name,
                teacher: parsed.teacher,
                teacherId: parsed.teacherId,
                courseURL: parsed.courseURL
            ))
        }
        return out
    }

    // MARK: - Ячейка предмета

    struct Subject {
        var room: String?
        var kind: String?
        var name: String
        var teacher: String?
        var teacherId: String?
        var courseURL: String?
    }

    static func parseSubject(_ cellHTML: String) -> Subject {
        let cell = cellHTML as NSString
        let whole = NSRange(location: 0, length: cell.length)

        var teacher: String?
        var teacherId: String?
        var courseURL: String?
        var parts: [String] = []

        for bold in Rx.bold.allMatches(in: cell, range: whole) {
            guard let innerRange = bold.groupRanges[1] else { continue }
            let innerString = cell.substring(with: innerRange)
            let inner = innerString as NSString
            let innerWhole = NSRange(location: 0, length: inner.length)

            if let t = Rx.teacher.firstGroups(in: inner, range: innerWhole) {
                teacherId = t[1]
                teacher = t[2].map(strip)
                continue
            }
            if let c = Rx.course.firstGroups(in: inner, range: innerWhole) {
                courseURL = c[1]?.replacingOccurrences(of: "&amp;", with: "&")
                if let label = c[2].map(strip), !label.isEmpty { parts.append(label) }
                continue
            }
            let value = strip(innerString)
            if !value.isEmpty { parts.append(value) }
        }

        let name: String
        if parts.count >= 3 {
            name = parts[2...].joined(separator: ", ")
        } else {
            // Название лежит обычным текстом между <b>-сегментами.
            let plain = Rx.bold.replacingMatches(in: cell, range: whole, with: "")
            name = strip(plain).trimmingCharacters(in: CharacterSet(charactersIn: ", "))
        }

        return Subject(
            room: parts.first,
            kind: parts.count > 1 ? parts[1] : nil,
            name: name,
            teacher: teacher,
            teacherId: teacherId,
            courseURL: courseURL
        )
    }

    // MARK: - Текст

    /// Снимает теги, разворачивает сущности и схлопывает пробелы.
    static func strip(_ html: String) -> String {
        var s = Rx.tag.replacingMatches(in: html as NSString, range: fullRange(html), with: "")
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&laquo;", with: "«")
        s = s.replacingOccurrences(of: "&raquo;", with: "»")
        s = Rx.numericEntity.replacingMatches(in: s as NSString, range: fullRange(s), with: "")
        s = Rx.whitespace.replacingMatches(in: s as NSString, range: fullRange(s), with: " ")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func fullRange(_ s: String) -> NSRange {
        NSRange(location: 0, length: (s as NSString).length)
    }
}
