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

## 错误处理

```swift
do {
    let grades = try await app.getGrades()
    // 处理成功
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
