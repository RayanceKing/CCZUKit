//
//  TrainingPlan.swift
//  CCZUKit
//
//  Created by rayanceking on 2025/12/12.
//

import Foundation

/// 培养方案课程条目（来自接口原始字段）
public struct RawTrainingPlanItem: Codable {
    public let nj: Int?            // 年级
    public let zydm: String?       // 专业代码
    public let xz: String?         // 学制（年）
    public let xq: Int             // 学期
    public let kcdm: String        // 课程代码
    public let kcmc: String        // 课程名称（含空格填充）
    public let lbdh: String        // 类别代号（A1/B1/B2/C1/C3/S等）
    public let xf: Double          // 学分
    public let lbmc: String        // 类别名称（中文）
    public let xh: String?         // 学号
    public let kscj: Double?       // 成绩
    public let lb: String?         // 类别（必修/专业任选/实践环节）
    public let zymc: String?       // 专业名称
}

/// 课程类型归类（UI视图需要的三类 + 实践）
public enum PlanCourseType: String, Codable {
    case required    // 必修（对应 A1/B1/C1）
    case elective    // 选修（对应 C3 及其他任选）
    case practice    // 实践（对应 S）
}

/// 计划课程（用于App展示）
public struct PlanCourse: Codable, Identifiable {
    public let id: String
    public let name: String
    public let code: String
    public let credits: Double
    public let type: PlanCourseType
    public let teacher: String?
}

/// 培养方案聚合模型
public struct TrainingPlan: Codable {
    public let majorName: String
    public let degree: String
    public let durationYears: Int
    public let totalCredits: Double
    public let requiredCredits: Double
    public let electiveCredits: Double
    public let practiceCredits: Double
    public let objectives: String?
    public let coursesBySemester: [Int: [PlanCourse]]
}

/// 培养方案解析器
public enum TrainingPlanParser {
    /// 从接口原始 JSON 解析并聚合为 TrainingPlan
    /// - Parameter data: 原始响应数据（包含 `{"status":0,"message":[...]}`）
    /// - Returns: 聚合后的培养方案
    public static func parse(from data: Data) throws -> TrainingPlan {
        struct Root: Codable { let status: Int; let message: [RawTrainingPlanItem] }
        let root = try JSONDecoder().decode(Root.self, from: data)
        let items = root.message

        // 取专业名与学制
        let majorName = items.first?.zymc?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let durationYears = Int(items.first?.xz ?? "0") ?? 0

        // 课程按学期分组并映射类型
        var coursesBySemester: [Int: [PlanCourse]] = [:]
        var requiredCredits = 0.0
        var electiveCredits = 0.0
        var practiceCredits = 0.0

        for item in items {
            let code = item.kcdm
            let name = item.kcmc.trimmingCharacters(in: .whitespacesAndNewlines)
            let credits = item.xf
            let semester = item.xq

            // 类型映射：
            // - 必修学分: A1(通识教育必修)、B1(学科基础必修)、C1(专业必修)
            // - 选修学分: C3(专业任选) 以及其他任选
            // - 实践学分: S(实践环节)
            let type: PlanCourseType
            switch item.lbdh.trimmingCharacters(in: .whitespaces) {
            case "A1", "B1", "C1":
                type = .required
                requiredCredits += credits
            case let s where s.uppercased().hasPrefix("S"):
                type = .practice
                practiceCredits += credits
            case "C3":
                fallthrough
            default:
                type = .elective
                electiveCredits += credits
            }

            let course = PlanCourse(
                id: code,
                name: name,
                code: code,
                credits: credits,
                type: type,
                teacher: nil
            )
            coursesBySemester[semester, default: []].append(course)
        }

        // 计算总学分
        let totalCredits = requiredCredits + electiveCredits + practiceCredits

        return TrainingPlan(
            majorName: majorName,
            degree: "",
            durationYears: durationYears,
            totalCredits: totalCredits,
            requiredCredits: requiredCredits,
            electiveCredits: electiveCredits,
            practiceCredits: practiceCredits,
            objectives: nil,
            coursesBySemester: coursesBySemester
        )
    }
}
