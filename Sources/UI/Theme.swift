import SwiftUI

extension Color {
    /// Цвет из 24-битного HEX: `Color(hex: 0x5E5CE6)`.
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
    // Оформление опирается на системное: фон, группы списка, разделители и
    // кегли берутся у iOS. Своими остаются только цвета со смыслом — вид
    // занятия и статус, — и они подобраны не на глаз.
    //
    // Системные зелёный и оранжевый Apple здесь не годятся: на тёмном фоне
    // они выпадают из рабочей полосы светлоты, а при дейтеранопии расходятся
    // всего на ΔE 7,1 при пороге 8 — то есть на полосе дня, где цвет
    // единственный признак, практику и лабораторную не различить.
    // Пересняты на пару, которая проходит проверку с запасом (ΔE 10,9).

    /// Тон приложения — он же цвет лекции.
    ///
    /// Это один цвет намеренно: разводить их в индиго и системный синий
    /// пробовали, но те неразличимы даже при обычном зрении (ΔE 10,5 при
    /// пороге 15).
    static let tint = Color(hex: 0x5E5CE6)

    static let practice = Color(hex: 0x00A878)
    static let lab      = Color(hex: 0xE0620D)

    /// Статусы. Заняты насовсем и не могут достаться виду занятия:
    /// «выполнено» красилось цветом практики — от перекраски практики
    /// менялся бы смысл галочки.
    static let success = Color(hex: 0x00A878)
    static let overdue = Color(hex: 0xFF453A)

    /// Цвет по виду занятия. Лекция — индиго, практика — зелёный,
    /// лаборатория — оранжевый: три вида различимы боковым зрением.
    static func color(forKind kind: String?) -> Color {
        switch kind?.lowercased() {
        case let k? where k.hasPrefix("лек"): return tint
        case let k? where k.hasPrefix("пр"):  return practice
        case let k? where k.hasPrefix("лаб"): return lab
        default:                              return .secondary
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

    /// Ширина колонки со временем — общая у всех списков занятий,
    /// чтобы названия предметов стояли на одной вертикали.
    static let timeColumn: CGFloat = 46

    /// Цветная риска слева от занятия — как в Календаре.
    static let railWidth: CGFloat = 3
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

    /// «пн, 1 сент.» — короткая форма для подписи внутри строки.
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
