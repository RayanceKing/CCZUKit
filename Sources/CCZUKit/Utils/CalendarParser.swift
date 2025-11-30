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
        
        for (dayIndex, dayCourses) in matrix.enumerated() {
            for (timeIndex, rawCourse) in dayCourses.enumerated() {
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
                    for component in components.dropFirst() {
                        if component.contains("周") {
                            weeks = parseWeeks(from: component)
                        } else {
                            location = component
                        }
                    }
                    
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
        
        // 移除"周"字
        let cleaned = weekString.replacingOccurrences(of: "周", with: "")
        
        // 处理单周/双周
        let isOdd = cleaned.contains("单")
        let isEven = cleaned.contains("双")
        let rangeStr = cleaned.replacingOccurrences(of: "[单双]", with: "", options: .regularExpression)
        
        // 解析范围
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
