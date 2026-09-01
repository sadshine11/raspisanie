import Foundation

struct GroupRef: Codable, Hashable, Identifiable {
    var id: Int             // id_edu_group
    var scheduleId: Int     // id_schedule
    var name: String        // «56-1 (ХБ 26-01)»
    var course: String      // «1-й курс»

    /// Короткий код без скобок — для заголовков.
    var shortName: String {
        name.split(separator: "(").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? name
    }
}

struct SemesterRef: Codable, Hashable, Identifiable {
    var id: Int             // id_schedule
    var title: String
}

enum NetworkError: LocalizedError {
    case badStatus(Int)
    case undecodable
    case badURL

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Сервер ответил с кодом \(code)."
        case .undecodable:         return "Не удалось прочитать ответ сервера."
        case .badURL:              return "Некорректный адрес запроса."
        }
    }
}

/// Клиент сайта расписания.
///
/// Сервер работает по обычному HTTP (не HTTPS) — на IP-адресе с портом 7085,
/// поэтому в Info.plist включено исключение App Transport Security.
struct ScheduleClient {

    static let host = "89.249.130.60"
    static let port = 7085
    static var baseURLString: String { "http://\(host):\(port)" }

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 15
            config.timeoutIntervalForResource = 30
            config.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Запросы

    func fetchSchedule(scheduleId: Int, groupId: Int) async throws -> Schedule {
        let html = try await get("/viewer/edu-group-schedule",
                                 query: ["id_schedule": "\(scheduleId)", "id_edu_group": "\(groupId)"])
        return try ScheduleParser.parse(html: html, scheduleId: scheduleId, groupId: groupId)
    }

    func fetchSemesters() async throws -> [SemesterRef] {
        let html = try await get("/viewer/index")
        let source = html as NSString
        let whole = NSRange(location: 0, length: source.length)
        var seen = Set<Int>()
        var out: [SemesterRef] = []
        for m in Rx.semesterLink.allMatches(in: source, range: whole) {
            guard let idText = m.groups[1], let id = Int(idText),
                  let title = m.groups[2].map(ScheduleParser.strip), !title.isEmpty,
                  seen.insert(id).inserted else { continue }
            out.append(SemesterRef(id: id, title: title))
        }
        return out
    }

    /// Список групп семестра. Сайт разбивает его на страницы по 20 записей,
    /// поэтому идём по страницам, пока появляются новые группы.
    func fetchGroups(scheduleId: Int, maxPages: Int = 10) async throws -> [GroupRef] {
        var out: [GroupRef] = []
        var seen = Set<Int>()

        for page in 1...maxPages {
            let html = try await get("/viewer/edu-group-list/\(scheduleId)", query: ["page": "\(page)"])
            let source = html as NSString
            let whole = NSRange(location: 0, length: source.length)

            var addedOnThisPage = 0
            for m in Rx.groupLink.allMatches(in: source, range: whole) {
                guard let idText = m.groups[1], let id = Int(idText),
                      let name = m.groups[2].map(ScheduleParser.strip), !name.isEmpty,
                      seen.insert(id).inserted else { continue }
                let course = m.groups[3].map(ScheduleParser.strip) ?? ""
                out.append(GroupRef(id: id, scheduleId: scheduleId, name: name, course: course))
                addedOnThisPage += 1
            }
            if addedOnThisPage == 0 { break }
        }
        return out
    }

    // MARK: - Транспорт

    private func get(_ path: String, query: [String: String] = [:]) async throws -> String {
        guard var components = URLComponents(string: Self.baseURLString + path) else {
            throw NetworkError.badURL
        }
        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
                .sorted { $0.name < $1.name }
        }
        guard let url = components.url else { throw NetworkError.badURL }

        var request = URLRequest(url: url)
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NetworkError.badStatus(http.statusCode)
        }
        // Сервер отдаёт UTF-8; windows-1251 оставлен запасным вариантом.
        if let text = String(data: data, encoding: .utf8) { return text }
        if let text = String(data: data, encoding: .windowsCP1251) { return text }
        throw NetworkError.undecodable
    }
}

private extension String.Encoding {
    static let windowsCP1251 = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.windowsCyrillic.rawValue))
    )
}
