import Foundation

/// Простое файловое хранилище JSON в Application Support.
/// Каждая группа хранится отдельно, чтобы при смене группы
/// сравнение не путало расписания разных групп между собой.
struct Storage {

    static let shared = Storage()

    private let root: URL
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.withoutEscapingSlashes]
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    /// Папку задают только тесты: иначе они писали бы в настоящие
    /// данные пользователя в Application Support.
    init(directory: URL? = nil) {
        if let directory {
            root = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            root = base.appendingPathComponent("Raspisanie", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(for: name)) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: url(for: name), options: .atomic)
    }

    func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(for: name))
    }

    private func url(for name: String) -> URL {
        root.appendingPathComponent("\(name).json")
    }

    // MARK: - Имена файлов

    static func scheduleKey(scheduleId: Int, groupId: Int) -> String { "schedule_\(scheduleId)_\(groupId)" }
    static func changesKey(scheduleId: Int, groupId: Int) -> String { "changes_\(scheduleId)_\(groupId)" }
    static let groupsKey = "groups"
    /// Домашние задания не привязаны к группе: список принадлежит человеку,
    /// а не сетке расписания, и переживает переключение группы.
    static let homeworkKey = "homework"
    static let semestersKey = "semesters"
}

/// Настройки, которые переживают перезапуск.
enum Prefs {
    private static let defaults = UserDefaults.standard

    static var selectedGroupId: Int {
        get { defaults.object(forKey: "selectedGroupId") as? Int ?? Catalog.defaultGroup.id }
        set { defaults.set(newValue, forKey: "selectedGroupId") }
    }

    static var selectedScheduleId: Int {
        get { defaults.object(forKey: "selectedScheduleId") as? Int ?? Catalog.defaultGroup.scheduleId }
        set { defaults.set(newValue, forKey: "selectedScheduleId") }
    }

    /// Подгруппа пользователя: nil — показывать все.
    ///
    /// По умолчанию — 2-я. Пустая строка в хранилище означает осознанный выбор
    /// «показывать все»: без неё нельзя было бы отличить его от «ещё ни разу
    /// не выбирал», и настройка каждый раз возвращалась бы к умолчанию.
    static let defaultSubgroup = "2"

    static var subgroup: String? {
        get {
            guard let raw = defaults.string(forKey: "subgroup") else { return defaultSubgroup }
            return raw.isEmpty ? nil : raw
        }
        set { defaults.set(newValue ?? "", forKey: "subgroup") }
    }

    static var lastCheckedAt: Date? {
        get { defaults.object(forKey: "lastCheckedAt") as? Date }
        set { defaults.set(newValue, forKey: "lastCheckedAt") }
    }
}
