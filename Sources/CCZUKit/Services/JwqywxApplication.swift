import Foundation

/// 教务企业微信应用
public final class JwqywxApplication: @unchecked Sendable {
    private let client: DefaultHTTPClient
    private var authorizationToken: String?
    private var authorizationId: String?
    private var studentNumber: String?
    private var customHeaders: [String: String]
    private var trainingPlanCache: TrainingPlan?
    
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
            throw CCZUError.loginFailed("HTTP Status code: \(response.statusCode)")
        }
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<LoginUserData>.self, from: data)
        
        guard let token = message.token else {
            throw CCZUError.loginFailed("未收到认证令牌")
        }
        
        guard let userData = message.message.first else {
            throw CCZUError.loginFailed("未收到用户数据")
        }
        
        // 检查账号密码是否错误：用户ID为空表示登录失败
        if userData.id.isEmpty || userData.userid.isEmpty {
            throw CCZUError.invalidCredentials
        }
        
        // 保存token和id
        authorizationToken = "Bearer \(token)"
        authorizationId = userData.id
        studentNumber = userData.userid
        
        // 更新headers：后续接口需要Authorization
        customHeaders["Authorization"] = authorizationToken
        
        // 自动预取培养方案（忽略错误以不影响登录流程）
        Task { [weak self] in
            do { _ = try await self?.prefetchTrainingPlan() } catch { }
        }
        
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

    // MARK: - 培养方案

    /// 获取并缓存培养方案（含磁盘缓存）
    public func getTrainingPlan() async throws -> TrainingPlan {
        if let cached = trainingPlanCache { return cached }
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        guard let stuNum = studentNumber else { throw CCZUError.notLoggedIn }

        // 先尝试读取磁盘缓存
        if let disk = try? loadTrainingPlanFromDisk(studentNumber: stuNum) {
            trainingPlanCache = disk
            return disk
        }

        // 真实端点
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/cj_xh_jxjh_cj")!
        let requestData: [String: String] = [
            "xh": stuNum,
            "yhid": authId
        ]

        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        let plan = try TrainingPlanParser.parse(from: data)
        trainingPlanCache = plan
        try? saveTrainingPlanToDisk(plan, studentNumber: stuNum)
        return plan
    }

    /// 预取培养方案（触发网络并落盘）
    @discardableResult
    public func prefetchTrainingPlan() async throws -> TrainingPlan {
        guard let _ = authorizationId, let _ = studentNumber else { throw CCZUError.notLoggedIn }
        return try await getTrainingPlan()
    }

    /// 清除培养方案缓存
    public func clearTrainingPlanCache() {
        trainingPlanCache = nil
    }

    // MARK: - 磁盘缓存帮助
    private func cacheURL(studentNumber: String) throws -> URL {
        let fm = FileManager.default
        let dir = try fm.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("CCZUKit", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("training_plan_\(studentNumber).json")
    }

    private func saveTrainingPlanToDisk(_ plan: TrainingPlan, studentNumber: String) throws {
        let url = try cacheURL(studentNumber: studentNumber)
        let data = try JSONEncoder().encode(plan)
        try data.write(to: url, options: .atomic)
    }

    private func loadTrainingPlanFromDisk(studentNumber: String) throws -> TrainingPlan? {
        let url = try cacheURL(studentNumber: studentNumber)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(TrainingPlan.self, from: data)
    }

    /// 删除磁盘缓存
    public func deleteTrainingPlanDiskCache() {
        guard let stuNum = studentNumber, let url = try? cacheURL(studentNumber: stuNum) else { return }
        try? FileManager.default.removeItem(at: url)
    }
    
    // MARK: - 学生信息
    
    /// 获取学生基本信息
    public func getStudentBasicInfo() async throws -> Message<StudentBasicInfo> {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        guard let stuNum = studentNumber else {
            throw CCZUError.notLoggedIn
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xs_xh_jbxx")!
        let requestData = [
            "xh": stuNum,
            "yhid": authId
        ]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        return try decoder.decode(Message<StudentBasicInfo>.self, from: data)
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
    
    /// 获取指定学期的考试安排
    /// - Parameters:
    ///   - term: 学期，格式如 "25-26-1"，如果为空则获取当前学期
    ///   - examType: 考试类型，默认为 "学分制考试"
    /// - Returns: 考试安排列表
    public func getExamArrangements(term: String? = nil, examType: String = "学分制考试") async throws -> [ExamArrangement] {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        // 如果没有指定学期，获取当前学期
        let examTerm: String
        if let term = term {
            examTerm = term
        } else {
            let terms = try await getTerms()
            guard let currentTerm = terms.message.first?.term else {
                throw CCZUError.missingData("No term found")
            }
            examTerm = currentTerm
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/ks_xs_kslb")!
        
        let requestData: [String: String] = [
            "xq": examTerm,
            "yhdm": client.account.username,
            "dm": examType,
            "yhid": authId
        ]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<ExamArrangement>.self, from: data)
        
        return message.message
    }
    
    /// 获取当前学期的考试安排
    public func getCurrentExamArrangements() async throws -> [ExamArrangement] {
        return try await getExamArrangements()
    }
    
    // MARK: - 教师评价
    
    /// 获取指定学期可评价的课程列表
    /// - Parameter term: 学期，格式如 "25-26-1"
    /// - Returns: 可评价课程列表
    public func getEvaluatableClasses(term: String) async throws -> [EvaluatableClass] {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/pj_xspj_kcxx")!
        
        let requestData: [String: String] = [
            "pjxq": term,
            "xh": client.account.username,
            "yhid": authId
        ]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<EvaluatableClass>.self, from: data)
        
        return message.message
    }
    
    /// 获取当前学期可评价的课程列表
    public func getCurrentEvaluatableClasses() async throws -> [EvaluatableClass] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else {
            throw CCZUError.missingData("No term found")
        }
        return try await getEvaluatableClasses(term: currentTerm)
    }
    
    /// 获取指定学期已提交的评价信息
    /// - Parameter term: 学期，格式如 "25-26-1"
    /// - Returns: 已提交的评价列表
    public func getSubmittedEvaluations(term: String) async throws -> [SubmittedEvaluation] {
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/pj_xh_pjxx")!
        
        let requestData: [String: String] = [
            "pjxq": term,
            "xh": client.account.username
        ]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        let message = try decoder.decode(Message<SubmittedEvaluation>.self, from: data)
        
        return message.message
    }
    
    /// 获取当前学期已提交的评价信息
    public func getCurrentSubmittedEvaluations() async throws -> [SubmittedEvaluation] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else {
            throw CCZUError.missingData("No term found")
        }
        return try await getSubmittedEvaluations(term: currentTerm)
    }
    
    /// 提交教师评价
    /// - Parameters:
    ///   - term: 学期，格式如 "25-26-1"
    ///   - evaluatableClass: 可评价课程信息
    ///   - overallScore: 总体评分，建议值为90
    ///   - scores: 各项评分数组，例如 [100,80,100,80,100,80]
    ///   - comments: 评价意见
    public func submitTeacherEvaluation(
        term: String,
        evaluatableClass: EvaluatableClass,
        overallScore: Int,
        scores: [Int],
        comments: String
    ) async throws {
        guard let authId = authorizationId else {
            throw CCZUError.notLoggedIn
        }
        
        // 将分数数组转换为逗号分隔的字符串，末尾加逗号
        let scoresString = scores.map(String.init).joined(separator: ",") + ","
        
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/pj_insert_xspj")!
        
        let requestData: [String: String] = [
            "pjxq": term,
            "yhdm": client.account.username,
            "jsdm": evaluatableClass.teacherCode,
            "kcdm": evaluatableClass.courseCode,
            "zhdf": String(overallScore),
            "pjjg": scoresString,
            "yjjy": comments,
            "yhid": authId
        ]
        
        let (_, response) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        guard response.statusCode == 200 else {
            throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
        }
    }
    
    // MARK: - 电费查询
    
    /// 查询校区列表
    /// - Returns: 可用的校区列表
    public func getElectricityAreas() async throws -> [ElectricityArea] {
        // 预定义的校区配置
        return [
            ElectricityArea(area: "西太湖校区", areaname: "西太湖校区", aid: "0030000000002501"),
            ElectricityArea(area: "武进校区", areaname: "武进校区", aid: "0030000000002502"),
            ElectricityArea(area: "西太湖校区1-7,10-11", areaname: "西太湖校区1-7,10-11", aid: "0030000000002503")
        ]
    }
    
    /// 获取指定校区的建筑物列表
    /// - Parameter area: 校区信息
    /// - Returns: 建筑物列表
    public func getBuildings(area: ElectricityArea) async throws -> [Building] {
        let url = URL(string: "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecBuilding.html")!
        
        let areaDict: [String: String] = ["area": area.area, "areaname": area.areaname]
        let areaJson = try String(data: JSONEncoder().encode(areaDict), encoding: .utf8) ?? ""
        
        let payload: [String: String] = [
            "aid": area.aid,
            "account": "1",
            "area": areaJson
        ]
        
        var headers = customHeaders
        headers["User-Agent"] = "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340157 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"
        
        let (data, response) = try await client.postForm(url: url, headers: headers, formData: payload)
        
        guard response.statusCode == 200 else {
            throw CCZUError.networkError(NSError(domain: "HTTP", code: response.statusCode))
        }
        
        let decoder = JSONDecoder()
        let json = try decoder.decode([String: [Building]].self, from: data)
        return json["buildingtab"] ?? []
    }
    
    /// 查询电费信息
    /// - Parameters:
    ///   - area: 校区信息
    ///   - building: 建筑物信息
    ///   - roomId: 房间ID
    /// - Returns: 电费查询结果
    public func queryElectricity(area: ElectricityArea, building: Building, roomId: String) async throws -> ElectricityResponse {
        let url = URL(string: "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecRoomInfo.html")!
        
        let areaDict: [String: String] = ["area": area.area, "areaname": area.areaname]
        let buildingDict: [String: String] = ["building": building.building, "buildingid": building.buildingid]
        let floorDict: [String: String] = ["floorid": "", "floor": ""]
        let roomDict: [String: String] = ["room": "", "roomid": roomId]
        
        let areaJson = try String(data: JSONEncoder().encode(areaDict), encoding: .utf8) ?? ""
        let buildingJson = try String(data: JSONEncoder().encode(buildingDict), encoding: .utf8) ?? ""
        let floorJson = try String(data: JSONEncoder().encode(floorDict), encoding: .utf8) ?? ""
        let roomJson = try String(data: JSONEncoder().encode(roomDict), encoding: .utf8) ?? ""
        
        let payload: [String: String] = [
            "aid": area.aid,
            "account": "1",
            "area": areaJson,
            "building": buildingJson,
            "floor": floorJson,
            "room": roomJson
        ]
        
        var headers = customHeaders
        headers["User-Agent"] = "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340125 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"
        
        let (data, response) = try await client.postForm(url: url, headers: headers, formData: payload)
        
        guard response.statusCode == 200 else {
            throw CCZUError.networkError(NSError(domain: "HTTP", code: response.statusCode))
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(ElectricityResponse.self, from: data)
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
