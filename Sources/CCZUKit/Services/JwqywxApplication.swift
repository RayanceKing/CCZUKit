import Foundation

/// 教务企业微信应用
public final class JwqywxApplication: @unchecked Sendable {
    private let client: DefaultHTTPClient
    private var authorizationToken: String?
    private var authorizationId: String?
    private var studentNumber: String?
    private var customHeaders: [String: String]
    private var trainingPlanCache: TrainingPlan?
    public private(set) var lastTrainingPlanRawResponse: String?
    public var enableDebugLogging: Bool = false
    
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

        // 真实端点 - 清理参数空格，并复用学生基本信息填充必需字段
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/cj_xh_jxjh_cj")!
        let cleanStudentNumber = stuNum.trimmingCharacters(in: .whitespacesAndNewlines)
        var requestData: [String: String] = [
            // 先尝试用授权ID作为 xh（部分实现以内部ID查询更稳定）
            "xh": authId,
            "yhid": authId
        ]

        // 复用已登录实例获取的学生基本信息
        do {
            let basic = try await getStudentBasicInfo()
            if let info = basic.message.first {
                // 年级与学制用于服务端筛选培养方案
                let grade = String(info.grade)
                let studyLength = String(info.studyLength)
                requestData["nj"] = grade
                requestData["xz"] = studyLength
                // 大多实现要求专业代码，抓包亦显示可能参与查询；若存在则提供
                let majorCode = info.majorCode
                if !majorCode.isEmpty {
                    requestData["zydm"] = majorCode
                }
            }
        } catch {
            // 获取基本信息失败不阻断；服务端可能仍可返回默认方案
            print("[WARN] 获取学生基本信息失败，继续请求培养方案: \(error)")
        }
        
        // 打印调试信息
        print("[DEBUG] 培养方案请求参数: \(requestData)")

        var (data, response) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        // 打印响应状态和内容（输出完整 JSON 便于排查）
        print("[DEBUG] 培养方案响应状态: \(response.statusCode)")
        if let responseString = String(data: data, encoding: .utf8) {
            print("[DEBUG] 培养方案响应长度: \(responseString.count)")
            print("[DEBUG] 培养方案完整响应: \(responseString)")
            lastTrainingPlanRawResponse = responseString
        }
        
        var plan: TrainingPlan
        do {
            let basic = try? await getStudentBasicInfo()
            plan = try TrainingPlanParser.parse(from: data, basicInfo: basic?.message.first)
        } catch {
            // 若失败或返回空数组，回退用学号作为 xh 再试一次
            print("[WARN] 培养方案首次解析失败，尝试用学号重试: \(error)")
            requestData["xh"] = cleanStudentNumber
            print("[DEBUG] 培养方案回退参数: \(requestData)")
            let retry = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
            data = retry.0
            response = retry.1
            if let responseString = String(data: data, encoding: .utf8) {
                print("[DEBUG] 培养方案回退响应长度: \(responseString.count)")
                print("[DEBUG] 培养方案回退完整响应: \(responseString)")
                lastTrainingPlanRawResponse = responseString
            }
            let basic = try? await getStudentBasicInfo()
            plan = try TrainingPlanParser.parse(from: data, basicInfo: basic?.message.first)
        }
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
        
        let areaJSON = """
        {"areaname":"\(area.areaname)","area":"\(area.area)"}
        """
        
        let payload: [String: String] = [
            "account": "1",
            "area": areaJSON,
            "aid": area.aid
        ]
        
        var headers = customHeaders
        headers["User-Agent"] = "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340157 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"
        
        let (data, response) = try await client.postForm(url: url, headers: headers, formData: payload)
        
        guard response.statusCode == 200 else {
            throw CCZUError.networkError(NSError(domain: "HTTP", code: response.statusCode))
        }
        
        // 使用 JSONSerialization 手动解析，因为后端返回的 JSON 格式可能不标准
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let buildingArray = json["buildingtab"] as? [[String: Any]] else {
            return []
        }
        
