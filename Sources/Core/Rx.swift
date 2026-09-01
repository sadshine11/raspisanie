import Foundation

/// Безопасный доступ по индексу: если разметка на сайте изменится и группа
/// пропадёт, парсер вернёт nil вместо падения приложения.
struct RxGroups {
    private let values: [String?]
    init(_ values: [String?]) { self.values = values }
    subscript(index: Int) -> String? {
        index >= 0 && index < values.count ? values[index] : nil
    }
}

struct RxRanges {
    private let values: [NSRange?]
    init(_ values: [NSRange?]) { self.values = values }
    subscript(index: Int) -> NSRange? {
        index >= 0 && index < values.count ? values[index] : nil
    }
}

struct RxMatch {
    let range: NSRange
    let groups: RxGroups
    let groupRanges: RxRanges
}

/// Тонкая обёртка над NSRegularExpression, чтобы разбор читался
/// так же, как проверенный прототип на JS.
struct Rx {
    private let re: NSRegularExpression

    init(_ pattern: String) {
        // Шаблоны заданы в коде и не приходят извне: ошибка здесь — опечатка разработчика.
        guard let compiled = try? NSRegularExpression(pattern: pattern) else {
            preconditionFailure("Некорректное регулярное выражение: \(pattern)")
        }
        re = compiled
    }

    func allMatches(in source: NSString, range: NSRange) -> [RxMatch] {
        guard range.length > 0, NSMaxRange(range) <= source.length else { return [] }
        return re.matches(in: source as String, range: range).map { m in
            var groups: [String?] = []
            var ranges: [NSRange?] = []
            for i in 0..<m.numberOfRanges {
                let r = m.range(at: i)
                if r.location == NSNotFound {
                    groups.append(nil)
                    ranges.append(nil)
                } else {
                    groups.append(source.substring(with: r))
                    ranges.append(r)
                }
            }
            return RxMatch(range: m.range, groups: RxGroups(groups), groupRanges: RxRanges(ranges))
        }
    }

    func firstGroups(in source: NSString, range: NSRange) -> RxGroups? {
        allMatches(in: source, range: range).first?.groups
    }

    func replacingMatches(in source: NSString, range: NSRange, with template: String) -> String {
        guard range.length > 0, NSMaxRange(range) <= source.length else { return source as String }
        return re.stringByReplacingMatches(in: source as String, options: [],
                                           range: range, withTemplate: template)
    }
}

// MARK: - Шаблоны разметки сайта

extension Rx {
    static let title      = Rx(#"<title>([^<]*)</title>"#)
    static let semester   = Rx(#"<a href="/viewer/view/\d+">([^<]*)</a>"#)
    static let day        = Rx(#"<h2 id="link(\d+)"[^>]*>\s*<b>([^<]+)</b>\s*</h2>"#)
    static let panel      = Rx(#"<h3 class="panel-title">\s*(?:<b>)?\s*([^<]+?)\s*(?:</b>)?\s*</h3>([\s\S]*?)</table>"#)
    static let row        = Rx(#"<tr class="([^"]*)">([\s\S]*?)</tr>"#)
    static let cell       = Rx(#"<td[^>]*>([\s\S]*?)</td>"#)
    static let bold       = Rx(#"<b>([\s\S]*?)</b>"#)
    static let teacher    = Rx(#"<a[^>]*id_teacher=(\d+)[^>]*>([\s\S]*?)</a>"#)
    static let course     = Rx(#"<a[^>]*href="(https?://[^"]+)"[^>]*>([\s\S]*?)</a>"#)

    static let tag            = Rx(#"<[^>]+>"#)
    static let numericEntity  = Rx(#"&#\d+;"#)
    static let whitespace     = Rx(#"\s+"#)

    /// Ссылки на группы на странице списка: id, название, курс.
    static let groupLink = Rx(#"id_edu_group=(\d+)"[^>]*>\s*<h4[^>]*>([^<]*)</h4>\s*<p[^>]*>([^<]*)<"#)
    /// Доступные семестры на /viewer/index.
    static let semesterLink = Rx(#"<a[^>]*href="/viewer/view/(\d+)"[^>]*>\s*<h4[^>]*>([^<]*)</h4>"#)
}
