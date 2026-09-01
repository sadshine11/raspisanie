import Foundation

@MainActor
final class ScheduleStore: ObservableObject {

    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        case failed(String)

        var isLoading: Bool { self == .loading }
        var errorText: String? { if case .failed(let t) = self { return t } else { return nil } }
    }

    @Published private(set) var schedule: Schedule?
    @Published private(set) var changeLog: [ChangeRecord] = []
    @Published private(set) var groups: [GroupRef] = Catalog.groups
    @Published private(set) var semesters: [SemesterRef] = Catalog.semesters
    @Published private(set) var state: LoadState = .idle
    @Published private(set) var lastCheckedAt: Date?
    @Published private(set) var selectedGroup: GroupRef
    @Published var subgroup: String? {
        didSet { Prefs.subgroup = subgroup }
    }

    private let client: ScheduleClient
    private let storage: Storage

    init(client: ScheduleClient = ScheduleClient(), storage: Storage = .shared) {
        self.client = client
        self.storage = storage
        let saved = Catalog.group(id: Prefs.selectedGroupId)
            ?? GroupRef(id: Prefs.selectedGroupId, scheduleId: Prefs.selectedScheduleId,
                        name: "Группа \(Prefs.selectedGroupId)", course: "")
        self.selectedGroup = saved
        self.subgroup = Prefs.subgroup
        self.lastCheckedAt = Prefs.lastCheckedAt
        if let cached: [GroupRef] = storage.load([GroupRef].self, from: Storage.groupsKey), !cached.isEmpty {
            self.groups = cached
        }
        if let cached: [SemesterRef] = storage.load([SemesterRef].self, from: Storage.semestersKey), !cached.isEmpty {
            self.semesters = cached
        }
    }

    // MARK: - Непрочитанные изменения

    var unseenChanges: [ScheduleChange] {
        changeLog.filter { !$0.isSeen }.flatMap(\.changes)
    }

    var unseenCount: Int { unseenChanges.count }

    func markChangesSeen() {
        guard changeLog.contains(where: { !$0.isSeen }) else { return }
        for i in changeLog.indices { changeLog[i].isSeen = true }
        persistChanges()
    }

    // MARK: - Загрузка

    /// Показываем кэш мгновенно, затем идём в сеть.
    func bootstrap() async {
        loadCache()
        await refresh()
        await refreshCatalog()
    }

    func refresh() async {
        guard !state.isLoading else { return }
        state = .loading
        let group = selectedGroup
        do {
            let fresh = try await client.fetchSchedule(scheduleId: group.scheduleId, groupId: group.id)
            apply(fresh, for: group)
            state = .loaded
        } catch {
            state = .failed(friendlyMessage(for: error))
        }
    }

    func select(group: GroupRef) async {
        guard group != selectedGroup else { return }
        selectedGroup = group
        Prefs.selectedGroupId = group.id
        Prefs.selectedScheduleId = group.scheduleId
        schedule = nil
        changeLog = []
        loadCache()
        await refresh()
    }

    /// Обновляет справочник групп в фоне; ошибки здесь не показываем —
    /// встроенного списка достаточно для работы.
    func refreshCatalog() async {
        guard let fetched = try? await client.fetchSemesters(), !fetched.isEmpty else { return }
        semesters = fetched
        storage.save(fetched, to: Storage.semestersKey)

        var all: [GroupRef] = []
        for semester in fetched {
            if let list = try? await client.fetchGroups(scheduleId: semester.id) {
                all.append(contentsOf: list)
            }
        }
        guard !all.isEmpty else { return }
        groups = all
        storage.save(all, to: Storage.groupsKey)
        if let refreshed = all.first(where: { $0.id == selectedGroup.id }) {
            selectedGroup = refreshed
        }
    }

    // MARK: - Внутреннее

    private func loadCache() {
        let key = Storage.scheduleKey(scheduleId: selectedGroup.scheduleId, groupId: selectedGroup.id)
        schedule = storage.load(Schedule.self, from: key)
        let changesKey = Storage.changesKey(scheduleId: selectedGroup.scheduleId, groupId: selectedGroup.id)
        changeLog = storage.load([ChangeRecord].self, from: changesKey) ?? []
    }

    private func apply(_ fresh: Schedule, for group: GroupRef) {
        // Пустой разбор не затирает рабочий кэш: скорее всего сайт отдал заглушку.
        guard fresh.lessonCount > 0 || schedule == nil else {
            lastCheckedAt = Date()
            Prefs.lastCheckedAt = lastCheckedAt
            return
        }

        if let previous = schedule,
           previous.groupId == fresh.groupId,
           previous.scheduleId == fresh.scheduleId {
            let changes = ScheduleDiffer.diff(from: previous, to: fresh)
            if !changes.isEmpty {
                changeLog.insert(ChangeRecord(detectedAt: Date(), changes: changes), at: 0)
                if changeLog.count > 40 { changeLog.removeLast(changeLog.count - 40) }
                persistChanges()
            }
        }

        schedule = fresh
        storage.save(fresh, to: Storage.scheduleKey(scheduleId: group.scheduleId, groupId: group.id))
        lastCheckedAt = Date()
        Prefs.lastCheckedAt = lastCheckedAt
    }

    private func persistChanges() {
        storage.save(changeLog, to: Storage.changesKey(scheduleId: selectedGroup.scheduleId,
                                                       groupId: selectedGroup.id))
    }

    private func friendlyMessage(for error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return "Нет подключения к интернету."
            case .timedOut:               return "Сервер не ответил вовремя."
            case .cannotConnectToHost,
                 .cannotFindHost:         return "Сервер расписания недоступен."
            default:                      return "Сеть недоступна: \(urlError.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}
