import SwiftUI

struct LessonRow: View {
    let lesson: Lesson
    var isNow: Bool = false
    var progress: Double = 0
    var changeKind: ChangeKind? = nil

    private var accent: Color { Theme.color(forKind: lesson.kind) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timeRail
            details
            Spacer(minLength: 0)
        }
        .padding(Theme.cardPadding)
        .card(tint: isNow ? accent : .clear)
        .overlay(alignment: .topTrailing) {
            if let changeKind {
                Image(systemName: changeKind.symbol)
                    .font(.system(size: 15))
                    .foregroundColor(color(for: changeKind))
                    .padding(8)
            }
        }
    }

    // MARK: - Левая колонка со временем

    private var timeRail: some View {
        HStack(spacing: 10) {
            Capsule()
                .fill(accent.opacity(isNow ? 1 : 0.55))
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text(startTime)
                    .font(Theme.rounded(16, .semibold))
                    .monospacedDigit()
                Text(endTime)
                    .font(Theme.rounded(13))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
        .frame(minWidth: 62, alignment: .leading)
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
                badge(Theme.fullKindName(lesson.kind), icon: Theme.icon(forKind: lesson.kind), color: accent)
                if let subgroup = lesson.subgroup, !subgroup.isEmpty {
                    badge("\(subgroup)-я п/гр", icon: "person.2", color: .purple)
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
                    Capsule().fill(accent)
                        .frame(width: max(4, geo.size.width * progress))
                }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Мелочи

    private func badge(_ text: String, icon: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(Theme.rounded(12, .semibold))
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.13)))
    }

    private func label(_ text: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(text)
                .font(Theme.rounded(14))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func color(for kind: ChangeKind) -> Color {
        switch kind {
        case .added:    return .green
        case .removed:  return .red
        case .modified: return .orange
        }
    }

    private var startTime: String {
        lesson.time.split(separator: "-").first.map(String.init) ?? lesson.time
    }

    private var endTime: String {
        lesson.time.split(separator: "-").last.map(String.init) ?? ""
    }
}
