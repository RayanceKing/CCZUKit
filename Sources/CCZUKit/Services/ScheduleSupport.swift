// MARK: - 课表行数据

struct CourseScheduleRow: Decodable, Sendable {
    let fields: [String: AnyCodable]
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let dict = try container.decode([String: AnyCodable].self)
        self.fields = dict
    }
    
    func toCourses(fallbackTeachersByCourseName: [String: String] = [:]) -> [RawCourse] {
        var courses: [String] = []
        var teachers: [String: String] = [:]
        var classrooms: [String: String] = [:]

        // 提取课程信息 (kc1-kc7)
        for index in 1...7 {
            let key = "kc\(index)"
            if let courseValue = fields[key], let course = courseValue.stringValue {
                courses.append(course)
            } else {
                courses.append("")
            }
        }

        // 提取教师和教室信息 (kcmc1-kcmc20, skjs1-skjs20, lbdh1-lbdh20)
        for index in 1...20 {
            let nameKey = "kcmc\(index)"
            let teacherKey = "skjs\(index)"
            let classroomKey = "lbdh\(index)"

            if let nameValue = fields[nameKey], let name = nameValue.stringValue {
                if let teacherValue = fields[teacherKey], let teacher = teacherValue.stringValue {
                    teachers[name] = teacher
                }
                if let classroomValue = fields[classroomKey], let classroom = classroomValue.stringValue,
                   !classroom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    classrooms[name] = classroom.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }

        // 组合课程、教师和教室信息
        return courses.map { course in
            let courseParts = course.split(separator: "/")
            let teacherParts = courseParts.map { part -> String in
                let partText = part.trimmingCharacters(in: .whitespacesAndNewlines)
                let matchedName = matchedCourseName(for: partText, from: teachers.keys)
                if let matchedName, let teacher = teachers[matchedName], !teacher.isEmpty {
                    return teacher
                }
                if let matchedName,
                   let teacher = fallbackTeachersByCourseName[matchedName],
                   !teacher.isEmpty {
                    return teacher
                }
                let normalizedPartText = normalizedCourseName(partText)
                let matchedNormalizedName = matchedCourseName(for: normalizedPartText, from: fallbackTeachersByCourseName.keys)
                if let matchedNormalizedName {
                    return fallbackTeachersByCourseName[matchedNormalizedName] ?? ""
                }
                return ""
            }

            // 将教室信息注入课程字符串，使 CalendarParser 能解析到教室位置
            var enhancedParts: [String] = []
            for part in courseParts {
                let partText = part.trimmingCharacters(in: .whitespacesAndNewlines)
                if partText.isEmpty {
                    enhancedParts.append(String(part))
                    continue
                }
                let matchedName = matchedCourseName(for: partText, from: classrooms.keys)
                if let matchedName, let classroom = classrooms[matchedName],
                   // 仅当课程字符串中尚未包含教室号时才注入
                   !partText.contains(classroom) {
                    if let range = part.range(of: matchedName) {
                        let afterName = part[range.upperBound...]
                        let enhanced = matchedName + " " + classroom + afterName
                        enhancedParts.append(enhanced)
                    } else {
                        enhancedParts.append(String(part))
                    }
                } else {
                    enhancedParts.append(String(part))
                }
            }
            let enhancedCourse = enhancedParts.joined(separator: "/")

            // 保留空字符串占位，确保与课程分段索引对齐，避免后续解析时教师错位
            let teacher = teacherParts.joined(separator: ",/")
            return RawCourse(course: enhancedCourse, teacher: teacher)
        }
    }

    private func normalizedCourseName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "（", with: "(")
            .replacingOccurrences(of: "）", with: ")")
    }

    private func matchedCourseName(for part: String, from names: Dictionary<String, String>.Keys) -> String? {
        let normalizedPart = normalizedCourseName(part)
        return names
            .filter { !($0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            .sorted { $0.count > $1.count }
            .first { candidate in
                let normalizedCandidate = normalizedCourseName(candidate)
                return normalizedPart.hasPrefix(normalizedCandidate)
            }
    }
}

struct CourseTeacherSupplementItem: Decodable, Sendable {
    let courseName: String
    let teacherName: String

    enum CodingKeys: String, CodingKey {
        case courseName = "kcmc"
        case teacherName = "jsmc"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespacesAndNewlines)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - AnyCodable辅助类型

enum AnyCodableValue: Sendable {
    case int(Int)
    case double(Double)
    case string(String)
    case bool(Bool)
    case null
}

struct AnyCodable: Decodable, Sendable {
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
