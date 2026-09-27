import XCTest
@testable import EarlyOtter

final class AlarmSoundOptionTests: XCTestCase {
    func testEveryBundledToneExists() throws {
        for option in AlarmSoundOption.allCases {
            guard let resourceName = option.resourceName else { continue }
            let name = (resourceName as NSString).deletingPathExtension
            XCTAssertNotNil(
                Bundle.main.url(forResource: name, withExtension: "wav"),
                "\(option) points at missing \(resourceName)"
            )
        }
    }

    func testRetiredToneFallsBackToDefault() throws {
        let decoded = try JSONDecoder().decode([AlarmSoundOption].self, from: Data(#"["glass","tide"]"#.utf8))
        XCTAssertEqual(decoded, [.default, .tide])
    }
}
