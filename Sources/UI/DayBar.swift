import SwiftUI

/// Полоса дня: пары отрезками на шкале с 8 до 18, риска — текущий момент.
///
/// Единственный нарисованный элемент во всём приложении. Список отвечает на
/// вопрос «что дальше», а полоса — на «сколько ещё сегодня и где окна»:
/// промежутки между парами видно как настоящие пустоты, а не как одинаковые
/// зазоры между строками.
struct DayBar: View {
    let lessons: [Lesson]
    let now: Date

    private static let dayStart = 8 * 60
    private static let dayEnd = 18 * 60
    private static let barHeight: CGFloat = 8

    /// Доля 0…1 от начала шкалы. За краями обрезается, чтобы ранняя пара
    /// или поздний вечер не уехали за пределы полосы.
    private static func fraction(of minutes: Int) -> Double {
        let span = Double(dayEnd - dayStart)
        return min(max(Double(minutes - dayStart) / span, 0), 1)
    }

    private var nowFraction: Double? {
        let minutes = Planner.minutesSinceMidnight(now)
        guard minutes >= Self.dayStart, minutes <= Self.dayEnd else { return nil }
        return Self.fraction(of: minutes)
    }

    private struct Segment: Identifiable {
        var id: String
        var start: Double
        var width: Double
        var color: Color
        var isPast: Bool
    }

    private var segments: [Segment] {
        let minutesNow = Planner.minutesSinceMidnight(now)
        return lessons.compactMap { lesson in
            guard let start = lesson.startMinutes, let end = lesson.endMinutes, end > start else { return nil }
            let from = Self.fraction(of: start)
            let to = Self.fraction(of: end)
            guard to > from else { return nil }
            return Segment(id: lesson.id,
                           start: from,
                           width: to - from,
                           color: Theme.color(forKind: lesson.kind),
                           isPast: end <= minutesNow)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.tertiarySystemFill))

                    ForEach(segments) { segment in
                        Capsule()
                            .fill(segment.color)
                            .opacity(segment.isPast ? 0.4 : 1)
                            .frame(width: max(2, geo.size.width * segment.width))
                            .offset(x: geo.size.width * segment.start)
                    }

                    if let nowFraction {
                        // Риска лежит поверх заливки, поэтому её отделяет
                        // кольцо цвета подложки, а не обводка вокруг отрезков.
                        Capsule()
                            .fill(Color(.systemBackground))
                            .frame(width: 6, height: Self.barHeight + 8)
                            .overlay(
                                Capsule()
                                    .fill(Color(.label))
                                    .frame(width: 2, height: Self.barHeight + 8)
                            )
                            .offset(x: max(0, geo.size.width * nowFraction - 3))
                    }
                }
            }
            .frame(height: Self.barHeight)
            .padding(.vertical, 4)

            HStack(spacing: 0) {
                ForEach([8, 10, 12, 14, 16], id: \.self) { hour in
                    Text("\(hour)")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("18")
            }
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(.tertiary)
        }
        .accessibilityElement()
        .accessibilityLabel("Полоса дня")
        .accessibilityValue("Занятий: \(lessons.count)")
    }
}
