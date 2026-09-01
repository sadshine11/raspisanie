import XCTest
@testable import Raspisanie

final class PrefsTests: XCTestCase {

    private let key = "subgroup"
    private var savedValue: Any?

    override func setUp() {
        super.setUp()
        savedValue = UserDefaults.standard.object(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
    }

    override func tearDown() {
        if let savedValue {
            UserDefaults.standard.set(savedValue, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
        super.tearDown()
    }

    /// На чистой установке показывается 2-я подгруппа.
    func testDefaultsToSecondSubgroup() {
        XCTAssertEqual(Prefs.subgroup, Prefs.defaultSubgroup)
        XCTAssertEqual(Prefs.subgroup, "2")
    }

    func testRemembersChosenSubgroup() {
        Prefs.subgroup = "1"
        XCTAssertEqual(Prefs.subgroup, "1")
    }

    /// Осознанный выбор «показывать все» не должен на следующем запуске
    /// откатываться к подгруппе по умолчанию.
    func testExplicitShowAllSurvives() {
        Prefs.subgroup = nil
        XCTAssertNil(Prefs.subgroup)
        XCTAssertEqual(UserDefaults.standard.string(forKey: key), "")
    }

    func testSwitchingBackAndForth() {
        Prefs.subgroup = nil
        XCTAssertNil(Prefs.subgroup)
        Prefs.subgroup = "2"
        XCTAssertEqual(Prefs.subgroup, "2")
        Prefs.subgroup = nil
        XCTAssertNil(Prefs.subgroup)
    }
}
