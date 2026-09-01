import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ScheduleStore

    var body: some View {
        NavigationStack {
            List {
                groupSection
                subgroupSection
                dataSection
                sourceSection
                aboutSection
            }
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Группа

    private var groupSection: some View {
        Section {
            NavigationLink {
                GroupPicker()
            } label: {
                HStack {
                    Label("Группа", systemImage: "person.3.fill")
                    Spacer()
                    Text(store.selectedGroup.name)
                        .foregroundColor(.secondary)
                }
            }
        } footer: {
            if !store.selectedGroup.course.isEmpty {
                Text(store.selectedGroup.course)
            }
        }
    }

    // MARK: - Подгруппа

    private var subgroupSection: some View {
        Group {
            if let schedule = store.schedule {
                let available = Planner.availableSubgroups(in: schedule)
                if !available.isEmpty {
                    Section {
                        Picker(selection: Binding(
                            get: { store.subgroup ?? "" },
                            set: { store.subgroup = $0.isEmpty ? nil : $0 }
                        )) {
                            Text("Показывать все").tag("")
                            ForEach(available, id: \.self) { value in
                                Text("\(value)-я подгруппа").tag(value)
                            }
                        } label: {
                            Label("Подгруппа", systemImage: "person.2.fill")
                        }
                    } footer: {
                        Text("Занятия всей группы показываются всегда. Выбор влияет только на занятия, разделённые по подгруппам.")
                    }
                }
            }
        }
    }

    // MARK: - Данные

    private var dataSection: some View {
        Section("Данные") {
            if let schedule = store.schedule {
                LabeledContent("Семестр", value: schedule.semester.isEmpty ? "—" : schedule.semester)
                LabeledContent("Занятий в сетке", value: "\(schedule.lessonCount)")
                LabeledContent("Текущая неделя", value: "\(schedule.currentWeekIndex)-я")
            }
            if let checked = store.lastCheckedAt {
                LabeledContent("Последняя сверка", value: checked.checkedAtDescription)
            }
            Button {
                Task { await store.refresh() }
            } label: {
                Label(store.state.isLoading ? "Проверяем…" : "Проверить сейчас",
                      systemImage: "arrow.clockwise")
            }
            .disabled(store.state.isLoading)
        }
    }

    // MARK: - Источник

    private var sourceSection: some View {
        Section {
            if let url = URL(string: "\(ScheduleClient.baseURLString)/viewer/edu-group-schedule?id_schedule=\(store.selectedGroup.scheduleId)&id_edu_group=\(store.selectedGroup.id)") {
                Link(destination: url) {
                    Label("Открыть официальную страницу", systemImage: "safari")
                }
            }
        } header: {
            Text("Источник")
        } footer: {
            Text("Данные берутся напрямую с сайта расписания \(ScheduleClient.host):\(String(ScheduleClient.port)). Приложение ничего не меняет на сервере и не требует входа.")
        }
    }

    // MARK: - О приложении

    private var aboutSection: some View {
        Section {
            LabeledContent("Версия", value: Bundle.main.appVersion)
        } footer: {
            Text("Приложение подписано вашим сертификатом. Если оно перестало запускаться, сертификат отозвали: переподпишите тот же файл заново — пересобирать ничего не нужно.")
        }
    }
}

// MARK: - Выбор группы

struct GroupPicker: View {
    @EnvironmentObject private var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var sections: [(semester: SemesterRef, groups: [GroupRef])] {
        store.semesters.compactMap { semester in
            let matching = store.groups
                .filter { $0.scheduleId == semester.id }
                .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) }
                .sorted { $0.name < $1.name }
            return matching.isEmpty ? nil : (semester, matching)
        }
    }

    var body: some View {
        List {
            ForEach(sections, id: \.semester.id) { section in
                Section(section.semester.title) {
                    ForEach(section.groups) { group in
                        Button {
                            Task {
                                await store.select(group: group)
                                dismiss()
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(group.name).foregroundColor(.primary)
                                    if !group.course.isEmpty {
                                        Text(group.course)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                if group.id == store.selectedGroup.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.accentColor)
                                }
                            }
                        }
                    }
                }
            }
        }
        .searchable(text: $query, prompt: "Номер или шифр группы")
        .navigationTitle("Выбор группы")
        .navigationBarTitleDisplayMode(.inline)
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
