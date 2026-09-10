import SwiftUI

extension Color {
    /// Цвет из 24-битного HEX: `Color(hex: 0x17181A)`.
    init(hex: UInt32) {
        self.init(.sRGB,
                  red:     Double((hex >> 16) & 0xFF) / 255,
                  green:   Double((hex >> 8)  & 0xFF) / 255,
                  blue:    Double( hex        & 0xFF) / 255,
                  opacity: 1)
    }
}

enum Theme {

    // MARK: - Палитра
    //
    // Почти монохром и один тёплый акцент. Цветом отмечается только то, на
    // что смотрят: идущая пара, счётчики, выбранный чип. Раньше цвет нёс вид
    // занятия — получалось шесть оттенков на экране, и ни один не выделялся.
    // Теперь вид занятия написан словом, а янтарь остаётся единственным.

    static let background    = Color(hex: 0x0A0A0B)
    static let surface       = Color(hex: 0x17181A)
    /// Блок внутри карточки — время, коэффициент, счётчик.
    static let surfaceRaised = Color(hex: 0x232427)
    static let hairline      = Color.white.opacity(0.06)
    static let textSecondary = Color(hex: 0x8E9198)

    /// Акцент — тёплый янтарь. Текст на нём почти чёрный.
    static let accent   = Color(hex: 0xFFC72C)
    static let onAccent = Color(hex: 0x0A0A0B)

    /// Вид занятия и подгруппа. Подобраны валидатором под тёмную подложку:
    /// все пары различимы при обычном зрении с запасом (худшая ΔE 19,1).
    /// Синий и сиреневый сливаются у протанопов — с этим живём осознанно,
    /// потому что рядом с цветом всегда стоит слово: «Лекция», «2-я п/гр».
    static let lecture  = Color(hex: 0x2E86FF)
    static let practice = Color(hex: 0x00A878)
    static let lab      = Color(hex: 0xE0620D)
    static let subgroup = Color(hex: 0xB95BE8)

    /// Цвет по виду занятия.
    static func color(forKind kind: String?) -> Color {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return lecture
        case let k? where k.hasPrefix("пр"):  return practice
        case let k? where k.hasPrefix("лаб"): return lab
        default:                              return textSecondary
        }
    }

    /// Статусы. Заняты насовсем и не могут достаться ничему другому.
    static let success = Color(hex: 0x3ECF8E)
    static let overdue = Color(hex: 0xFF453A)

    static func fullKindName(_ kind: String?) -> String {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return "Лекция"
        case let k? where k.hasPrefix("пр"):  return "Практика"
        case let k? where k.hasPrefix("лаб"): return "Лабораторная"
        default:                              return kind ?? "Занятие"
        }
    }

    // MARK: - Метрика

    static let corner: CGFloat = 16
    static let blockCorner: CGFloat = 12
    static let cardPadding: CGFloat = 14
    static let screenPadding: CGFloat = 14

    /// Обычный гротеск, не скруглённый: скруглённый шрифт делает интерфейс
    /// «мягким», а здесь нужен плотный список, который сканируют.
    static func rounded(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
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

    /// «1 сентября»
    var dayAndMonthRussian: String {
        Date.formatter { $0.dateFormat = "d MMMM" }.string(from: self)
    }

    /// «1 сент.»
    var shortRussian: String {
        Date.formatter { $0.dateFormat = "d MMM" }.string(from: self)
    }

    /// «вторник, 1 сент.»
    var weekdayAndShortRussian: String {
        Date.formatter { $0.dateFormat = "EEEE, d MMM" }.string(from: self)
    }

    /// «пн, 1 сент.» — короткая форма для подписи внутри карточки.
    var shortWeekdayAndShortRussian: String {
        Date.formatter { $0.dateFormat = "E, d MMM" }.string(from: self)
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

extension String {
    var capitalizedFirst: String {
        guard let first else { return self }
        return first.uppercased() + dropFirst()
    }
}

// MARK: - Фон экрана

/// Почти чёрный фон с тёплым свечением вверху — оно и задаёт «верх» экрана,
/// раз собственной панели навигации у экранов больше нет.
struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                Theme.background
                RadialGradient(
                    colors: [Theme.accent.opacity(0.20), Theme.accent.opacity(0)],
                    center: UnitPoint(x: 0.5, y: -0.04),
                    startRadius: 0,
                    endRadius: 360
                )
            }
            .ignoresSafeArea()
        )
    }
}

/// Тёмная плашка. Границ нет намеренно: блоки отделяются друг от друга
/// отступами, как в приложениях, на которые это списано.
struct CardBackground: ViewModifier {
    var tint: Color = .clear

    private var isTinted: Bool { tint != .clear }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                            .fill(tint.opacity(isTinted ? 0.12 : 0))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(isTinted ? tint.opacity(0.45) : Color.clear, lineWidth: 1)
            )
    }
}

extension View {
    func card(tint: Color = .clear) -> some View { modifier(CardBackground(tint: tint)) }
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}
