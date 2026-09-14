import XCTest
@testable import Stash

final class DateFormattersTests: XCTestCase {
    
    // MARK: - Format Date String Tests
    
    func testFormatDateString_withEmptyString_returnsEmpty() {
        XCTAssertEqual(DateFormatters.formatDateString(""), "")
    }
    
    func testFormatDateString_withStandardDate() {
        let formatted = DateFormatters.formatDateString("2024-08-08")
        XCTAssertEqual(formatted, "Aug 8th, 2024")
    }
    
    func testFormatDateString_withISO8601FractionalSeconds() {
        let formatted = DateFormatters.formatDateString("2024-01-01T15:30:00.000Z")
        XCTAssertEqual(formatted, "Jan 1st, 2024")
    }
    
    func testFormatDateString_withAlternatePatterns() {
        let formattedSlash = DateFormatters.formatDateString("2024/05/22")
        XCTAssertEqual(formattedSlash, "May 22nd, 2024")
        
        let formattedMonthDay = DateFormatters.formatDateString("07-03-2023")
        XCTAssertEqual(formattedMonthDay, "Jul 3rd, 2023")
    }
    
    func testFormatDateString_withInvalidFormat_returnsOriginalString() {
        let invalid = "not-a-valid-date"
        XCTAssertEqual(DateFormatters.formatDateString(invalid), invalid)
    }
    
    // MARK: - Ordinal Suffix Tests
    
    func testFormatDate_ordinalSuffixes() {
        let testCases: [(day: String, expectedDaySuffix: String)] = [
            ("2024-05-01", "May 1st, 2024"),
            ("2024-05-02", "May 2nd, 2024"),
            ("2024-05-03", "May 3rd, 2024"),
            ("2024-05-04", "May 4th, 2024"),
            ("2024-05-11", "May 11th, 2024"),
            ("2024-05-12", "May 12th, 2024"),
            ("2024-05-13", "May 13th, 2024"),
            ("2024-05-21", "May 21st, 2024"),
            ("2024-05-22", "May 22nd, 2024"),
            ("2024-05-23", "May 23rd, 2024"),
            ("2024-05-31", "May 31st, 2024"),
        ]
        
        for testCase in testCases {
            let result = DateFormatters.formatDateString(testCase.day)
            XCTAssertEqual(result, testCase.expectedDaySuffix)
        }
    }
    
    // MARK: - Timestamp Formatting Tests
    
    func testFormatTimestamp_withEmptyString_returnsEmpty() {
        XCTAssertEqual(DateFormatters.formatTimestamp(""), "")
    }
    
    func testFormatTimestamp_withValidISO8601() {
        let result = DateFormatters.formatTimestamp("2024-01-15T15:30:00Z")
        XCTAssertTrue(result.contains("Jan 15th, 2024 at"))
    }
    
    func testFormatTimestamp_withInvalidISO_returnsOriginal() {
        let invalid = "invalid-iso"
        XCTAssertEqual(DateFormatters.formatTimestamp(invalid), invalid)
    }
    
    // MARK: - Calculate Age Tests
    
    func testCalculateAge_withLivingPerformer() {
        let birthdate = "1990-05-15"
        let age = DateFormatters.calculateAge(from: birthdate)
        XCTAssertNotNil(age)
        XCTAssertGreaterThan(age!, 30)
    }
    
    func testCalculateAge_withDeceasedPerformer() {
        let birthdate = "1970-01-01"
        let deathdate = "2020-01-01"
        let age = DateFormatters.calculateAge(from: birthdate, deathDate: deathdate)
        XCTAssertEqual(age, 50)
    }
    
    func testCalculateAge_withInvalidBirthdate_returnsNil() {
        XCTAssertNil(DateFormatters.calculateAge(from: "not-a-date"))
    }
}
