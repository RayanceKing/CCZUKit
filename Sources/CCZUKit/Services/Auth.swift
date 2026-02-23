import Foundation

extension JwqywxApplication {
    /// 登录教务企业微信
    public func login() async throws -> Message<LoginUserData> {
        // 使用抓包信息：端口8180，HTTP，且登录时不需要Authorization头
        let url = CCZUConstants.Jwqywx.loginURL
        
        let loginData: [String: String] = [
            "userid": client.account.username,
            "userpwd": client.account.password
        ]
        
        // 确保登录请求不携带Authorization
        customHeaders.removeValue(forKey: CCZUConstants.Jwqywx.authHeader)
        
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
        authorizationToken = "\(CCZUConstants.Jwqywx.bearerPrefix)\(token)"
        authorizationId = userData.id
        studentNumber = userData.userid
        
        // 更新headers：后续接口需要Authorization
        customHeaders[CCZUConstants.Jwqywx.authHeader] = authorizationToken
        
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
        
        let url = CCZUConstants.Jwqywx.gradesURL
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
        
        let url = CCZUConstants.Jwqywx.creditsAndRankURL
        let requestData = ["xh": authId]
        
        let (data, _) = try await client.postJSON(url: url, headers: customHeaders, json: requestData)
        
        let decoder = JSONDecoder()
        return try decoder.decode(Message<StudentPoint>.self, from: data)
    }
    
    // MARK: - 学期信息
    
    /// 获取所有学期
    public func getTerms() async throws -> Message<Term> {
        let url = CCZUConstants.Jwqywx.termsURL
        let (data, _) = try await client.get(url: url)
        
        let decoder = JSONDecoder()
        return try decoder.decode(Message<Term>.self, from: data)
    }
}
