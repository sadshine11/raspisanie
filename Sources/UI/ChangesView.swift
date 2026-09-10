import SwiftUI

struct ChangesView: View {
    @EnvironmentObject private var store: ScheduleStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScreenHeader(title: "Изменения",
                                 subtitle: "Сверяется с сайтом при каждом открытии") {
                        if store.unseenCount > 0 {
                            Button("Прочитано") { store.markChangesSeen() }
                                .font(Theme.rounded(14, .semibold))
                                .foregroundColor(Theme.accent)
                        }
                    }

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
                .padding(.horizontal, Theme.screenPadding)
                .padding(.bottom, 24)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await store.refresh() }
            .onDisappear { store.markChangesSeen() }
        }
    }

    private func recordSection(_ record: ChangeRecord) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                if !record.isSeen {
                    Circle().fill(Theme.accent).frame(width: 8, height: 8)
                }
                Text(record.detectedAt.checkedAtDescription)
                    .font(Theme.rounded(15, .bold))
                Spacer()
                Text("\(record.changes.count)")
                    .font(Theme.rounded(13, .medium))
                    .foregroundColor(Theme.textSecondary)
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
                    .foregroundColor(Theme.textSecondary)
            }

            if let lesson = change.lesson {
                HStack(alignment: .top, spacing: 8) {
                    Text(lesson.pair)
                        .font(Theme.rounded(12, .semibold))
                        .foregroundColor(Theme.textSecondary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(change.kind == .modified ? (change.after?.name ?? lesson.name) : lesson.name)
                            .font(Theme.rounded(15, .semibold))
                            .foregroundColor(.white)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(lesson.time)
                            .font(Theme.rounded(12))
                            .monospacedDigit()
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if !change.details.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(change.details, id: \.self) { line in
                        Text(line)
                            .font(Theme.rounded(13))
                            .foregroundColor(Theme.textSecondary)
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
        case .added:    return Theme.success
        case .removed:  return Theme.overdue
        case .modified: return Theme.accent
        }
    }
}
