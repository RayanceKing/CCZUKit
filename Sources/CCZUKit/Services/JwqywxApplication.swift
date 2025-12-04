import Foundation

/// 教务企业微信应用
public final class JwqywxApplication: @unchecked Sendable {
    private let client: DefaultHTTPClient
    private var authorizationToken: String?
    private var authorizationId: String?
    private var customHeaders: [String: String]
    
    public init(client: DefaultHTTPClient) {
        self.client = client
        self.customHeaders = CCZUConstants.defaultHeaders
        self.customHeaders["Referer"] = "http://jwqywx.cczu.edu.cn/"
        self.customHeaders["Origin"] = "http://jwqywx.cczu.edu.cn"
    }
    
    // MARK: - 登录
    
    /// 登录教务企业微信
    public func login() async throws -> Message<LoginUserData> {
        // 使用抓包信息：端口8180，HTTP，且登录时不需要Authorization头
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/login")!
        
        let loginData: [String: String] = [
            "userid": client.account.username,
            "userpwd": client.account.password
        ]
        
        // 确保登录请求不携带Authorization
        customHeaders.removeValue(forKey: "Authorization")
        
        let (data, response) = try await client.postJSON(url: url, headers: customHeaders, json: loginData)
        
        guard response.statusCode == 200 else {
            throw CCZUError.loginFailed("Status code: \(response.statusCode)")
        }
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<LoginUserData>.self, from: data)
        
        guard let token = message.token else {
            throw CCZUError.loginFailed("No token received")
        }
        
        guard let userData = message.message.first else {
            throw CCZUError.loginFailed("No user data received")
        }
        
        // 保存token和id
        authorizationToken = "Bearer \(token)"
        authorizationId = userData.id
        
        // 更新headers：后续接口需要Authorization
        customHeaders["Authorization"] = authorizationToken
        
        return message
    }
    
    // MARK: - 成绩查询
    
    /// 获取成绩
    public func getGrades() async throws -> Message<CourseGrade> {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/cj_xh")!
        let requestData = ["xh": authId]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        return try decoder.decode(Message<CourseGrade>.self, from: data)
    }
    
    /// 获取学分绩点和排名
    public func getCreditsAndRank() async throws -> Message<StudentPoint> {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/cj_xh_xfjd")!
        let requestData = ["xh": authId]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        return try decoder.decode(Message<StudentPoint>.self, from: data)
    }
    
    // MARK: - 学期信息
    
    /// 获取所有学期
    public func getTerms() async throws -> Message<Term> {
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xqall")!
        let (data, _) = try await client.get(url: url)
        
        let decoder = JSONDecoder()
        return try decoder.decode(Message<Term>.self, from: data)
    }
    
    // MARK: - 课表查询
    
    /// 获取指定学期的课表
    public func getClassSchedule(term: String) async throws -> [[RawCourse]] {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/kb_xq_xh")!
        
        let requestData: [String: String] = [
            "xh": client.account.username,
            "xq": term,
            "yhid": authId
        ]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        let jsonObject = try decoder.decode(Message<CourseScheduleRow>.self, from: data)
        
        return jsonObject.message.map { $0.toCourses() }
    }
    
    /// 获取当前学期的课表
    public func getCurrentClassSchedule() async throws -> [[RawCourse]] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else {
            throw CCZUError.missingData("No term found")
        }
        return try await getClassSchedule(term: currentTerm)
    }
    
    // MARK: - 考试安排查询
    
    /// 获取考试安排
    public func getExamArrangements() async throws -> [ExamArrangement] {
        guard let _ = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/ks_xs_kslb")!
        
        let requestData: [String: String] = [:]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<ExamArrangement>.self, from: data)
        
        return message.message
    }
}

// MARK: - 课表行数据

private struct CourseScheduleRow: Decodable, Sendable {
    let fields: [String: AnyCodable]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.fields = dict
    }
    
    func toCourses() -> [RawCourse] {
        var courses: [String] = []
        var teachers: [String: String] = [:]
        
        // 提取课程信息 (kc1-kc7)
        for index in 1...7 {
            let key = "kc\(index)"
            if let courseValue = fields[key], let course = courseValue.stringValue {
                courses.append(course)
            } else {
                courses.append("")
            }
        }
        
        // 提取教师信息 (kcmc1-kcmc20 和 skjs1-skjs20)
        for index in 1...20 {
            let nameKey = "kcmc\(index)"
            let teacherKey = "skjs\(index)"
            
            if let nameValue = fields[nameKey], let name = nameValue.stringValue,
               let teacherValue = fields[teacherKey], let teacher = teacherValue.stringValue {
                teachers[name] = teacher
            }
        }
        
        // 组合课程和教师信息
        return courses.map { course in
            let courseParts = course.split(separator: "/")
            let teacherParts = courseParts.map { part -> String in
                let courseName = part.split(separator: " ").first.map(String.init) ?? ""
                return teachers[courseName] ?? ""
            }
            
            let teacher = teacherParts.filter { !$0.isEmpty }.joined(separator: ",/")
            return RawCourse(course: course, teacher: teacher)
        }
    }
}

// MARK: - AnyCodable辅助类型

private enum AnyCodableValue: Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case null
}

private struct AnyCodable: Decodable, Sendable {
    let value: AnyCodableValue
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let intValue = try? container.decode(Int.self) {
            value = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            value = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            value = .string(stringValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            value = .bool(boolValue)
        } else if container.decodeNil() {
            value = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
        }
    }
    
    var stringValue: String? {
        if case .string(let str) = value {
            return str
        }
        return nil
    }
}
