# CCZUKit 快速开始

## 安装

### 方式1: Swift Package Manager (推荐)

在 Xcode 中:
1. File → Add Package Dependencies
2. 输入: `https://github.com/CCZU-OSSA/cczuni.git`
3. 选择版本并添加到项目

### 方式2: Package.swift

```swift
dependencies: [
    .package(url: "https://github.com/CCZU-OSSA/cczuni.git", from: "0.1.0")
]
```

## 基础使用

### 1. 导入库

```swift
import CCZUKit
```

### 2. 创建客户端

```swift
let client = DefaultHTTPClient(
    username: "你的学号",
    password: "你的密码"
)
```

### 3. 登录

```swift
// SSO统一登录
do {
    let loginInfo = try await client.ssoUniversalLogin()
    print("登录成功")
} catch {
    print("登录失败: \(error)")
}
```

### 4. 使用教务应用

```swift
// 创建教务应用实例
let app = JwqywxApplication(client: client)

// 登录教务系统
try await app.login()

// 查询成绩
let grades = try await app.getGrades()
for grade in grades.message {
    print("\(grade.courseName): \(grade.grade)分")
}

// 查询课表
let schedule = try await app.getCurrentClassSchedule()

// 查询学分绩点
let points = try await app.getCreditsAndRank()
```

### 5. 解析课表

```swift
// 获取课表矩阵
let schedule = try await app.getCurrentClassSchedule()

// 解析课程信息
let courses = CalendarParser.parseWeekMatrix(schedule)

// 遍历课程
for course in courses {
    print("课程: \(course.name)")
    print("教师: \(course.teacher)")
    print("地点: \(course.location)")
    print("时间: 周\(course.dayOfWeek) 第\(course.timeSlot)节")
    print("周次: \(course.weeks)")
}
```

## 完整示例

```swift
import CCZUKit

@main
struct MyApp {
    static func main() async {
        do {
            // 1. 创建客户端
            let client = DefaultHTTPClient(
                username: "202012345678",
                password: "your_password"
            )
            
            // 2. SSO登录
            _ = try await client.ssoUniversalLogin()
            print("✓ SSO登录成功")
            
            // 3. 创建并登录教务应用
            let app = JwqywxApplication(client: client)
            _ = try await app.login()
            print("✓ 教务系统登录成功")
            
            // 4. 查询成绩
            let gradesResponse = try await app.getGrades()
            print("\n📊 成绩信息:")
            for grade in gradesResponse.message.prefix(3) {
                print("  \(grade.courseName): \(grade.grade)分")
            }
            
            // 5. 查询学分绩点
            let pointsResponse = try await app.getCreditsAndRank()
            if let point = pointsResponse.message.first {
                print("\n📈 学分绩点: \(point.gradePoints)")
            }
            
            // 6. 查询课表
            let schedule = try await app.getCurrentClassSchedule()
            let courses = CalendarParser.parseWeekMatrix(schedule)
            print("\n📅 本周课程: \(courses.count)门")
            
            // 7. 查询考试安排
            let exams = try await app.getCurrentExamArrangements()
            let scheduledExams = exams.filter { $0.examTime != nil }
            print("\n📝 考试安排: \(scheduledExams.count)/\(exams.count)门已安排")
            
            // 8. 教师评价
            let evaluatableClasses = try await app.getCurrentEvaluatableClasses()
            print("\n⭐ 可评价课程: \(evaluatableClasses.count)门")
            
            if let classToEvaluate = evaluatableClasses.first {
                let terms = try await app.getTerms()
                if let currentTerm = terms.message.first?.term {
                    try await app.submitTeacherEvaluation(
                        term: currentTerm,
                        evaluatableClass: classToEvaluate,
                        overallScore: 90,
                        scores: [100, 80, 100, 80, 100, 80],
                        comments: "教学质量优秀"
                    )
                    print("✓ 评价已提交")
                }
            }
            
        } catch {
            print("❌ 错误: \(error)")
        }
    }
}
```

## SwiftUI 集成示例

```swift
import SwiftUI
import CCZUKit

struct ContentView: View {
    @State private var grades: [CourseGrade] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            List(grades, id: \.courseId) { grade in
                VStack(alignment: .leading) {
                    Text(grade.courseName)
                        .font(.headline)
                    HStack {
                        Text("成绩: \(String(format: "%.1f", grade.grade))")
                        Spacer()
                        Text("学分: \(String(format: "%.1f", grade.courseCredits))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .navigationTitle("我的成绩")
            .overlay {
                if isLoading {
                    ProgressView()
                }
            }
            .alert("错误", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .task {
            await fetchGrades()
        }
    }
    
    func fetchGrades() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let client = DefaultHTTPClient(
                username: "your_username",
                password: "your_password"
            )
            
            _ = try await client.ssoUniversalLogin()
            
            let app = JwqywxApplication(client: client)
            _ = try await app.login()
            
            let response = try await app.getGrades()
            grades = response.message
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

## 错误处理

```swift
do {
    let grades = try await app.getGrades()
    // 处理成功情况
} catch CCZUError.invalidCredentials {
    // 账号或密码错误
    print("账号或密码错误，请检查输入")
} catch CCZUError.ssoLoginFailed(let reason) {
    // SSO登录失败
    print("SSO登录失败: \(reason)")
} catch CCZUError.notLoggedIn {
    // 未登录
} catch CCZUError.loginFailed(let reason) {
    // 登录失败
    print("登录失败: \(reason)")
} catch CCZUError.networkError(let error) {
    // 网络错误
    print("网络错误: \(error)")
} catch {
    // 其他错误
    print("未知错误: \(error)")
}
```

## 教师评价

### 获取可评价课程列表

```swift
// 获取当前学期可评价的课程
let evaluatableClasses = try await app.getCurrentEvaluatableClasses()

for evaluatableClass in evaluatableClasses {
    print("课程: \(evaluatableClass.courseName)")
    print("教师: \(evaluatableClass.teacherName)")
    print("学分: \(evaluatableClass.credit)")
    print("评价状态: \(evaluatableClass.evaluationStatus)")
    print("---")
}
```

### 提交评价

```swift
// 提交教师评价
let terms = try await app.getTerms()
guard let currentTerm = terms.message.first?.term else { return }

if let classToEvaluate = evaluatableClasses.first {
    try await app.submitTeacherEvaluation(
        term: currentTerm,
        evaluatableClass: classToEvaluate,
        overallScore: 90,              // 总体评分
        scores: [100, 80, 100, 80, 100, 80],  // 各项评分
        comments: "教学质量优秀，建议继续改进"
    )
    print("✓ 评价已提交成功")
}
```

### 评分说明

- **overallScore**: 总体评分,建议90分
- **scores**: 各项评分数组,常用值为 `[100, 80, 100, 80, 100, 80]`
- **comments**: 评价意见,自由输入,最多可为空字符串

## 注意事项

1. **账号安全**: 不要在代码中硬编码账号密码,使用 Keychain 等安全存储
2. **并发访问**: 客户端支持并发请求,但建议控制请求频率
3. **错误处理**: 务必正确处理各种错误情况
4. **Cookie管理**: 客户端会自动管理 Cookie,保持登录状态

## 更多信息

- 完整文档: [README.md](README.md)
- 示例代码: [Examples/Example.swift](Examples/Example.swift)
- API 参考: 查看源码注释
