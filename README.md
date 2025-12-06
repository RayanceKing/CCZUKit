# CCZUKit

<div align="center">
  <h3>常州大学 API 客户端 Swift Package</h3>
  <img src="https://img.shields.io/badge/Swift-5.9+-orange" alt="Swift">
  <img src="https://img.shields.io/badge/Platform-iOS%20%7C%20macOS%20%7C%20watchOS%20%7C%20tvOS-lightgrey" alt="Platform">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="License">
</div>

## 简介

CCZUKit 是常州大学官方服务的 Swift 客户端库,提供了便捷的 API 访问接口。本项目是 Rust 版本 [cczuni](https://github.com/CCZU-OSSA/cczuni) 的 Swift 重写版本,专为 Apple 平台优化。

## 特性

- ✅ **SSO 统一登录** - 支持普通模式和 WebVPN 模式
- ✅ **教务企业微信** - 成绩查询、课表查询、学分绩点查询
- ✅ **课表解析** - 自动解析课程信息,包括周次、时间、地点
- ✅ **类型安全** - 完整的 Swift 类型系统支持
- ✅ **现代异步** - 基于 Swift Concurrency (async/await)
- ✅ **跨平台** - 支持 iOS、macOS、watchOS、tvOS

## 系统要求

- iOS 13.0+ / macOS 10.15+ / watchOS 6.0+ / tvOS 13.0+
- Swift 5.9+
- Xcode 15.0+

## 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖:

```swift
dependencies: [
    .package(url: "https://github.com/CCZU-OSSA/cczuni.git", from: "0.1.0")
]
```

或在 Xcode 中:
1. File → Add Package Dependencies
2. 输入仓库 URL: `https://github.com/CCZU-OSSA/cczuni.git`
3. 选择版本并添加到项目

## 使用示例

### 基础使用

```swift
import CCZUKit

// 创建客户端
let client = DefaultHTTPClient(username: "你的学号", password: "你的密码")

// SSO 登录
let loginInfo = try await client.ssoUniversalLogin()
print("登录成功")

// 创建教务应用
let app = JwqywxApplication(client: client)
try await app.login()
```

### 查询成绩

```swift
// 获取成绩
let gradesResponse = try await app.getGrades()
for grade in gradesResponse.message {
    print("\(grade.courseName): \(grade.grade) 分")
}

// 获取学分绩点
let pointsResponse = try await app.getCreditsAndRank()
if let point = pointsResponse.message.first {
    print("平均绩点: \(point.gradePoints)")
}
```

### 查询课表

```swift
// 获取当前学期课表
let schedule = try await app.getCurrentClassSchedule()

// 解析课表
let courses = CalendarParser.parseWeekMatrix(schedule)
for course in courses {
    print("\(course.name) - \(course.teacher)")
    print("时间: 周\(course.dayOfWeek) 第\(course.timeSlot)节")
    print("地点: \(course.location)")
    print("周次: \(course.weeks)")
}
```

### 查询指定学期课表

```swift
// 获取所有学期
let termsResponse = try await app.getTerms()
for term in termsResponse.message {
    print("学期: \(term.term)")
}

// 查询指定学期
let schedule = try await app.getClassSchedule(term: "202501")
```

### 查询考试安排

```swift
// 获取当前学期考试安排
let exams = try await app.getCurrentExamArrangements()

// 或指定学期和考试类型
let exams = try await app.getExamArrangements(
    term: "25-26-1", 
    examType: "学分制考试"
)

// 筛选已安排的考试
let scheduledExams = exams.filter { $0.examTime != nil }
for exam in scheduledExams {
    print("\(exam.courseName)")
    print("考试时间: \(exam.examTime ?? "待定")")
    print("考试地点: \(exam.examLocation ?? "待定")")
    print("修读类型: \(exam.studyType)")
    print("---")
}
```

### 查询学生基本信息

```swift
// 获取学生基本信息
let infoResponse = try await app.getStudentBasicInfo()
if let info = infoResponse.message.first {
    print("姓名: \(info.name)")
    print("学号: \(info.studentNumber)")
    print("专业: \(info.major)")
    print("学院: \(info.collegeName)")
    print("班级: \(info.className)")
    print("年级: \(info.grade)")
    print("学制: \(info.studyLength)年")
    print("学籍情况: \(info.studentStatus)")
    print("校区: \(info.campus)")
}
```

### 教师评价

```swift
// 获取当前学期可评价的课程列表
let evaluatableClasses = try await app.getCurrentEvaluatableClasses()

for evaluatableClass in evaluatableClasses {
    print("课程: \(evaluatableClass.courseName)")
    print("教师: \(evaluatableClass.teacherName)")
    print("学分: \(evaluatableClass.credit)")
    print("状态: \(evaluatableClass.evaluationStatus)")
}

// 提交教师评价
let terms = try await app.getTerms()
if let currentTerm = terms.message.first?.term,
   let classToEvaluate = evaluatableClasses.first {
    try await app.submitTeacherEvaluation(
        term: currentTerm,
        evaluatableClass: classToEvaluate,
        overallScore: 90,
        scores: [100, 80, 100, 80, 100, 80],
        comments: "教学质量优秀"
    )
    print("评价已提交")
}
```

## API 文档

### 核心类型

#### DefaultHTTPClient
HTTP 客户端,负责网络请求和会话管理。

```swift
let client = DefaultHTTPClient(username: String, password: String)
```

#### JwqywxApplication
教务企业微信应用接口。

```swift
let app = JwqywxApplication(client: DefaultHTTPClient)

// 登录
try await app.login() -> Message<LoginUserData>

// 获取成绩
try await app.getGrades() -> Message<CourseGrade>

// 获取学分绩点
try await app.getCreditsAndRank() -> Message<StudentPoint>

// 获取学期列表
try await app.getTerms() -> Message<Term>

// 获取课表
try await app.getClassSchedule(term: String) -> [[RawCourse]]
try await app.getCurrentClassSchedule() -> [[RawCourse]]

// 获取考试安排
try await app.getExamArrangements(term: String? = nil, examType: String = "学分制考试") -> [ExamArrangement]
try await app.getCurrentExamArrangements() -> [ExamArrangement]

// 获取学生基本信息
try await app.getStudentBasicInfo() -> Message<StudentBasicInfo>

// 获取可评价课程列表
try await app.getEvaluatableClasses(term: String) -> [EvaluatableClass]
try await app.getCurrentEvaluatableClasses() -> [EvaluatableClass]

// 提交教师评价
try await app.submitTeacherEvaluation(
    term: String,
    evaluatableClass: EvaluatableClass,
    overallScore: Int,
    scores: [Int],
    comments: String
) -> Void
```

#### CalendarParser
课表解析工具。

```swift
// 解析课表矩阵
CalendarParser.parseWeekMatrix([[RawCourse]]) -> [ParsedCourse]
```

### 数据模型

#### CourseGrade - 课程成绩
```swift
public struct CourseGrade {
    let courseName: String      // 课程名称
    let grade: Double          // 成绩
    let courseCredits: Double  // 学分
    let gradePoints: Double    // 绩点
    let teacherName: String    // 教师姓名
    // ... 更多字段
}
```

#### ParsedCourse - 解析后的课程
```swift
public struct ParsedCourse {
    let name: String         // 课程名称
    let teacher: String      // 教师姓名
    let location: String     // 上课地点
    let weeks: [Int]        // 上课周次
    let dayOfWeek: Int      // 星期几 (1-7)
    let timeSlot: Int       // 第几节课
}
```

#### ExamArrangement - 考试安排
```swift
public struct ExamArrangement {
    let id: Int                   // 记录ID
    let courseId: String          // 课程号(带版本)
    let courseCode: String        // 课程代码
    let courseName: String        // 课程名称
    let classId: String           // 行政班号
    let className: String         // 行政班名称
    let classNumber: String       // 上课班号
    let studentId: String         // 学号
    let studentName: String       // 学生姓名
    let examLocation: String?     // 考试地点
    let examTime: String?         // 考试时间
    let examType: String          // 考试类型(如"学分制考试")
    let studyType: String         // 修读类型(如"主修")
    let campus: String            // 校区
    let term: String              // 学期
    // ... 更多字段
}
```

#### StudentBasicInfo - 学生基本信息
```swift
public struct StudentBasicInfo {
    let name: String              // 姓名
    let studentNumber: String     // 学号
    let gender: String            // 性别
    let birthday: String          // 出生日期
    let collegeName: String       // 学院名称
    let major: String             // 专业名称
    let className: String         // 班级
    let grade: Int                // 年级
    let studyLength: String       // 学制
    let studentStatus: String     // 学籍情况
    let campus: String            // 校区名称
    let phone: String             // 手机号
    let dormitoryNumber: String   // 宿舍编号
    // ... 更多字段
}
```

#### EvaluatableClass - 可评价课程
```swift
public struct EvaluatableClass {
    let classId: String           // 班级号
    let courseCode: String        // 课程代码
    let courseName: String        // 课程名称
    let courseSerial: String      // 课程序列号
    let categoryCode: String      // 类别代码
    let teacherCode: String       // 教师代码
    let teacherName: String       // 教师名称
    let evaluationStatus: String? // 评价状态
    let evaluationId: Int         // 评价ID
    let teacherId: String         // 教师ID
}
```


## 错误处理

```swift
do {
    let grades = try await app.getGrades()
    // 处理成功
} catch CCZUError.invalidCredentials {
    // 账号或密码错误
    print("账号或密码错误，请检查输入")
} catch CCZUError.ssoLoginFailed(let reason) {
    // SSO登录失败
    print("SSO登录失败: \(reason)")
} catch CCZUError.notLoggedIn {
    print("未登录,请先登录")
} catch CCZUError.loginFailed(let reason) {
    print("登录失败: \(reason)")
} catch CCZUError.networkError(let error) {
    print("网络错误: \(error)")
} catch {
    print("未知错误: \(error)")
}
```

### 常见错误及处理

| 错误类型 | 含义 | 处理建议 |
|---------|------|---------|
| `invalidCredentials` | 账号或密码错误 | 检查学号和密码是否正确输入 |
| `ssoLoginFailed` | SSO登录失败 | 检查网络连接或SSO服务器状态 |
| `loginFailed` | 登录失败 | 检查网络连接或服务器状态 |
| `networkError` | 网络错误 | 检查网络连接是否正常 |
| `notLoggedIn` | 未登录 | 调用 `login()` 方法进行登录 |
| `decodingError` | 数据解析错误 | API返回格式可能已更新，请检查 |
| `missingData` | 缺少数据 | 确保当前学期数据完整 |

## 与 Rust 版本的区别

### 优势
- ✅ **类型安全**: Swift 的强类型系统提供更好的编译时检查
- ✅ **现代异步**: 使用 Swift 原生的 async/await 语法
- ✅ **Apple 生态**: 针对 Apple 平台优化,与 SwiftUI 等框架无缝集成
- ✅ **内存安全**: 自动引用计数,无需手动管理生命周期

### 功能对应
| Rust 版本 | Swift 版本 |
|-----------|-----------|
| `DefaultClient` | `DefaultHTTPClient` |
| `SSOUniversalLogin` | `SSOLogin` protocol |
| `JwqywxApplication` | `JwqywxApplication` |
| `CalendarParser` | `CalendarParser` |
| `Arc<RwLock<T>>` | `actor PropertyStorage` |

## 贡献

欢迎提交 Issue 和 Pull Request!

## 许可证

MIT License

## 相关项目

- [cczuni](https://github.com/CCZU-OSSA/cczuni) - Rust 版本
- [CCZU-Client-API](https://github.com/CCZU-OSSA/CCZU-Client-API) - 原始版本

## 致谢

感谢 CCZU-OSSA 团队的开源贡献。
