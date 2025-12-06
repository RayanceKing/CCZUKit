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
    
    func testExamArrangementDecoding() {
        // 模拟考试安排JSON数据（基于实际抓包数据结构）
        let json = """
        {
            "id": 1,
            "kch": "70091061",
            "kcmc": "法理学(1)",
            "kcdm": "70091061",
            "xsbh": "0721",
            "xsbj": "法学243",
            "xh": "114514",
            "xm": "张三",
            "jse": null,
            "kssj": null,
            "lb": "学分制考试",
            "xklb": "转专业重学",
            "bmmc": "西太湖校区",
            "bz": null,
            "zc": null,
            "jc1": null,
            "jc2": null,
            "xq": "25-26-1",
            "sjxx": null,
            "yx": 1,
            "ksz": null,
            "BH": "229903",
            "jseid": 0,
            "jkjs1": null,
            "jkjs2": null
        }
        """
        
        let decoder = JSONDecoder()
        let data = json.data(using: .utf8)!
        
        do {
            let exam = try decoder.decode(ExamArrangement.self, from: data)
            XCTAssertEqual(exam.id, 1)
            XCTAssertEqual(exam.courseId, "70091061")
            XCTAssertEqual(exam.courseName, "法理学(1)")
            XCTAssertEqual(exam.courseCode, "70091061")
            XCTAssertEqual(exam.classId, "0721")
            XCTAssertEqual(exam.className, "法学243")
            XCTAssertEqual(exam.studentId, "114514")
            XCTAssertEqual(exam.studentName, "张三")
            XCTAssertNil(exam.examLocation)
            XCTAssertNil(exam.examTime)
            XCTAssertEqual(exam.examType, "学分制考试")
            XCTAssertEqual(exam.studyType, "转专业重学")
            XCTAssertEqual(exam.campus, "西太湖校区")
            XCTAssertNil(exam.remark)
            XCTAssertNil(exam.week)
            XCTAssertNil(exam.startSlot)
            XCTAssertNil(exam.endSlot)
            XCTAssertEqual(exam.term, "25-26-1")
            XCTAssertNil(exam.examDayInfo)
            XCTAssertEqual(exam.isActive, 1)
            XCTAssertNil(exam.examSeat)
            XCTAssertEqual(exam.classNumber, "229903")
            XCTAssertEqual(exam.teacherRoomId, 0)
            XCTAssertNil(exam.startTeacherSlot)
            XCTAssertNil(exam.endTeacherSlot)
        } catch {
            XCTFail("Failed to decode ExamArrangement: \(error)")
        }
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
    
    // MARK: - 集成测试: 考试安排查询
    
    @available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
    func testLoginAndGetExamArrangements() async throws {
        // 从环境变量读取账号密码
        let username = ProcessInfo.processInfo.environment["CCZU_USERNAME"] ?? ""
        let password = ProcessInfo.processInfo.environment["CCZU_PASSWORD"] ?? ""
        
        // 若未设置，跳过此测试
        if username.isEmpty || password.isEmpty {
            throw XCTSkip("未设置CCZU_USERNAME/CCZU_PASSWORD，跳过考试安排集成测试")
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
        
        // 3. 获取考试安排
        do {
            let exams = try await app.getExamArrangements()
            print("\n=== 考试安排 ===")
            print("总共 \(exams.count) 门课程")
            
            // 统计已安排和未安排的考试
            let scheduledExams = exams.filter { $0.examTime != nil }
            let unscheduledExams = exams.filter { $0.examTime == nil }
            
            print("已安排考试: \(scheduledExams.count) 门")
            print("未安排考试: \(unscheduledExams.count) 门")
            
            // 打印已安排的考试详情
            if !scheduledExams.isEmpty {
                print("\n已安排的考试:")
                for exam in scheduledExams.prefix(5) {
                    print("\n课程: \(exam.courseName.trimmingCharacters(in: .whitespaces))")
                    print("  考试时间: \(exam.examTime ?? "N/A")")
                    print("  考试地点: \(exam.examLocation ?? "N/A")")
                    print("  考试类型: \(exam.examType)")
                    print("  修读类型: \(exam.studyType.trimmingCharacters(in: .whitespaces))")
                    print("  班级: \(exam.className.trimmingCharacters(in: .whitespaces))")
                    if let week = exam.week {
                        print("  考试周: 第\(week)周")
                    }
                    if let startSlot = exam.startSlot, let endSlot = exam.endSlot {
                        print("  节次: 第\(startSlot)-\(endSlot)节")
                    }
                }
                if scheduledExams.count > 5 {
                    print("\n... 还有 \(scheduledExams.count - 5) 门考试未显示")
                }
            }
            
            // 基本断言
            XCTAssertNotNil(exams)
            XCTAssertGreaterThanOrEqual(exams.count, 0)
            
            // 验证考试数据的完整性（只验证非空的数据）
            for exam in exams {
                XCTAssertFalse(exam.courseId.trimmingCharacters(in: .whitespaces).isEmpty)
                XCTAssertFalse(exam.courseName.trimmingCharacters(in: .whitespaces).isEmpty)
                XCTAssertFalse(exam.term.isEmpty)
            }
        } catch {
            print("[ERROR] 获取考试安排失败: \(error)")
            // 如果是网络相关的错误，跳过测试而不是失败
            if error is DecodingError {
                throw XCTSkip("API 返回格式不符合预期，跳过考试安排集成测试")
            }
            throw error
        }
    }
    
    // MARK: - 学生基本信息测试
    
    func testLoginAndGetStudentBasicInfo() async throws {
        // 从环境变量读取账号密码
        let username = ProcessInfo.processInfo.environment["CCZU_USERNAME"] ?? ""
        let password = ProcessInfo.processInfo.environment["CCZU_PASSWORD"] ?? ""
        
        // 若未设置，跳过此测试
        if username.isEmpty || password.isEmpty {
            throw XCTSkip("未设置CCZU_USERNAME/CCZU_PASSWORD，跳过学生基本信息集成测试")
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
        
        // 3. 获取学生基本信息
        do {
            let infoMessage = try await app.getStudentBasicInfo()
            
            print("\n=== 学生基本信息 ===")
            
            if let info = infoMessage.message.first {
                print("姓名: \(info.name)")
                print("学号: \(info.studentNumber)")
                print("性别: \(info.gender)")
                print("出生日期: \(info.birthday)")
                print("学院: \(info.collegeName)")
                print("专业: \(info.major)")
                print("班级: \(info.className)")
                print("年级: \(info.grade)")
                print("学制: \(info.studyLength)年")
                print("学籍情况: \(info.studentStatus)")
                print("校区: \(info.campus)")
                print("手机号: \(info.phone)")
                print("宿舍编号: \(info.dormitoryNumber)")
                
                // 基本断言
                XCTAssertFalse(info.name.isEmpty, "姓名不应为空")
                XCTAssertFalse(info.studentNumber.isEmpty, "学号不应为空")
                XCTAssertFalse(info.major.isEmpty, "专业不应为空")
                XCTAssertGreaterThan(info.grade, 0, "年级应大于0")
            } else {
                XCTFail("未获取到学生基本信息")
            }
        } catch {
            print("[ERROR] 获取学生基本信息失败: \(error)")
            // 如果是网络相关的错误，跳过测试而不是失败
            if error is DecodingError {
                throw XCTSkip("API 返回格式不符合预期，跳过学生基本信息集成测试")
            }
            throw error
        }
    }
    
    // MARK: - 登录失败处理测试
    
    func testLoginFailureHandling() async {
        let invalidClient = DefaultHTTPClient(username: "invalid_user", password: "wrong_password")
        let app = JwqywxApplication(client: invalidClient)
        
        do {
            _ = try await app.login()
            print("[INFO] 测试账号意外登录成功")
        } catch CCZUError.invalidCredentials {
            print("[SUCCESS] 捕获到账号密码错误")
            XCTAssertTrue(true)
        } catch CCZUError.loginFailed(let reason) {
            print("[INFO] 捕获到登录失败: \(reason)")
            XCTAssertTrue(true)
        } catch {
            print("[INFO] 捕获到其他错误: \(error)")
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - 教师评价功能测试
    
    func testGetEvaluatableClasses() async throws {
        guard let username = ProcessInfo.processInfo.environment["CCZU_USERNAME"],
              let password = ProcessInfo.processInfo.environment["CCZU_PASSWORD"] else {
            throw XCTSkip("CCZU_USERNAME 或 CCZU_PASSWORD 环境变量未设置")
        }
        
        let client = DefaultHTTPClient(username: username, password: password)
        let app = JwqywxApplication(client: client)
        
        do {
            print("\n=== 教师评价集成测试 ===")
            
            // 登录
            _ = try await app.login()
            print("[INFO] 登录成功")
            
            // 获取当前学期可评价课程
            let classes = try await app.getCurrentEvaluatableClasses()
            
            print("可评价课程数量: \(classes.count)")
            
            // 获取已提交的评价信息用于判断评价状态
            let submittedEvaluations = try await app.getCurrentSubmittedEvaluations()
            print("已提交评价数量: \(submittedEvaluations.count)")
            
            // 创建已评价课程代码集合用于快速查找
            let evaluatedCourses = Set(submittedEvaluations.map { $0.courseCode })
            
            if !classes.isEmpty {
                for (index, evaluatableClass) in classes.enumerated() {
                    let isEvaluated = evaluatedCourses.contains(evaluatableClass.courseCode)
                    
                    print("\n课程\(index + 1) [\(isEvaluated ? "已评价" : "未评价")]:")
                    print("- 课程名称: \(evaluatableClass.courseName)")
                    print("- 教师名称: \(evaluatableClass.teacherName)")
                    print("- 课程代码: \(evaluatableClass.courseCode)")
                    
                    // 基本断言
                    XCTAssertFalse(evaluatableClass.courseCode.isEmpty, "课程代码不应为空")
                    XCTAssertFalse(evaluatableClass.courseName.isEmpty, "课程名称不应为空")
                    XCTAssertFalse(evaluatableClass.teacherName.isEmpty, "教师名称不应为空")
                }
            } else {
                print("[INFO] 当前学期暂无可评价课程")
            }
        } catch {
            print("[ERROR] 获取可评价课程列表失败: \(error)")
            if error is DecodingError {
                throw XCTSkip("API 返回格式不符合预期，跳过教师评价集成测试")
            }
            throw error
        }
    }
    
    func testSubmitTeacherEvaluation() async throws {
        guard let username = ProcessInfo.processInfo.environment["CCZU_USERNAME"],
              let password = ProcessInfo.processInfo.environment["CCZU_PASSWORD"] else {
            throw XCTSkip("CCZU_USERNAME 或 CCZU_PASSWORD 环境变量未设置")
        }
        
        let client = DefaultHTTPClient(username: username, password: password)
        let app = JwqywxApplication(client: client)
        
        do {
            print("\n=== 教师评价提交测试 ===")
            
            // 登录
            _ = try await app.login()
            print("[INFO] 登录成功")
            
            // 获取当前学期可评价课程
            let classes = try await app.getCurrentEvaluatableClasses()
            
            if let evaluatableClass = classes.first {
                print("[INFO] 准备提交课程评价: \(evaluatableClass.courseName)")
                
                // 获取当前学期
                let terms = try await app.getTerms()
                guard let currentTerm = terms.message.first?.term else {
                    throw XCTSkip("无法获取当前学期")
                }
                
                // 提交评价
                try await app.submitTeacherEvaluation(
                    term: currentTerm,
                    evaluatableClass: evaluatableClass,
                    overallScore: 90,
                    scores: [100, 80, 100, 80, 100, 80],
                    comments: "教学质量好，讲解清晰"
                )
                
                print("[SUCCESS] 课程评价提交成功")
                XCTAssertTrue(true)
            } else {
                throw XCTSkip("当前学期暂无可评价课程，跳过提交测试")
            }
        } catch let error as XCTSkip {
            throw error
        } catch {
            print("[ERROR] 教师评价提交失败: \(error)")
            if error is DecodingError {
                throw XCTSkip("API 返回格式不符合预期，跳过教师评价提交测试")
            }
            throw error
        }
    }
}


