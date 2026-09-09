import SwiftUI

struct LessonRow: View {
    let lesson: Lesson
    var isNow: Bool = false
    var progress: Double = 0
    /// Домашние задания, которые нужно сдать на этой паре.
    var homework: [Homework] = []

    private var accent: Color { Theme.color(forKind: lesson.kind) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeRail
            details
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .card(tint: isNow ? accent : .clear)
    }

    // MARK: - Левая колонка со временем

    private var timeRail: some View {
        HStack(spacing: 10) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(startTime)
                    .font(Theme.rounded(16, .semibold))
                    .monospacedDigit()
                Text(endTime)
                    .font(Theme.rounded(13))
                    .monospacedDigit()
                    .foregroundColor(Theme.textSecondary)
                if lesson.pairNumber > 0 {
                    Text("\(lesson.pairNumber) пара")
                        .font(Theme.rounded(10, .medium))
                        .foregroundColor(Theme.textSecondary.opacity(0.75))
                        .padding(.top, 1)
                }
            }

            // Полоса-рельс тянется на всю высоту карточки и красит её видом
            // занятия: по одному этому столбику день читается, не вчитываясь.
            Capsule()
                .fill(LinearGradient(colors: [accent, accent.opacity(isNow ? 0.9 : 0.35)],
                                     startPoint: .top, endPoint: .bottom))
                .frame(width: 4)
        }
        .frame(minWidth: 62, alignment: .trailing)
        .fixedSize(horizontal: true, vertical: false)
    }

    // MARK: - Правая колонка

    private var details: some View {
        VStack(alignment: .leading, spacing: 7) {
            if isNow {
                nowBanner
            }

            Text(lesson.name.isEmpty ? "Без названия" : lesson.name)
                .font(Theme.rounded(16, .semibold))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                Pill(text: Theme.fullKindName(lesson.kind),
                     icon: Theme.icon(forKind: lesson.kind), color: accent)
                if let subgroup = lesson.subgroup, !subgroup.isEmpty {
                    Pill(text: "\(subgroup)-я п/гр", icon: "person.2", color: Theme.subgroup)
                }
            }

            if let room = lesson.room, !room.isEmpty {
                label(room, icon: "mappin.and.ellipse")
            }
            if let teacher = lesson.teacher, !teacher.isEmpty {
                label(teacher, icon: "person.crop.circle")
            }
            if let course = lesson.courseURL, let url = URL(string: course) {
                Link(destination: url) {
                    HStack(spacing: 5) {
                        Image(systemName: "graduationcap.fill")
                        Text("Открыть курс")
                    }
                    .font(Theme.rounded(13, .medium))
                }
                .padding(.top, 1)
            }

            if !homework.isEmpty {
                homeworkBlock
            }
        }
    }

    private var nowBanner: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "dot.radiowaves.left.and.right")
                Text("Идёт сейчас")
            }
            .font(Theme.rounded(12, .bold))
            .foregroundColor(accent)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.16))
                    Capsule()
                        .fill(LinearGradient(colors: [accent.opacity(0.65), accent],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 4)
        }
    }

    /// Домашнее задание прямо в карточке пары: ради этого оно и привязано
    /// к занятию, а не просто лежит списком на своей вкладке.
    private var homeworkBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "checklist")
                Text(homework.count == 1 ? "Домашнее задание" : "Домашние задания")
            }
            .font(Theme.rounded(11, .bold))
            .foregroundColor(Theme.homework)

            ForEach(homework) { item in
                HStack(alignment: .top, spacing: 6) {
                    Circle()
                        .fill(Theme.homework)
                        .frame(width: 5, height: 5)
                        .padding(.top, 6)
                    Text(item.text)
                        .font(Theme.rounded(14))
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.homework.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Theme.homework.opacity(0.25), lineWidth: 1)
        )
        .padding(.top, 2)
    }

    // MARK: - Мелочи

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)
            Text(text)
                .font(Theme.rounded(14))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var startTime: String {
        lesson.time.split(separator: "-").first.map(String.init) ?? lesson.time
    }

    private var endTime: String {
        lesson.time.split(separator: "-").last.map(String.init) ?? ""
    }
}
