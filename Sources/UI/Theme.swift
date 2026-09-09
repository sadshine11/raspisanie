import SwiftUI

extension Color {
    /// Цвет из 24-битного HEX: `Color(hex: 0x151A25)`.
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
    // Приложение всегда тёмное (см. `RaspisanieApp`), поэтому фон и карточки
    // заданы явными цветами, а не системными «адаптивными». У системной тёмной
    // темы фон чисто чёрный, а карточка — серая: на OLED-экране карточка висит
    // в пустоте и границы теряются. Здесь фон синевато-чёрный, карточка на
    // ступеньку светлее, и разница видна без обводки — обводка лишь помогает.

    static let background    = Color(hex: 0x090B11)
    static let surface       = Color(hex: 0x151A25)
    static let hairline      = Color.white.opacity(0.07)
    static let textSecondary = Color(hex: 0x98A2B6)

    /// Акцент приложения — он же цвет лекции.
    static let accent = Color(hex: 0x7194FF)

    /// Цвет подгруппы: сиреневый, чтобы не путался с тремя видами занятий.
    static let subgroup = Color(hex: 0xA78BFA)

    /// Цвет домашнего задания: розовый — единственный тон, не занятый
    /// ни видами занятий, ни подгруппой, ни статусами изменений.
    static let homework = Color(hex: 0xF07B9B)

    /// Цвет по виду занятия. Лекция — синий, практика — зелёный,
    /// лаборатория — оранжевый: три вида различимы боковым зрением.
    /// Оттенки подняты по яркости под тёмный фон — насыщенные «дневные»
    /// цвета на чёрном читаются заметно хуже.
    static func color(forKind kind: String?) -> Color {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return accent
        case let k? where k.hasPrefix("пр"):  return Color(hex: 0x3ECF8E)
        case let k? where k.hasPrefix("лаб"): return Color(hex: 0xF5A55C)
        default:                              return textSecondary
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

    // MARK: - Метрика

    static let corner: CGFloat = 18
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

    /// «вторник, 1 сент.»
    var weekdayAndShortRussian: String {
        Date.formatter { $0.dateFormat = "EEEE, d MMM" }.string(from: self)
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

// MARK: - Фон экрана

/// Общий фон всех экранов: глубокий синий-чёрный с мягким свечением акцента
/// в верхнем углу. Свечение неподвижно и не скроллится вместе с содержимым —
/// оно задаёт «верх» экрана и не даёт списку карточек выглядеть плоским.
struct ScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content.background(
            ZStack {
                Theme.background
                RadialGradient(
                    colors: [Theme.accent.opacity(0.17), Theme.accent.opacity(0)],
                    center: UnitPoint(x: 0.08, y: -0.02),
                    startRadius: 0,
                    endRadius: 480
                )
            }
            .ignoresSafeArea()
        )
    }
}

/// Мягкая карточка с фоном, одинаковая во всём приложении.
///
/// Подсвеченная карточка (идущая пара, изменение, домашнее задание)
/// дополнительно заливается диагональным градиентом своего цвета и получает
/// цветную обводку: плоская заливка на тёмном фоне выглядит грязным пятном,
/// градиент — подсветкой.
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
                            .fill(LinearGradient(
                                colors: [tint.opacity(isTinted ? 0.18 : 0),
                                         tint.opacity(isTinted ? 0.04 : 0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                    )
                    .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                    .strokeBorder(isTinted ? tint.opacity(0.34) : Theme.hairline,
                                  lineWidth: 1)
            )
    }
}

extension View {
    func card(tint: Color = .clear) -> some View { modifier(CardBackground(tint: tint)) }
    func screenBackground() -> some View { modifier(ScreenBackground()) }
}

// MARK: - Мелкие детали оформления

/// Капсула-подпись: «1-я неделя», «Лекция», «2-я п/гр».
struct Pill: View {
    let text: String
    var icon: String? = nil
    var color: Color = Theme.accent
    var size: CGFloat = 12

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: size - 1, weight: .semibold))
            }
            Text(text)
        }
        .font(Theme.rounded(size, .semibold))
        .foregroundColor(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.14)))
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 1))
    }
}
