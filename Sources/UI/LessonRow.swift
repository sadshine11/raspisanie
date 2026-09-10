import SwiftUI

/// Карточка пары: слева — что и где, справа — блок со временем.
///
/// Вид занятия написан словом в сером чипе, а не выкрашен в свой цвет:
/// янтарь на экране один и достаётся идущей паре. Прошедшая гаснет целиком,
/// чтобы день читался сверху вниз.
struct LessonRow: View {
    let lesson: Lesson
    var isNow: Bool = false
    var progress: Double = 0
    var isPast: Bool = false
    /// Домашние задания, которые нужно сдать на этой паре.
    var homework: [Homework] = []

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            details
            Spacer(minLength: 8)
            TimeBlock(start: startTime, end: endTime, isNow: isNow, isPast: isPast)
        }
        .padding(Theme.cardPadding)
        .card(tint: isNow ? Theme.accent : .clear)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isNow {
                nowLine
            }

            Text(lesson.name.isEmpty ? "Без названия" : lesson.name)
                .font(Theme.rounded(17, .semibold))
                .foregroundColor(isPast ? Theme.textSecondary : .white)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Chip(text: Theme.fullKindName(lesson.kind), style: isNow ? .accent : .quiet)
                if let subgroup = lesson.subgroup, !subgroup.isEmpty {
                    Chip(text: "\(subgroup)-я п/гр", style: .quiet)
                }
            }

            if !meta.isEmpty {
                Text(meta)
                    .font(Theme.rounded(14))
                    .foregroundColor(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let course = lesson.courseURL, let url = URL(string: course) {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "graduationcap.fill")
                        Text("Открыть курс")
                    }
                    .font(Theme.rounded(13, .semibold))
                    .foregroundColor(Theme.accent)
                }
            }

            if !homework.isEmpty {
                HomeworkNote(items: homework)
            }
        }
        .opacity(isPast ? 0.65 : 1)
    }

    /// «Идёт сейчас» с полосой хода пары.
    private var nowLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("Идёт сейчас")
            }
            .font(Theme.rounded(11, .bold))
            .foregroundColor(Theme.accent)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Theme.accent)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 3)
        }
    }

    /// «А312 · Петрова Л. В.» — одной строкой, без значков: строк меньше,
    /// карточка ниже, на экран влезает больше пар.
    private var meta: String {
        var parts: [String] = []
        if let room = lesson.room, !room.isEmpty { parts.append(room) }
        if let teacher = lesson.teacher, !teacher.isEmpty { parts.append(teacher) }
        return parts.joined(separator: " · ")
    }

    private var startTime: String {
        lesson.time.split(separator: "-").first.map(String.init) ?? lesson.time
    }

    private var endTime: String {
        lesson.time.split(separator: "-").last.map(String.init) ?? ""
    }
}