        let buildings = buildingArray.compactMap { buildingDict -> Building? in
            guard let building = buildingDict["building"] as? String,
                  let buildingid = buildingDict["buildingid"] as? String else {
                return nil
            }
            return Building(building: building, buildingid: buildingid)
        }
        
        return buildings
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

    // MARK: - 选课

    /// 检查功能权限（前置检查）
    /// - Parameters:
    ///   - userId: 用户代码（通常为学号）
    ///   - functionCode: 功能代码（如"xkbm_fsxz" 为分层选择）
    /// - Throws: 无权限时抛错
    public func checkSelectionPermission(userId: String, functionCode: String = "xkbm_fsxz") async throws {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/qx_yhdm_gnmk_syqx")!
        let body: [String: String] = [
            "yhdm": userId,
            "gnmk": functionCode,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] checkSelectionPermission body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<[String: String]>.self, from: data)
        if msg.status != 0 { throw CCZUError.unknown("选课权限检查失败") }
        if enableDebugLogging { print("[DEBUG] checkSelectionPermission OK") }
    }

    /// 获取该年级的选课批次列表（需要先确认用户身份）
    /// - Parameter grade: 年级（如 2025）
    /// - Returns: 选课批次列表
    public func getSelectionBatches(grade: Int) async throws -> [SelectionBatch] {
        guard let userId = studentNumber else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xk_xkxm_nj")!
        let body: [String: Any] = [
            "yhdm": userId,
            "nj": grade
        ]
        if enableDebugLogging { print("[DEBUG] getSelectionBatches body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectionBatch>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getSelectionBatches batches=\(msg.message.count)") }
        return msg.message
    }

    /// 检查某批次的选课权限
    /// - Parameters:
    ///   - batchCode: 批次代码（如"0003-004"）
    ///   - grade: 年级
    /// - Returns: 选课权限信息
    public func checkBatchPermission(batchCode: String, grade: Int) async throws -> SelectionPermission {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xkqx_dm_nj")!
        let body: [String: Any] = [
            "dm": batchCode,
            "nj": grade,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] checkBatchPermission body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectionPermission>.self, from: data)
        guard let perm = msg.message.first else { throw CCZUError.missingData("未获得选课权限") }
        if !perm.isAllowed { throw CCZUError.unknown("该批次对你的年级未开放选课权限") }
        if enableDebugLogging { print("[DEBUG] checkBatchPermission OK, term=\(perm.term)") }
        return perm
    }

    /// 综合前置检查后，获取当前允许批次的可选课程
    /// - Parameters:
    ///   - classCode: 班级代码
    ///   - grade: 年级（如 2025）
    /// - Returns: 可选课程列表
    public func getCurrentSelectableCoursesWithPreflight(classCode: String, grade: Int) async throws -> [SelectableCourse] {
        guard let userId = studentNumber else { throw CCZUError.notLoggedIn }
        // 1) 功能权限
        try await checkSelectionPermission(userId: userId)
        // 2) 获取批次并选择处于开放状态的批次
        let batches = try await getSelectionBatches(grade: grade)
        // 简化策略：优先选择 isOpen=true 且 xk=true 的批次；否则取最新 endDate 未过期的批次
        let candidate = batches.first { $0.isOpen && $0.isAllowed } ?? batches.sorted { ($0.endDate) > ($1.endDate) }.first
        guard let batch = candidate else { throw CCZUError.missingData("当前年级没有开放的选课批次") }
        // 3) 批次权限校验以获得正确学期
        let perm = try await checkBatchPermission(batchCode: batch.code, grade: grade)
        let term = perm.term
        // 4) 按正确学期拉取可选课程
        let courses = try await getSelectableCourses(term: term, classCode: classCode)
        if enableDebugLogging { print("[DEBUG] getCurrentSelectableCoursesWithPreflight term=\(term), courses=\(courses.count)") }
        return courses
    }
    /// 查询选课状态/课程列表（xk_xh_kbk）
    public func getSelectableCourses(term: String, classCode: String) async throws -> [SelectableCourse] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xk_xh_kbk")!
        let body: [String: String] = [
            "xq": term,
            "bh": classCode,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] xk_xh_kbk body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectableCourse>.self, from: data)
        if enableDebugLogging { print("[DEBUG] xk_xh_kbk items=\(msg.message.count)") }
        return msg.message
    }

    /// 查询当前学期、本人班级的可选课程
    public func getCurrentSelectableCourses() async throws -> [SelectableCourse] {
        let terms = try await getTerms()
        guard let currentTerm = terms.message.first?.term else { throw CCZUError.missingData("No term found") }
        let info = try await getStudentBasicInfo()
        guard let basic = info.message.first else { throw CCZUError.missingData("No basic info") }
        return try await getSelectableCourses(term: currentTerm, classCode: basic.classCode)
    }

    /// 选课（xk_insert_xfz），最多5门一组，自动分片
    /// - Parameters:
    ///   - term: 学期，如 "25-26-2"
    ///   - items: 待选课程（来自 getSelectableCourses）
    /// - Throws: 抛出首个失败错误
    public func selectCourses(term: String, items: [SelectableCourse]) async throws {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }

        // 获取姓名用于 xm 字段
        let basic = try await getStudentBasicInfo()
        let name = basic.message.first?.name ?? ""

        // 过滤：仅对未选(xkqk为空)的课程进行提交
        let pending = items.filter { $0.selectionStatus.isEmpty }
        if enableDebugLogging { print("[DEBUG] select pending count=\(pending.count) total=\(items.count)") }

        // 按5个分片
        let chunks: [[SelectableCourse]] = stride(from: 0, to: pending.count, by: 5).map {
            Array(pending[$0..<min($0+5, pending.count)])
        }

        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xk_insert_xfz")!
        let decoder = JSONDecoder()

        for chunk in chunks where !chunk.isEmpty {
            // postdata 需要与抓包一致的字段集合
            let postdata: [[String: Any]] = chunk.map { c in
                [
                    "xq": term,
                    "bh": c.classCode,
                    "bj": c.className,
                    "kcdm": c.courseCode,
                    "kcmc": c.courseName,
                    "kch": c.courseSerial,
                    "lbdh": c.categoryCode,
                    "xs": c.hours,
                    "xf": c.credits,
                    "ksfs": c.examTypeName,
                    "kkrs": c.capacity,
                    "kcxbdm": c.courseAttrCode,
                    "jsdm": c.teacherCode,
                    "jsmc": c.teacherName,
                    "ksxzm": c.isExamType,
                    "ksfsm": c.examMode,
                    "idn": c.idn,
                    "xkqk": c.selectionStatus,
                    "xkidn": c.selectedId,
                    "xklb": c.studyType
                ]
            }

            // 构造 JSON 体
            let payload: [String: Any] = [
                "xq": term,
                "xh": stuNum,
                "xm": name,
                "postdata": postdata,
                "yhid": authId
            ]
            if enableDebugLogging { print("[DEBUG] xk_insert_xfz chunk size=\(chunk.count)") }

            // 通过 JSONSerialization 发送（保持与 postJSON 一致的 headers），失败重试一次
            var lastError: Error?
            var success = false
            for _ in 0..<2 { // 最多2次（含首次）
                do {
                    let (data, response) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: payload)
                    guard response.statusCode == 200 else {
                        throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
                    }
                    let res = try decoder.decode(SimpleJWResponse.self, from: data)
                    if enableDebugLogging { print("[DEBUG] xk_insert_xfz status=\(res.status) messageInt=\(String(describing: res.messageInt)) messageString=\(String(describing: res.messageString))") }
                    if res.status == 0 {
                        success = true
                        break
                    } else {
                        throw CCZUError.unknown("选课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
                    }
                } catch {
                    lastError = error
                    // 继续下一次尝试
                }
            }
            if !success {
                throw lastError ?? CCZUError.unknown("选课失败且重试后仍未成功")
            }
        }
    }

    /// 根据 idn 列表选课（自动查询并匹配条目）
    public func selectCoursesByIdn(term: String, classCode: String, idns: [Int]) async throws {
        let all = try await getSelectableCourses(term: term, classCode: classCode)
        let map = Dictionary(uniqueKeysWithValues: all.map { ($0.idn, $0) })
        let items = idns.compactMap { map[$0] }
        guard !items.isEmpty else { return }
        try await selectCourses(term: term, items: items)
    }

    /// 批量退课（xk_delete_xfzxkmd）
    /// - Parameter selectedIds: xkidn 列表（已选课程记录ID）
    public func dropCourses(selectedIds: [Int]) async throws -> String {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        guard !selectedIds.isEmpty else { return "" }

        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/xk_delete_xfzxkmd")!
        // 按抓包格式，结尾带逗号
        let idnlist = selectedIds.map(String.init).joined(separator: ",") + ","
        let body: [String: String] = [
            "idnlist": idnlist,
            "yhid": authId
        ]
        let (data, response) = try await client.postJSON(url: url, headers: customHeaders, json: body)
        guard response.statusCode == 200 else {
            throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
        }
        let decoder = JSONDecoder()
        let res = try decoder.decode(SimpleJWResponse.self, from: data)
        if res.status != 0 {
            throw CCZUError.unknown("退课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
        }
        return res.messageString ?? ""
    }

    // MARK: - 通识类选修课程

    /// 获取通识类选修课程可选列表（yxk_xk_xh_kxkc_gx）
    /// - Parameters:
    ///   - term: 学期
    ///   - classCode: 班级代码
    ///   - grade: 年级
    ///   - campus: 校区名称
    /// - Returns: 可选课程列表
    public func getGeneralElectiveCourses(term: String, classCode: String, grade: Int, campus: String) async throws -> [GeneralElectiveCourse] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/yxk_xk_xh_kxkc_gx")!
        let body: [String: Any] = [
            "xq": term,
            "bh": classCode,
            "nj": grade,
            "bmmc": campus,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveCourses body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<GeneralElectiveCourse>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getGeneralElectiveCourses courses=\(msg.message.count)") }
        return msg.message
    }

    /// 获取已选通识类选修课程（yxk_xk_xh_yxkc_gx）
    /// - Parameter term: 学期
    /// - Returns: 已选课程列表
    public func getSelectedGeneralElectiveCourses(term: String) async throws -> [SelectedGeneralElectiveCourse] {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/yxk_xk_xh_yxkc_gx")!
        let body: [String: String] = [
            "xq": term,
            "xh": stuNum,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] getSelectedGeneralElectiveCourses body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<SelectedGeneralElectiveCourse>.self, from: data)
        if enableDebugLogging { print("[DEBUG] getSelectedGeneralElectiveCourses courses=\(msg.message.count)") }
        return msg.message
    }

    /// 检查通识类选修课程批次权限（yxk_xkqx_dm_nj）
    /// - Parameters:
    ///   - batchCode: 批次代码
    ///   - grade: 年级
    /// - Returns: 权限信息
    public func checkGeneralElectivePermission(batchCode: String, grade: Int) async throws -> GeneralElectivePermission {
        guard let authId = authorizationId else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/yxk_xkqx_dm_nj")!
        let body: [String: Any] = [
            "dm": batchCode,
            "nj": grade,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] checkGeneralElectivePermission body=\(body)") }
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: body)
        let decoder = JSONDecoder()
        let msg = try decoder.decode(Message<GeneralElectivePermission>.self, from: data)
        guard let perm = msg.message.first else { throw CCZUError.missingData("未获得通识选课权限") }
        if enableDebugLogging { print("[DEBUG] checkGeneralElectivePermission OK, term=\(perm.term)") }
        return perm
    }

    /// 选通识类选修课程（yxk_xk_insert_ggxx），最多2门一组，自动分片
    /// - Parameters:
    ///   - term: 学期
    ///   - courses: 待选课程（来自 getGeneralElectiveCourses）
    /// - Throws: 抛出首个失败错误
    public func selectGeneralElectiveCourses(term: String, courses: [GeneralElectiveCourse]) async throws {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }

        // 获取姓名用于 xm 字段（暂时未使用）
        let basic = try await getStudentBasicInfo()
        _ = basic.message.first?.name ?? ""

        // 过滤：仅对可选课程进行提交（kxrs > 0）
        let available = courses.filter { $0.availableCount > 0 }
        if enableDebugLogging { print("[DEBUG] selectGeneralElective available count=\(available.count) total=\(courses.count)") }

        // 按2个分片（通识选课最多2门）
        let chunks: [[GeneralElectiveCourse]] = stride(from: 0, to: available.count, by: 2).map {
            Array(available[$0..<min($0+2, available.count)])
        }

        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/yxk_xk_insert_ggxx")!
        let decoder = JSONDecoder()

        for chunk in chunks where !chunk.isEmpty {
            // 构造请求体
            let payload: [String: Any] = [
                "xq": term,
                "xh": stuNum,
                "kcxh": chunk[0].courseSerial,
                "zc": chunk[0].week,
                "jc1": chunk[0].startSlot,
                "jc2": chunk[0].endSlot,
                "xxrs": chunk[0].capacity,
                "xkmc": chunk.count,  // 选课门数
                "yhid": authId
            ]
            if enableDebugLogging { print("[DEBUG] yxk_xk_insert_ggxx chunk size=\(chunk.count), courseSerial=\(chunk[0].courseSerial)") }

            // 发送请求，失败重试一次
            var lastError: Error?
            var success = false
            for _ in 0..<2 { // 最多2次（含首次）
                do {
                    let (data, response) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: payload)
                    guard response.statusCode == 200 else {
                        throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
                    }
                    let res = try decoder.decode(SimpleJWResponse.self, from: data)
                    if enableDebugLogging { print("[DEBUG] yxk_xk_insert_ggxx status=\(res.status) messageInt=\(String(describing: res.messageInt)) messageString=\(String(describing: res.messageString))") }
                    if res.status == 0 {
                        success = true
                        break
                    } else {
                        throw CCZUError.unknown("通识选课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
                    }
                } catch {
                    lastError = error
                    // 继续下一次尝试
                }
            }
            if !success {
                throw lastError ?? CCZUError.unknown("通识选课失败且重试后仍未成功")
            }
        }
    }

    /// 退通识类选修课程（yxk_xk_delete_ggxx）
    /// - Parameters:
    ///   - term: 学期
    ///   - courseSerial: 课程序号
    /// - Throws: 退课失败时抛错
    public func dropGeneralElectiveCourse(term: String, courseSerial: Int) async throws {
        guard let authId = authorizationId, let stuNum = studentNumber else { throw CCZUError.notLoggedIn }
        let url = URL(string: "http://jwqywx.cczu.edu.cn:8180/api/yxk_xk_delete_ggxx")!
        let body: [String: Any] = [
            "xq": term,
            "xh": stuNum,
            "kcxh": courseSerial,
            "yhid": authId
        ]
        if enableDebugLogging { print("[DEBUG] dropGeneralElectiveCourse body=\(body)") }
        let (data, response) = try await client.postJSON(url: url, headers: customHeaders, anyJSON: body)
        guard response.statusCode == 200 else {
            throw CCZUError.unknown("HTTP Status code: \(response.statusCode)")
        }
        let decoder = JSONDecoder()
        let res = try decoder.decode(SimpleJWResponse.self, from: data)
        if res.status != 0 {
            throw CCZUError.unknown("退通识选课失败: status=\(res.status), message=\(res.messageString ?? String(res.messageInt ?? -1))")
        }
        if enableDebugLogging { print("[DEBUG] dropGeneralElectiveCourse OK") }
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
