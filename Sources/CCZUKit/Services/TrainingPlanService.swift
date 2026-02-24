import Foundation

extension JwqywxApplication {
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
        let url = CCZUConstants.Jwqywx.trainingPlanURL
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
            .appendingPathComponent(CCZUConstants.Jwqywx.cacheDirectoryName, isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("\(CCZUConstants.Jwqywx.trainingPlanCachePrefix)\(studentNumber)\(CCZUConstants.Jwqywx.trainingPlanCacheExtension)")
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
}
