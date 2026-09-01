import Foundation

/// Справочник групп и семестров, снятый с сайта.
/// Нужен, чтобы выбор группы работал сразу и без сети;
/// при первом успешном обращении список обновляется с сервера.
enum Catalog {

    static let defaultGroup = GroupRef(id: 3281, scheduleId: 116, name: "56-1 (ХБ 26-01)", course: "1-й курс")

    static let semesters: [SemesterRef] = [
        SemesterRef(id: 116, title: "2026-2027, Осень, Очная форма обучения"),
        SemesterRef(id: 117, title: "2026-2027, Осень, Очно-заочная форма обучения"),
    ]

    static let groups: [GroupRef] = [
        GroupRef(id: 3259, scheduleId: 116, name: "13-1 (ХЭн23-01)", course: "4-й курс"),
        GroupRef(id: 3260, scheduleId: 116, name: "14-1 (ХЭн24-01)", course: "3-й курс"),
        GroupRef(id: 3261, scheduleId: 116, name: "15-1 (ХЭн25-01)", course: "2-й курс"),
        GroupRef(id: 3262, scheduleId: 116, name: "16-1 (ХЭн26-01)", course: "1-й курс"),
        GroupRef(id: 3263, scheduleId: 116, name: "23-1 (ХС 23-04)", course: "4-й курс"),
        GroupRef(id: 3264, scheduleId: 116, name: "24-1 (ХС 24-04)", course: "3-й курс"),
        GroupRef(id: 3265, scheduleId: 116, name: "25-1 (ХС 25-04)", course: "2-й курс"),
        GroupRef(id: 3266, scheduleId: 116, name: "31-2 (ХС 21-02)", course: "6-й курс"),
        GroupRef(id: 3267, scheduleId: 116, name: "32-2 (ХС 22-02)", course: "5-й курс"),
        GroupRef(id: 3268, scheduleId: 116, name: "33-1 (ХС 23-01)", course: "4-й курс"),
        GroupRef(id: 3269, scheduleId: 116, name: "33-2 (ХС 23-02)", course: "4-й курс"),
        GroupRef(id: 3270, scheduleId: 116, name: "34-1 (ХС 24-01)", course: "3-й курс"),
        GroupRef(id: 3271, scheduleId: 116, name: "34-2 (ХС 24-02)", course: "3-й курс"),
        GroupRef(id: 3272, scheduleId: 116, name: "35-1 (ХС 25-01)", course: "2-й курс"),
        GroupRef(id: 3273, scheduleId: 116, name: "35-2 (ХС 25-02)", course: "2-й курс"),
        GroupRef(id: 3274, scheduleId: 116, name: "35-3 (ХС 25-03)", course: "2-й курс"),
        GroupRef(id: 3275, scheduleId: 116, name: "36-1 (ХС 26-01)", course: "1-й курс"),
        GroupRef(id: 3276, scheduleId: 116, name: "36-2 (ХС 26-02)", course: "1-й курс"),
        GroupRef(id: 3277, scheduleId: 116, name: "36-3 (ХС 26-03)", course: "1-й курс"),
        GroupRef(id: 3278, scheduleId: 116, name: "53-1 (ХБ 23-01)", course: "4-й курс"),
        GroupRef(id: 3279, scheduleId: 116, name: "54-1 (ХБ 24-01)", course: "3-й курс"),
        GroupRef(id: 3280, scheduleId: 116, name: "55-1 (ХБ 25-01)", course: "2-й курс"),
        GroupRef(id: 3281, scheduleId: 116, name: "56-1 (ХБ 26-01)", course: "1-й курс"),
        GroupRef(id: 3282, scheduleId: 116, name: "66-1 (ХС 26-04)", course: "1-й курс"),
        GroupRef(id: 3283, scheduleId: 117, name: "ОЗ-32 (ОЗХС22-01)", course: "5-й курс"),
        GroupRef(id: 3284, scheduleId: 117, name: "ОЗ-33 (ОЗХС23-01)", course: "4-й курс"),
        GroupRef(id: 3285, scheduleId: 117, name: "ОЗ-34 (ОЗХС24-01)", course: "3-й курс"),
        GroupRef(id: 3286, scheduleId: 117, name: "ОЗ-35 (ОЗХС25-01)", course: "2-й курс"),
        GroupRef(id: 3287, scheduleId: 117, name: "ОЗ-36 (ОЗХС26-01)", course: "1-й курс"),
        GroupRef(id: 3288, scheduleId: 117, name: "ОЗ-72 (ОЗХБ22-01)", course: "5-й курс"),
        GroupRef(id: 3289, scheduleId: 117, name: "ОЗ-73 (ОЗХБ23-01)", course: "4-й курс"),
        GroupRef(id: 3290, scheduleId: 117, name: "ОЗ-74 (ОЗХБ24-01)", course: "3-й курс"),
        GroupRef(id: 3291, scheduleId: 117, name: "ОЗ-75 (ОЗХБ25-01)", course: "2-й курс"),
        GroupRef(id: 3292, scheduleId: 117, name: "ОЗ-76м (ОЗХБ26-01)", course: "1-й курс"),
    ]

    static func group(id: Int) -> GroupRef? { groups.first { $0.id == id } }
}
