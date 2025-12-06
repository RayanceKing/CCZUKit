// 示例: 使用CCZUKit查询成绩和课表

import Foundation
import CCZUKit

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
func exampleUsage() async throws {
    // 1. 创建客户端
    let client = DefaultHTTPClient(username: "你的学号", password: "你的密码")
    
    // 2. SSO登录
    print("正在登录...")
    let loginInfo = try await client.ssoUniversalLogin()
    if let info = loginInfo {
        print("WebVPN登录成功: \(info.userid)")
    } else {
        print("普通登录成功")
    }
    
    // 3. 创建教务应用并登录
    let app = JwqywxApplication(client: client)
    let userData = try await app.login()
    print("教务登录成功: \(userData.message.first?.username ?? "")")
    
    // 4. 查询成绩
    print("\n=== 查询成绩 ===")
    let gradesResponse = try await app.getGrades()
    for grade in gradesResponse.message.prefix(5) {
        print("\(grade.courseName):")
        print("  成绩: \(grade.grade) 分")
        print("  学分: \(grade.courseCredits)")
        print("  绩点: \(grade.gradePoints)")
        print("  教师: \(grade.teacherName)")
    }
    
    // 5. 查询学分绩点
    print("\n=== 查询学分绩点 ===")
    let pointsResponse = try await app.getCreditsAndRank()
    if let point = pointsResponse.message.first {
        print("学号: \(point.studentId)")
        print("姓名: \(point.studentName)")
        print("班级: \(point.className)")
        print("平均绩点: \(point.gradePoints)")
    }
    
    // 6. 查询当前学期课表
    print("\n=== 查询课表 ===")
    let schedule = try await app.getCurrentClassSchedule()
    let courses = CalendarParser.parseWeekMatrix(schedule)
    
    // 按星期分组显示
    let groupedByDay = Dictionary(grouping: courses) { $0.dayOfWeek }
    for day in 1...7 {
        guard let dayCourses = groupedByDay[day], !dayCourses.isEmpty else {
            continue
        }
        
        let weekdayName = ["一", "二", "三", "四", "五", "六", "日"][day - 1]
        print("\n周\(weekdayName):")
        
        for course in dayCourses.sorted(by: { $0.timeSlot < $1.timeSlot }) {
            print("  第\(course.timeSlot)节: \(course.name)")
            print("    教师: \(course.teacher)")
            print("    地点: \(course.location)")
            print("    周次: \(course.weeks.map(String.init).joined(separator: ","))")
        }
    }
    
    // 7. 查询所有学期
    print("\n=== 可用学期 ===")
    let termsResponse = try await app.getTerms()
    for term in termsResponse.message.prefix(5) {
        print("  \(term.term)")
    }
    
    // 8. 查询学生基本信息
    print("\n=== 学生基本信息 ===")
    let infoResponse = try await app.getStudentBasicInfo()
    if let info = infoResponse.message.first {
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
    }
    
    // 9. 查询考试安排
    print("\n=== 查询考试安排 ===")
    let exams = try await app.getCurrentExamArrangements()
    
    // 统计已安排和未安排的考试
    let scheduledExams = exams.filter { $0.examTime != nil }
    let unscheduledExams = exams.filter { $0.examTime == nil }
    
    print("总共 \(exams.count) 门考试")
    print("已安排: \(scheduledExams.count) 门")
    print("未安排: \(unscheduledExams.count) 门")
    
    // 显示已安排的考试
    if !scheduledExams.isEmpty {
        print("\n已安排的考试:")
        for exam in scheduledExams.prefix(5) {
            print("  \(exam.courseName.trimmingCharacters(in: .whitespaces))")
            print("    时间: \(exam.examTime ?? "待定")")
            print("    地点: \(exam.examLocation ?? "待定")")
            print("    类型: \(exam.studyType.trimmingCharacters(in: .whitespaces))")
        }
    }
    
    // 10. 教师评价
    print("\n=== 教师评价 ===")
    let evaluatableClasses = try await app.getCurrentEvaluatableClasses()
    print("当前学期可评价课程数: \(evaluatableClasses.count)")
    
    if !evaluatableClasses.isEmpty {
        for (index, evaluatableClass) in evaluatableClasses.prefix(3).enumerated() {
            print("\n课程\(index + 1): \(evaluatableClass.courseName)")
            print("  教师: \(evaluatableClass.teacherName)")
            print("  班级号: \(evaluatableClass.classId)")
            print("  评价ID: \(evaluatableClass.evaluationId)")
            print("  评价状态: \(evaluatableClass.evaluationStatus ?? "未评价")")
        }
        
        // 提交评价示例
        if let classToEvaluate = evaluatableClasses.first {
            let terms = try await app.getTerms()
            if let currentTerm = terms.message.first?.term {
                print("\n准备提交评价...")
                try await app.submitTeacherEvaluation(
                    term: currentTerm,
                    evaluatableClass: classToEvaluate,
                    overallScore: 90,
                    scores: [100, 80, 100, 80, 100, 80],
                    comments: "教学质量好，讲解清晰，内容充实"
                )
                print("评价已提交")
            }
        }
    }
}

