import SwiftUI

/// Быстрое переключение подгруппы прямо на экране расписания.
///
/// Настройка есть и в «Настройках», но она нужна почти каждый день —
/// прятать её на четвёртую вкладку было бы неудобно.
/// Показывается только там, где подгруппы вообще есть.
struct SubgroupPicker: View {
    @EnvironmentObject private var store: ScheduleStore
    let available: [String]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12))
                .foregroundColor(Theme.textSecondary)

            chip(title: "Все", value: nil)
            ForEach(available, id: \.self) { value in
                chip(title: "\(value)-я", value: value)
            }

            Spacer(minLength: 0)
        }
    }

    private func chip(title: String, value: String?) -> some View {
        let isSelected = store.subgroup == value
        return Button {
            store.subgroup = value
        } label: {
            Text(title)
                .font(Theme.rounded(13, .semibold))
                .foregroundColor(isSelected ? .white : Theme.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected
                                   ? AnyShapeStyle(LinearGradient(
                                        colors: [Theme.subgroup, Theme.subgroup.opacity(0.75)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                   : AnyShapeStyle(Theme.surface))
                )
                .overlay(
                    Capsule().strokeBorder(isSelected ? Color.clear : Theme.hairline, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == nil ? "Показывать все подгруппы" : "\(value ?? "")-я подгруппа")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
