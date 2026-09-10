import SwiftUI

// Общие детали оформления: заголовок экрана, чипы, блок времени и шапка
// раздела. Всё это списано с приложений, на которые ориентировались:
// крупный заголовок в самом содержимом (своей панели навигации у экранов
// нет), фильтры чипами под ним, содержимое — тёмными плашками без границ.

/// Заголовок экрана: крупное название, подпись под ним и место справа.
struct ScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.rounded(28, .bold))
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.rounded(14))
                        .foregroundColor(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            trailing
        }
        .padding(.top, 6)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil) {
        self.init(title: title, subtitle: subtitle) { EmptyView() }
    }
}

/// Чип-подпись и он же чип-фильтр.
///
/// Выбранный — белая пилюля с тёмным текстом: так он читается сразу и не
/// тратит акцентный цвет, который нужен идущей паре.
struct Chip: View {
    enum Style {
        case quiet      // подпись внутри карточки
        case accent     // янтарь: что-то происходит сейчас
        case solid      // выбранный фильтр
    }

    let text: String
    var icon: String? = nil
    var style: Style = .quiet
    var size: CGFloat = 12

    private var foreground: Color {
        switch style {
        case .quiet:  return Theme.textSecondary
        case .accent: return Theme.accent
        case .solid:  return Theme.onAccent
        }
    }

    private var background: Color {
        switch style {
        case .quiet:  return Color.white.opacity(0.08)
        case .accent: return Theme.accent.opacity(0.16)
        case .solid:  return .white
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon).font(.system(size: size - 1, weight: .semibold))
            }
            Text(text)
        }
        .font(Theme.rounded(size, .semibold))
        .foregroundColor(foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(background))
    }
}

/// Блок со временем пары — то, ради чего в этот список вообще смотрят,
/// поэтому он вынесен отдельной плашкой к правому краю карточки.
struct TimeBlock: View {
    let start: String
    let end: String
    var isNow: Bool = false
    var isPast: Bool = false

    var body: some View {
        VStack(spacing: 1) {
            Text(start)
                .font(Theme.rounded(17, .semibold))
                .monospacedDigit()
                .foregroundColor(isNow ? Theme.onAccent : (isPast ? Theme.textSecondary : .white))
            Text(end)
                .font(Theme.rounded(13))
                .monospacedDigit()
                .foregroundColor(isNow ? Theme.onAccent.opacity(0.65) : Theme.textSecondary)
        }
        .frame(width: 62)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.blockCorner, style: .continuous)
                .fill(isNow ? Theme.accent : Theme.surfaceRaised)
        )
        .opacity(isPast ? 0.55 : 1)
    }
}

/// Шапка раздела отдельной плашкой — как заголовок турнира в списке матчей.
/// Если передан `onTap`, справа появляется шеврон и плашка сворачивает раздел.
struct SectionBlock: View {
    let title: String
    var detail: String? = nil
    var badge: String? = nil
    var isExpanded: Bool = true
    var onTap: (() -> Void)? = nil

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) { content }.buttonStyle(.plain)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(Theme.rounded(16, .semibold))
                .foregroundColor(.white)
            if let detail {
                Text(detail)
                    .font(Theme.rounded(14))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            if let badge {
                Text(badge)
                    .font(Theme.rounded(13, .semibold))
                    .monospacedDigit()
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            if onTap != nil {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 180 : 0))
            }
        }
        .padding(.horizontal, Theme.cardPadding)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.corner, style: .continuous)
                .fill(Theme.surface)
        )
    }
}

/// Домашнее задание внутри карточки пары — вложенная плашка, а не цветная
/// рамка: цвет на экране один, и он занят идущей парой.
struct HomeworkNote: View {
    let items: [Homework]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "checklist")
                Text(items.count == 1 ? "Домашнее задание" : "Домашние задания")
            }
            .font(Theme.rounded(11, .bold))
            .foregroundColor(Theme.accent)

            ForEach(items) { item in
                Text(item.text)
                    .font(Theme.rounded(14))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: Theme.blockCorner, style: .continuous)
                .fill(Theme.surfaceRaised)
        )
    }
}
