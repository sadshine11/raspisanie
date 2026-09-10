import SwiftUI

/// Быстрое переключение подгруппы прямо на экране расписания.
///
/// Настройка есть и в «Настройках», но она нужна почти каждый день —
/// прятать её на пятую вкладку было бы неудобно.
/// Показывается только там, где подгруппы вообще есть.
struct SubgroupPicker: View {
    @EnvironmentObject private var store: ScheduleStore
    let available: [String]

    var body: some View {
        HStack(spacing: 8) {
            chip(title: "Все", value: nil)
            ForEach(available, id: \.self) { value in
                chip(title: "\(value)-я подгруппа", value: value)
            }
            Spacer(minLength: 0)
        }
    }

    private func chip(title: String, value: String?) -> some View {
        let isSelected = store.subgroup == value
        return Button {
            store.subgroup = value
        } label: {
            Chip(text: title, style: isSelected ? .solid : .quiet, size: 13)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(value == nil ? "Показывать все подгруппы" : "\(value ?? "")-я подгруппа")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}
