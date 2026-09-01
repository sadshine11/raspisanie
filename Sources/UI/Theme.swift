import SwiftUI

enum Theme {

    /// Цвет по виду занятия. Лекция — синий, практика — зелёный,
    /// лаборатория — оранжевый: три вида различимы боковым зрением.
    /// Оттенки подняты по яркости под тёмный фон — насыщенные «дневные»
    /// цвета на чёрном читаются заметно хуже.
    static func color(forKind kind: String?) -> Color {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return Color(red: 0.443, green: 0.580, blue: 1.000)
        case let k? where k.hasPrefix("пр"):  return Color(red: 0.243, green: 0.812, blue: 0.557)
        case let k? where k.hasPrefix("лаб"): return Color(red: 0.961, green: 0.647, blue: 0.361)
        default:                              return Color.secondary
        }
    }

    /// Акцент приложения — он же цвет лекции.
    static let accent = Color(red: 0.443, green: 0.580, blue: 1.000)

    /// Цвет подгруппы: сиреневый, чтобы не путался с тремя видами занятий.
    static let subgroup = Color(red: 0.655, green: 0.545, blue: 0.980)

    static func fullKindName(_ kind: String?) -> String {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return "Лекция"
        case let k? where k.hasPrefix("пр"):  return "Практика"
        case let k? where k.hasPrefix("лаб"): return "Лабораторная"
        default:                              return kind ?? "Занятие"
        }
    }

    static func icon(forKind kind: String?) -> String {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return "person.fill.viewfinder"
        case let k? where k.hasPrefix("пр"):  return "pencil.and.ruler"
        case let k? where k.hasPrefix("лаб"): return "flask"
        default:                              return "book"
        }
    }

    static let corner: CGFloat = 16
    static let cardPadding: CGFloat = 14

    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

extension Date {
    /// Все даты и время показываются по красноярскому времени — тому же,
    /// в котором составлено расписание. См. `Planner.timeZone`.
    private static func formatter(_ configure: (DateFormatter) -> Void) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.timeZone = Planner.timeZone
        configure(f)
        return f
    }

    /// «1 сентября, вторник»
    var longRussian: String {
        Date.formatter { $0.dateFormat = "d MMMM, EEEE" }.string(from: self)
    }

    /// «1 сент.»
    var shortRussian: String {
        Date.formatter { $0.dateFormat = "d MMM" }.string(from: self)
    }

    /// «сегодня в 13:49» / «вчера в 20:10» / «28 авг. в 09:03»
    var checkedAtDescription: String {
        Date.formatter {
            $0.doesRelativeDateFormatting = true
            $0.dateStyle = .medium
            $0.timeStyle = .short
        }.string(from: self)
    }
}

/// Мягкая карточка с фоном, одинаковая во всём приложении.
///
/// На чёрном фоне тёмной темы карточка сливается по краям, поэтому у неё
/// всегда есть еле заметная светлая граница. Подсвеченная карточка (идущая
/// пара, изменение) дополнительно заливается своим цветом.
struct CardBackground: ViewModifier {
    var tint: Color = .clear

    private var isTinted: Bool { tint != .clear }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .fill(tint.opacity(0.10))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(isTinted ? tint.opacity(0.32) : Color.white.opacity(0.06),
                                  lineWidth: 1)
            )
    }
}

extension View {
    func card(tint: Color = .clear) -> some View { modifier(CardBackground(tint: tint)) }
}
