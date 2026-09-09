import SwiftUI

struct ChangesView: View {
    @EnvironmentObject private var store: ScheduleStore

    var body: some View {
        NavigationStack {
            List {
                if store.changeLog.isEmpty {
                    Section {
                        EmptyBlock(
                            icon: "checkmark.seal.fill",
                            title: "Изменений не было",
                            message: "Приложение сверяет расписание с сайтом при каждом запуске. Как только учебная часть что-то поправит, здесь появится запись."
                        )
                    } footer: {
                        Text("Сравнивается с официальным расписанием на сайте при каждом открытии приложения.")
                    }
                } else {
                    ForEach(store.changeLog) { record in
                        recordSection(record)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Изменения")
            .refreshable { await store.refresh() }
            .toolbar {
                if store.unseenCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Прочитано") { store.markChangesSeen() }
                    }
                }
            }
            .onDisappear { store.markChangesSeen() }
        }
    }

    private func recordSection(_ record: ChangeRecord) -> some View {
        Section {
            ForEach(record.changes) { change in
                changeRow(change)
            }
        } header: {
            HStack(spacing: 6) {
                if !record.isSeen {
                    Circle().fill(Theme.tint).frame(width: 7, height: 7)
                }
                Text(record.detectedAt.checkedAtDescription)
                Spacer()
                Text("\(record.changes.count)")
            }
        }
    }

    private func changeRow(_ change: ScheduleChange) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: change.kind.symbol)
                .foregroundStyle(tint(change.kind))
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(change.kind.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint(change.kind))
                    Spacer()
                    Text("\(change.day) · \(change.weekIndex)-я нед.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let lesson = change.lesson {
                    Text(change.kind == .modified ? (change.after?.name ?? lesson.name) : lesson.name)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(lesson.pair) · \(lesson.time)")
                        .font(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }

                ForEach(change.details, id: \.self) { line in
                    Text(line)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func tint(_ kind: ChangeKind) -> Color {
        switch kind {
        case .added:    return Theme.success
        case .removed:  return Theme.overdue
        case .modified: return .orange
        }
    }
}
