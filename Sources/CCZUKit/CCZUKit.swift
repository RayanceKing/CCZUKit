// The Swift Programming Language
// https://docs.swift.org/swift-book

/// CCZUKit - 常州大学API客户端库
///
/// 本库提供了访问常州大学各种服务的接口,包括:
/// - SSO统一登录
/// - 教务企业微信应用
/// - 成绩查询
/// - 课表查询
/// - 日历解析
///
/// ## 使用示例
///
/// ```swift
/// import CCZUKit
///
/// // 创建客户端
/// let client = DefaultHTTPClient(username: "学号", password: "密码")
///
/// // SSO登录
/// let loginInfo = try await client.ssoUniversalLogin()
///
/// // 创建教务应用
/// let app = JwqywxApplication(client: client)
/// try await app.login()
///
/// // 获取成绩
/// let grades = try await app.getGrades()
///
/// // 获取课表
/// let schedule = try await app.getCurrentClassSchedule()
/// ```
///
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
public struct CCZUKit {
    public static let version = "0.1.0"
    
    private init() {}
}
