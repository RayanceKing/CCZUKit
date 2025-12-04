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
    
    // 8. 查询考试安排
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
