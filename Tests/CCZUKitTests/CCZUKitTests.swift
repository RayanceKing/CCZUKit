import XCTest
@testable import CCZUKit

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
final class CCZUKitTests: XCTestCase {
    
    // MARK: - 基础测试
    
    func testAccountCreation() {
        let account = Account(username: "test", password: "password")
        XCTAssertEqual(account.username, "test")
        XCTAssertEqual(account.password, "password")
    }
    
    func testDefaultAccount() {
        let account = Account.default
        XCTAssertEqual(account.username, "")
        XCTAssertEqual(account.password, "")
    }
    
    func testProperty() {
        let stringProp = Property.string("test")
        XCTAssertEqual(stringProp.stringValue, "test")
        XCTAssertNil(stringProp.intValue)
        
        let intProp = Property.int(42)
        XCTAssertEqual(intProp.intValue, 42)
        XCTAssertNil(intProp.stringValue)
        
        let boolProp = Property.bool(true)
        XCTAssertEqual(boolProp.boolValue, true)
        XCTAssertNil(boolProp.stringValue)
    }
    
    // MARK: - HTTP客户端测试
    
    func testHTTPClientCreation() {
        let client = DefaultHTTPClient(username: "test", password: "password")
        XCTAssertEqual(client.account.username, "test")
        XCTAssertEqual(client.account.password, "password")
    }
    
    // MARK: - 日历解析测试
    
    func testCalendarParserWithEmptyCourses() {
        let matrix: [[RawCourse]] = [
            [RawCourse(course: "", teacher: "")],
            [RawCourse(course: "", teacher: "")]
        ]
        
        let parsed = CalendarParser.parseWeekMatrix(matrix)
        XCTAssertEqual(parsed.count, 0)
    }
    
    func testCalendarParserWithSingleCourse() {
        let matrix: [[RawCourse]] = [
            [RawCourse(course: "高等数学 1-16周 教学楼A101", teacher: "张三")]
        ]
        
        let parsed = CalendarParser.parseWeekMatrix(matrix)
        XCTAssertEqual(parsed.count, 1)
        
        if let course = parsed.first {
            XCTAssertEqual(course.name, "高等数学")
            XCTAssertEqual(course.teacher, "张三")
            XCTAssertEqual(course.location, "教学楼A101")
            XCTAssertEqual(course.dayOfWeek, 1)
            XCTAssertEqual(course.timeSlot, 1)
            XCTAssertTrue(course.weeks.count > 0)
        }
    }
    
    // MARK: - 错误处理测试
    
    func testCCZUError() {
        let networkError = CCZUError.networkError(NSError(domain: "test", code: 0))
        XCTAssertNotNil(networkError.errorDescription)
        
        let loginError = CCZUError.loginFailed("test reason")
        XCTAssertTrue(loginError.errorDescription?.contains("test reason") ?? false)
        
        let notLoggedInError = CCZUError.notLoggedIn
        XCTAssertNotNil(notLoggedInError.errorDescription)
    }
    
    // MARK: - 模型测试
    
    func testRawCourse() {
        let course = RawCourse(course: "高等数学", teacher: "张三")
        XCTAssertEqual(course.course, "高等数学")
        XCTAssertEqual(course.teacher, "张三")
    }
    
    func testParsedCourse() {
        let course = ParsedCourse(
            name: "高等数学",
            teacher: "张三",
            location: "教学楼A101",
            weeks: [1, 2, 3, 4, 5],
            dayOfWeek: 1,
            timeSlot: 1
        )
        
        XCTAssertEqual(course.name, "高等数学")
        XCTAssertEqual(course.teacher, "张三")
        XCTAssertEqual(course.location, "教学楼A101")
        XCTAssertEqual(course.weeks, [1, 2, 3, 4, 5])
        XCTAssertEqual(course.dayOfWeek, 1)
        XCTAssertEqual(course.timeSlot, 1)
    }
}
