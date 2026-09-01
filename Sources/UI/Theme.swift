import SwiftUI

enum Theme {

    /// Цвет по виду занятия. Лекция — спокойный синий, практика — зелёный,
    /// лаборатория — оранжевый: три вида различимы боковым зрением.
    static func color(forKind kind: String?) -> Color {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return Color(red: 0.29, green: 0.45, blue: 0.94)
        case let k? where k.hasPrefix("пр"):  return Color(red: 0.16, green: 0.66, blue: 0.42)
        case let k? where k.hasPrefix("лаб"): return Color(red: 0.94, green: 0.55, blue: 0.18)
        default:                              return Color.secondary
        }
    }

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
    /// «1 сентября, вторник»
    var longRussian: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM, EEEE"
        return f.string(from: self)
    }

    /// «1 сент.»
    var shortRussian: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMM"
        return f.string(from: self)
    }

    /// «сегодня в 13:49» / «вчера в 20:10» / «28 авг. в 09:03»
    var checkedAtDescription: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.doesRelativeDateFormatting = true
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: self)
    }
}

/// Мягкая карточка с фоном, одинаковая во всём приложении.
struct CardBackground: ViewModifier {
    var tint: Color = .clear

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(tint.opacity(0.22), lineWidth: tint == .clear ? 0 : 1)
            )
    }
}

extension View {
    func card(tint: Color = .clear) -> some View { modifier(CardBackground(tint: tint)) }
}
