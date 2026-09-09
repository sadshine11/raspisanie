import SwiftUI

/// Строка занятия в сгруппированном списке.
///
/// Вид занятия несёт цветная риска слева — как в Календаре, — а не крашеная
/// плашка: цвет остаётся на одном узком элементе, всё остальное набрано
/// системными кеглями и системными цветами текста.
struct LessonRow: View {
    let lesson: Lesson
    var isNow: Bool = false
    var progress: Double = 0
    /// Пара уже отзвенела: строка гаснет, чтобы день читался сверху вниз.
    var isPast: Bool = false
    /// Домашние задания, которые нужно сдать на этой паре.
    var homework: [Homework] = []

    private var accent: Color { Theme.color(forKind: lesson.kind) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            times
            rail
            details
        }
        .padding(.vertical, 2)
        .listRowBackground(isNow ? Theme.tint.opacity(0.14) : nil)
    }

    // MARK: - Колонка со временем

    private var times: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(startTime)
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(isPast ? .tertiary : .secondary)
            Text(endTime)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
        .frame(width: Theme.timeColumn, alignment: .trailing)
    }

    private var rail: some View {
        Capsule()
            .fill(accent)
            .opacity(isPast ? 0.4 : 1)
            .frame(width: Theme.railWidth)
    }

    // MARK: - Содержание

    private var details: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(lesson.name.isEmpty ? "Без названия" : lesson.name)
                .font(.body)
                .fontWeight(isNow ? .semibold : .regular)
                .foregroundStyle(isPast ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(isPast ? .tertiary : .secondary)
                .fixedSize(horizontal: false, vertical: true)

            if isNow {
                progressBar
            }

            if let course = lesson.courseURL, let url = URL(string: course) {
                Link("Открыть курс", destination: url)
                    .font(.subheadline)
                    .padding(.top, 2)
            }

            ForEach(homework) { item in
                homeworkLine(item)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// «Лекция · А312 · Петрова Л. В.» — одной строкой, как подпись ячейки.
    private var subtitle: String {
        var parts = [Theme.fullKindName(lesson.kind)]
        if let subgroup = lesson.subgroup, !subgroup.isEmpty {
            parts.append("\(subgroup)-я подгруппа")
        }
        if let room = lesson.room, !room.isEmpty { parts.append(room) }
        if let teacher = lesson.teacher, !teacher.isEmpty { parts.append(teacher) }
        if isPast { parts.append("прошла") }
        return parts.joined(separator: " · ")
    }

    private var progressBar: some View {
        HStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(Theme.tint)
                        .frame(width: max(3, geo.size.width * progress))
                }
            }
            .frame(height: 3)

            Text(endTime)
                .font(.footnote)
                .monospacedDigit()
                .foregroundStyle(Theme.tint)
        }
        .padding(.top, 6)
    }

    /// Задание прямо в строке пары: ради этого оно и привязано к занятию.
    /// Текст носит обычный цвет текста — опознаёт строку значок рядом.
    private func homeworkLine(_ item: Homework) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Image(systemName: "checklist")
                .font(.footnote)
                .foregroundStyle(Theme.tint)
            Text(item.text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 5)
    }

    private var startTime: String {
        lesson.time.split(separator: "-").first.map(String.init) ?? lesson.time
    }

    private var endTime: String {
        lesson.time.split(separator: "-").last.map(String.init) ?? ""
    }
}

/// Однострочная версия для сетки недели и «завтра»: время, риска, название.
struct CompactLessonRow: View {
    let lesson: Lesson
    var homework: [Homework] = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(lesson.time.split(separator: "-").first.map(String.init) ?? "")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: Theme.timeColumn, alignment: .trailing)

            Capsule()
                .fill(Theme.color(forKind: lesson.kind))
                .frame(width: Theme.railWidth)

            VStack(alignment: .leading, spacing: 2) {
                Text(lesson.name)
                    .font(.body)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(homework) { item in
                    HStack(alignment: .top, spacing: 7) {
                        Image(systemName: "checklist")
                            .font(.footnote)
                            .foregroundStyle(Theme.tint)
                        Text(item.text)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    private var subtitle: String {
        var parts = [Theme.fullKindName(lesson.kind)]
        if let subgroup = lesson.subgroup, !subgroup.isEmpty {
            parts.append("\(subgroup)-я подгруппа")
        }
        if let room = lesson.room, !room.isEmpty { parts.append(room) }
        return parts.joined(separator: " · ")
    }
}
