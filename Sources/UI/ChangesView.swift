import SwiftUI

struct ChangesView: View {
    @EnvironmentObject private var store: ScheduleStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    explainer

                    if store.changeLog.isEmpty {
                        EmptyBlock(
                            icon: "checkmark.seal.fill",
                            title: "Изменений не было",
                            message: "Приложение сверяет расписание с сайтом при каждом запуске. Как только учебная часть что-то поправит, здесь появится запись."
                        )
                    } else {
                        ForEach(store.changeLog) { record in
                            recordSection(record)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Изменения")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { await store.refresh() }
            .toolbar {
                if store.unseenCount > 0 {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Прочитано") { store.markChangesSeen() }
                            .font(Theme.rounded(15, .medium))
                    }
                }
            }
            .onDisappear { store.markChangesSeen() }
        }
    }

    private var explainer: some View {
        HStack(spacing: 10) {
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.accentColor)
            Text("Сравнивается с официальным расписанием на сайте при каждом открытии приложения.")
                .font(Theme.rounded(13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.top, 6)
    }

    private func recordSection(_ record: ChangeRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if !record.isSeen {
                    Circle().fill(Color.accentColor).frame(width: 8, height: 8)
                }
                Text(record.detectedAt.checkedAtDescription)
                    .font(Theme.rounded(15, .bold))
                Spacer()
                Text("\(record.changes.count)")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 6)

            ForEach(record.changes) { change in
                changeCard(change)
            }
        }
    }

    private func changeCard(_ change: ScheduleChange) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 7) {
                Image(systemName: change.kind.symbol)
                    .foregroundColor(tint(change.kind))
                Text(change.kind.title)
                    .font(Theme.rounded(13, .bold))
                    .foregroundColor(tint(change.kind))
                Spacer()
                Text("\(change.day) · \(change.weekIndex)-я нед.")
                    .font(Theme.rounded(12, .medium))
                    .foregroundColor(.secondary)
            }

            if let lesson = change.lesson {
                HStack(alignment: .top, spacing: 8) {
                    Text(lesson.pair)
                        .font(Theme.rounded(12, .semibold))
                        .foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(change.kind == .modified ? (change.after?.name ?? lesson.name) : lesson.name)
                            .font(Theme.rounded(15, .semibold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(lesson.time)
                            .font(Theme.rounded(12))
                            .monospacedDigit()
                            .foregroundColor(.secondary)
                    }
                }
            }

            if !change.details.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(change.details, id: \.self) { line in
                        Text(line)
                            .font(Theme.rounded(13))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.cardPadding)
        .card(tint: tint(change.kind))
    }

    private func tint(_ kind: ChangeKind) -> Color {
        switch kind {
        case .added:    return .green
        case .removed:  return .red
        case .modified: return .orange
        }
    }
}
