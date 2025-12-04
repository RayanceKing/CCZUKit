import Foundation

/// 课程信息(已解析)
public struct ParsedCourse: Sendable {
    public let name: String
    public let teacher: String
    public let location: String
    public let weeks: [Int]
    public let dayOfWeek: Int
    public let timeSlot: Int
    
    public init(name: String, teacher: String, location: String, weeks: [Int], dayOfWeek: Int, timeSlot: Int) {
        self.name = name
        self.teacher = teacher
        self.location = location
        self.weeks = weeks
        self.dayOfWeek = dayOfWeek
        self.timeSlot = timeSlot
    }
}

/// 日历解析器
public struct CalendarParser {
    
    /// 解析周课表矩阵
    /// - Parameter matrix: 课表原始数据,格式为 [[RawCourse]]
    /// - Returns: 解析后的课程列表
    public static func parseWeekMatrix(_ matrix: [[RawCourse]]) -> [ParsedCourse] {
        var courses: [ParsedCourse] = []
        
        for (timeIndex, timeCourses) in matrix.enumerated() {
            for (dayIndex, rawCourse) in timeCourses.enumerated() {
                if rawCourse.course.isEmpty {
                    continue
                }
                
                // 解析课程字符串
                // 格式示例: "高等数学 1-16周 教学楼A101"
                let courseParts = rawCourse.course.split(separator: "/")
                
                for part in courseParts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty { continue }
                    
                    let components = trimmed.split(separator: " ").map(String.init)
                    
                    if components.isEmpty { continue }
                    
                    let name = components[0]
                    var location = ""
                    var weeks: [Int] = []
                    
                    // 解析周次和地点
                    var locationParts: [String] = []
                    for component in components.dropFirst() {
                        let compTrimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
                        if compTrimmed.isEmpty { continue }

                        // 尝试识别周次（如含“周”，或仅为数字/范围如 "1-16" 或 "17-18,"）
                        if compTrimmed.contains("周") || compTrimmed.range(of: "^\\d+(-\\d+)?[,，]?$", options: .regularExpression) != nil || compTrimmed.range(of: "单|双") != nil {
                            let parsed = parseWeeks(from: compTrimmed)
                            if !parsed.isEmpty {
                                weeks = parsed
                                continue
                            }
                        }

                        // 非周次部分视为地点或附加信息，收集起来
                        // 去除末尾逗号与其他常见分隔符
                        let cleaned = compTrimmed.trimmingCharacters(in: CharacterSet(charactersIn: ",，;:。"))
                        if !cleaned.isEmpty {
                            locationParts.append(cleaned)
                        }
                    }

                    location = locationParts.joined(separator: " ")
                    
                    // 提取对应的教师信息
                    let teacherParts = rawCourse.teacher.components(separatedBy: ",/")
                    let teacher = teacherParts.first ?? ""
                    
                    let course = ParsedCourse(
                        name: name,
                        teacher: teacher,
                        location: location,
                        weeks: weeks,
                        dayOfWeek: dayIndex + 1,
                        timeSlot: timeIndex + 1
                    )
                    
                    courses.append(course)
                }
            }
        }
        
        return courses
    }
    
    /// 解析周次字符串
    /// - Parameter weekString: 周次字符串,如 "1-16周"
    /// - Returns: 周次数组
    private static func parseWeeks(from weekString: String) -> [Int] {
        var weeks: [Int] = []
        // 规范化：去除“周”、中文标点与空白
        var cleaned = weekString.replacingOccurrences(of: "周", with: "")
        cleaned = cleaned.replacingOccurrences(of: "单", with: "单")
        cleaned = cleaned.replacingOccurrences(of: "双", with: "双")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: ",，;:。"))

        // 处理单周/双周标识
        let isOdd = cleaned.contains("单")
        let isEven = cleaned.contains("双")
        cleaned = cleaned.replacingOccurrences(of: "单", with: "")
        cleaned = cleaned.replacingOccurrences(of: "双", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)

        // 提取仅含数字和连字符的部分
        let rangeStr = cleaned.replacingOccurrences(of: "[^0-9\\-]", with: "", options: .regularExpression)

        if rangeStr.isEmpty {
            return []
        }

        if rangeStr.contains("-") {
            let parts = rangeStr.split(separator: "-").compactMap { Int($0) }
            if parts.count == 2 {
                let start = parts[0]
                let end = parts[1]
                for week in start...end {
                    if isOdd && week % 2 == 1 {
                        weeks.append(week)
                    } else if isEven && week % 2 == 0 {
                        weeks.append(week)
                    } else if !isOdd && !isEven {
                        weeks.append(week)
                    }
                }
            }
        } else if let week = Int(rangeStr) {
            weeks.append(week)
        }

        return weeks
    }
}
