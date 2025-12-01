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
    
    // MARK: - 集成测试: SSO + WeChat登录并打印课表
    
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func testLoginAndPrintSchedule() async throws {
        // 从环境变量读取账号密码
        let username = ProcessInfo.processInfo.environment["CCZU_USERNAME"] ?? ""
        let password = ProcessInfo.processInfo.environment["CCZU_PASSWORD"] ?? ""
        
        // 若未设置，跳过此测试
        if username.isEmpty || password.isEmpty {
            throw XCTSkip("未设置CCZU_USERNAME/CCZU_PASSWORD，跳过集成测试")
        }
        
        let client = DefaultHTTPClient(username: username, password: password)
        
        // 1. SSO统一登录（可能走WebVPN）
        let loginInfo = try await client.ssoUniversalLogin()
        if let info = loginInfo {
            print("[SSO] WebVPN登录成功: userid=\(info.userid)")
        } else {
            print("[SSO] 普通登录成功")
        }
        
        // 2. 教务企业微信登录
        let app = JwqywxApplication(client: client)
        let userMessage = try await app.login()
        let userName = userMessage.message.first?.username ?? ""
        print("[JWQYWX] 登录成功: username=\(userName)")
        
        // 3. 获取当前学期课表并解析
        let scheduleMatrix = try await app.getCurrentClassSchedule()
        let courses = CalendarParser.parseWeekMatrix(scheduleMatrix)
        
        // 4. 控制台输出课表（按星期与节次排序）
        print("\n=== 当前学期课表 ===")
        let groupedByDay = Dictionary(grouping: courses) { $0.dayOfWeek }
        let weekdayNames = [1: "一", 2: "二", 3: "三", 4: "四", 5: "五", 6: "六", 7: "日"]
        
        for day in 1...7 {
            guard let dayCourses = groupedByDay[day], !dayCourses.isEmpty else { continue }
            let dayName = weekdayNames[day] ?? ""
            print("\n周\(dayName):")
            for course in dayCourses.sorted(by: { $0.timeSlot < $1.timeSlot }) {
                let weeksStr = course.weeks.map(String.init).joined(separator: ",")
                print("  第\(course.timeSlot)节: \(course.name)")
                print("    教师: \(course.teacher)")
                print("    地点: \(course.location)")
                print("    周次: \(weeksStr)")
            }
        }
        
        // 基本断言，至少解析到0门课（允许为空但流程需完整）
        XCTAssertNotNil(courses)
    }
}