// 教师评价示例
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
func exampleTeacherEvaluation() async throws {
    let client = DefaultHTTPClient(username: "你的学号", password: "你的密码")
    let app = JwqywxApplication(client: client)
    
    // 登录
    print("正在登录...")
    try await app.login()
    print("登录成功")
    
    // 获取可评价的课程列表
    print("\n=== 可评价课程 ===")
    let evaluatableClasses = try await app.getCurrentEvaluatableClasses()
    
    if evaluatableClasses.isEmpty {
        print("当前学期暂无可评价课程")
        return
    }
    
    for (index, evaluatableClass) in evaluatableClasses.enumerated() {
        print("\n[\(index + 1)] \(evaluatableClass.courseName)")
        print("   教师: \(evaluatableClass.teacherName)")
        print("   学分: \(evaluatableClass.credit)")
        print("   评价状态: \(evaluatableClass.evaluationStatus)")
    }
    
    // 提交评价
    guard let classToEvaluate = evaluatableClasses.first else { return }
    
    let terms = try await app.getTerms()
    guard let currentTerm = terms.message.first?.term else { return }
    
    print("\n提交评价: \(classToEvaluate.courseName)")
    try await app.submitTeacherEvaluation(
        term: currentTerm,
        evaluatableClass: classToEvaluate,
        overallScore: 90,
        scores: [100, 80, 100, 80, 100, 80],
        comments: "教学质量优秀，建议继续改进"
    )
    print("评价已提交成功")
}


// 错误处理示例
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
func exampleWithErrorHandling() async {
    let client = DefaultHTTPClient(username: "test", password: "test")
    
    do {
        let app = JwqywxApplication(client: client)
        try await app.login()
        
        let grades = try await app.getGrades()
        print("成绩查询成功: \(grades.message.count) 门课程")
        
    } catch CCZUError.invalidCredentials {
        print("错误: 账号或密码错误，请检查输入")
    } catch CCZUError.ssoLoginFailed(let reason) {
        print("错误: SSO登录失败 - \(reason)")
    } catch CCZUError.notLoggedIn {
        print("错误: 未登录,请先登录")
    } catch CCZUError.loginFailed(let reason) {
        print("错误: 登录失败 - \(reason)")
    } catch CCZUError.networkError(let error) {
        print("错误: 网络请求失败 - \(error.localizedDescription)")
    } catch CCZUError.decodingError(let error) {
        print("错误: 数据解析失败 - \(error.localizedDescription)")
    } catch CCZUError.missingData(let description) {
        print("错误: 缺少数据 - \(description)")
    } catch {
        print("错误: 未知错误 - \(error)")
    }
}

// 使用示例
// Task {
//     try await exampleUsage()
// }
