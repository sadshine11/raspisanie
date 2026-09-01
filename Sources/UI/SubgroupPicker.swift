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
                .foregroundColor(.secondary)

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
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(isSelected
                                   ? Theme.subgroup
                                   : Color(.secondarySystemGroupedBackground))
                )
                .overlay(
                    Capsule().strokeBorder(Color.white.opacity(isSelected ? 0 : 0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == nil ? "Показывать все подгруппы" : "\(value ?? "")-я подгруппа")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
