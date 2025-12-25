import Foundation

// MARK: - 通用响应消息
public struct Message<T: Decodable>: Decodable, Sendable where T: Sendable {
    public let status: Int
    public let message: [T]
    public let token: String?
    
    enum CodingKeys: String, CodingKey {
        case status
        case message
        case token
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        token = try container.decodeIfPresent(String.self, forKey: .token)
        
        // 使用灵活的方式解析 message，处理任何返回格式
        if container.contains(.message) {
            let msgDecoder = try container.superDecoder(forKey: .message)
            do {
                // 尝试作为数组解析
                let arrayContainer = try msgDecoder.singleValueContainer()
                message = try arrayContainer.decode([T].self)
            } catch {
                // 如果失败，使用空数组
                message = []
            }
        } else {
            message = []
        }
    }
}

// MARK: - 登录用户数据
public struct LoginUserData: Decodable, Sendable {
    public let userid: String
    public let username: String
    public let userident: String
    public let term: String
    public let currentValue: Int
    public let position: Int
    public let employeeNumber: String
    public let smscode: String
    public let gender: String
    public let permission: String
    public let id: String
    
    enum CodingKeys: String, CodingKey {
        case userid = "yhdm"
        case username = "yhmc"
        case userident = "yhsf"
        case term = "xq"
        case currentValue = "dqz"
        case position = "zc"
        case employeeNumber = "gh"
        case smscode
        case gender = "xb"
        case permission = "yhqx"
        case id = "yhid"
    }
}

// MARK: - 课程成绩
public struct CourseGrade: Decodable, Sendable {
    public let classId: String
    public let className: String
    public let studentId: String
    public let studentName: String
    public let courseId: String
    public let courseName: String
    public let term: Int
    public let courseType: String
    public let courseTypeName: String
    public let courseHours: Int
    public let courseCredits: Double
    public let teacherName: String
    public let isExamType: Int
    public let examType: String
    public let examGrade: String
    public let ident: Int
    public let grade: Double
    public let gradePoints: Double
    
    enum CodingKeys: String, CodingKey {
        case classId = "bh"
        case className = "bj"
        case studentId = "xh"
        case studentName = "xm"
        case courseId = "kcdm"
        case courseName = "kcmc"
        case term = "xq"
        case courseType = "kclb"
        case courseTypeName = "lbmc"
        case courseHours = "xs"
        case courseCredits = "xf"
        case teacherName = "jsmc"
        case isExamType = "ksxzm"
        case examType = "ksxz"
        case examGrade = "kscj"
        case ident = "idn"
        case grade = "cj"
        case gradePoints = "xfjd"
    }
}

// MARK: - 学生绩点信息
public struct StudentPoint: Decodable, Sendable {
    public let classId: String
    public let className: String
    public let studentId: String
    public let studentName: String
    public let studentGender: String
    public let studentStatus: String
    public let studentBirthday: String
    public let studentXid: String
    public let gradePoints: Double
    
    enum CodingKeys: String, CodingKey {
        case classId = "bh"
        case className = "bj"
        case studentId = "xh"
        case studentName = "xm"
        case studentGender = "xb"
        case studentStatus = "xjqk"
        case studentBirthday = "csny"
        case studentXid = "xsid"
        case gradePoints = "pjxfjd"
    }
}

// MARK: - 学期信息
public struct Term: Decodable, Sendable {
    public let term: String
    
    enum CodingKeys: String, CodingKey {
        case term = "xq"
    }
}

// MARK: - 课程信息
public struct RawCourse: Sendable {
    public let course: String
    public let teacher: String
    
    public init(course: String, teacher: String) {
        self.course = course
        self.teacher = teacher
    }
}

// MARK: - 考试安排
public struct ExamArrangement: Decodable, Sendable {
    public let id: Int
    public let courseId: String
    public let courseName: String
    public let courseCode: String
    public let classId: String
    public let className: String
    public let studentId: String
    public let studentName: String
    public let examLocation: String?
    public let examTime: String?
    public let examType: String
    public let studyType: String
    public let campus: String
    public let remark: String?
    public let week: Int?
    public let startSlot: Int?
    public let endSlot: Int?
    public let term: String
    public let examDayInfo: String?
    public let isActive: Int
    public let examSeat: Int?
    public let classNumber: String
    public let teacherRoomId: Int
    public let startTeacherSlot: Int?
    public let endTeacherSlot: Int?
    public let classShortName: String          // 班级简称
    
    enum CodingKeys: String, CodingKey {
        case id
        case courseId = "kch"
        case courseName = "kcmc"
        case courseCode = "kcdm"
        case classId = "xsbh"
        case className = "xsbj"
        case studentId = "xh"
        case studentName = "xm"
        case examLocation = "jse"
        case examTime = "sj"           // 实际API使用 "sj" 而不是 "kssj"
        case examType = "lb"
        case studyType = "xklb"
        case campus = "bmmc"
        case remark = "bz"
        case week = "zc"
        case startSlot = "jc1"
        case endSlot = "jc2"
        case term = "xq"
        case examDayInfo = "sjxx"
        case isActive = "yx"
        case examSeat = "ksz"
        case classNumber = "BH"
        case teacherRoomId = "jseid"
        case startTeacherSlot = "jkjs1"
        case endTeacherSlot = "jkjs2"
        case classShortName = "bj"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        courseId = try container.decode(String.self, forKey: .courseId).trimmingCharacters(in: .whitespaces)
        courseName = try container.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        courseCode = try container.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        classId = try container.decode(String.self, forKey: .classId).trimmingCharacters(in: .whitespaces)
        className = try container.decode(String.self, forKey: .className).trimmingCharacters(in: .whitespaces)
        studentId = try container.decode(String.self, forKey: .studentId).trimmingCharacters(in: .whitespaces)
        studentName = try container.decode(String.self, forKey: .studentName).trimmingCharacters(in: .whitespaces)
        examLocation = try container.decodeIfPresent(String.self, forKey: .examLocation)?.trimmingCharacters(in: .whitespaces)
        examTime = try container.decodeIfPresent(String.self, forKey: .examTime)?.trimmingCharacters(in: .whitespaces)
        examType = try container.decode(String.self, forKey: .examType).trimmingCharacters(in: .whitespaces)
        studyType = try container.decode(String.self, forKey: .studyType).trimmingCharacters(in: .whitespaces)
        campus = try container.decode(String.self, forKey: .campus).trimmingCharacters(in: .whitespaces)
        remark = try container.decodeIfPresent(String.self, forKey: .remark)?.trimmingCharacters(in: .whitespaces)
        week = try container.decodeIfPresent(Int.self, forKey: .week)
        startSlot = try container.decodeIfPresent(Int.self, forKey: .startSlot)
        endSlot = try container.decodeIfPresent(Int.self, forKey: .endSlot)
        term = try container.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        examDayInfo = try container.decodeIfPresent(String.self, forKey: .examDayInfo)?.trimmingCharacters(in: .whitespaces)
        isActive = try container.decode(Int.self, forKey: .isActive)
        examSeat = try container.decodeIfPresent(Int.self, forKey: .examSeat)
        classNumber = try container.decode(String.self, forKey: .classNumber).trimmingCharacters(in: .whitespaces)
        teacherRoomId = try container.decode(Int.self, forKey: .teacherRoomId)
        startTeacherSlot = try container.decodeIfPresent(Int.self, forKey: .startTeacherSlot)
        endTeacherSlot = try container.decodeIfPresent(Int.self, forKey: .endTeacherSlot)
        classShortName = try container.decode(String.self, forKey: .classShortName).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 学生基本信息
public struct StudentBasicInfo: Decodable, Sendable {
    public let name: String                    // 姓名
    public let major: String                   // 专业名称
    public let genderCode: String              // 性别代码
    public let phone: String                   // 手机号
    public let birthday: String                // 出生日期
    public let className: String               // 班级
    public let studentId: String               // 学生ID
    public let collegeName: String             // 学院名称
    public let gender: String                  // 性别
    public let grade: Int                      // 年级
    public let campus: String                  // 校区名称
    public let majorCode: String               // 专业代码
    public let classCode: String               // 班级号
    public let studyLength: String             // 学制
    public let studentStatus: String           // 学籍情况
    public let studentNumber: String           // 学号
    public let dormitoryNumber: String         // 宿舍编号
    
    enum CodingKeys: String, CodingKey {
        case name = "xm"
        case major = "zymc"
        case genderCode = "xbdm"
        case phone = "smscode"
        case birthday = "csny"
        case className = "bj"
        case studentId = "xsid"
        case collegeName = "xbmc"
        case gender = "xb"
        case grade = "nj"
        case campus = "bmmc"
        case majorCode = "zydm"
        case classCode = "bh"
        case studyLength = "xz"
        case studentStatus = "xjqk"
        case studentNumber = "xh"
        case dormitoryNumber = "shbh"
    }
}

// MARK: - 可评价的课程信息
public struct EvaluatableClass: Decodable, Sendable {
    public let classId: String                 // 班级号 (bh)
    public let courseCode: String              // 课程代码 (kcdm)
    public let courseName: String              // 课程名称 (kcmc)
    public let courseSerial: String            // 课程序列号 (kch)
    public let categoryCode: String            // 类别代码 (lbdh)
    public let teacherCode: String             // 教师代码 (jsdm)
    public let teacherName: String             // 教师名称 (jsmc)
    public let evaluationStatus: String?       // 评价状态 (pjqk)
    public let evaluationId: Int               // 评价ID (pjid)
    public let teacherId: String               // 教师ID (jsid)
    
    enum CodingKeys: String, CodingKey {
        case classId = "bh"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case courseSerial = "kch"
        case categoryCode = "lbdh"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case evaluationStatus = "pjqk"
        case evaluationId = "pjid"
        case teacherId = "jsid"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        classId = try container.decode(String.self, forKey: .classId).trimmingCharacters(in: .whitespaces)
        courseCode = try container.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try container.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        courseSerial = try container.decode(String.self, forKey: .courseSerial).trimmingCharacters(in: .whitespaces)
        categoryCode = try container.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        teacherCode = try container.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try container.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        evaluationStatus = try container.decodeIfPresent(String.self, forKey: .evaluationStatus)?.trimmingCharacters(in: .whitespaces)
        evaluationId = try container.decode(Int.self, forKey: .evaluationId)
        teacherId = try container.decode(String.self, forKey: .teacherId).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - 已提交的评价信息
public struct SubmittedEvaluation: Decodable, Sendable {
    public let term: String                    // 学期 (xq)
    public let evaluationId: String            // 评价ID (pjid)
    public let studentNumber: String           // 学号 (xh)
    public let teacherCode: String             // 教师代码 (jsdm)
    public let teacherName: String             // 教师名称 (jsmc)
    public let courseCode: String              // 课程代码 (kcdm)
    public let courseName: String              // 课程名称 (kcmc)
    public let overallScore: Int               // 总体评分 (zhdf)
    public let scores: String                  // 各项评分 (pjjg)
    public let comments: String                // 评价意见 (yjjy)
    
    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case evaluationId = "pjid"
        case studentNumber = "xh"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case overallScore = "zhdf"
        case scores = "pjjg"
        case comments = "yjjy"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        term = try container.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        evaluationId = try container.decode(String.self, forKey: .evaluationId).trimmingCharacters(in: .whitespaces)
        studentNumber = try container.decode(String.self, forKey: .studentNumber).trimmingCharacters(in: .whitespaces)
        teacherCode = try container.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try container.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        courseCode = try container.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try container.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        overallScore = try container.decode(Int.self, forKey: .overallScore)
        scores = try container.decode(String.self, forKey: .scores).trimmingCharacters(in: .whitespaces)
        comments = try container.decode(String.self, forKey: .comments).trimmingCharacters(in: .whitespaces)
    }
}


// MARK: - Elink登录信息
public struct ElinkLoginInfo: Decodable, Sendable {
    public let userid: String
    public let username: String?
    
    enum CodingKeys: String, CodingKey {
        case userid
        case username
    }
}

// MARK: - 校区信息
public struct ElectricityArea: Codable, Sendable {
    public let area: String                    // 校区名称
    public let areaname: String                // 校区显示名称
    public let aid: String                     // 校区ID
    
    public init(area: String, areaname: String, aid: String) {
        self.area = area
        self.areaname = areaname
        self.aid = aid
    }
}

// MARK: - 建筑物信息
public struct Building: Codable, Sendable {
    public let building: String                // 建筑物名称
    public let buildingid: String              // 建筑物ID
    
    public init(building: String, buildingid: String) {
        self.building = building
        self.buildingid = buildingid
    }
}

// MARK: - 房间信息
public struct Room: Codable, Sendable {
    public let room: String                    // 房间号
    public let roomid: String                  // 房间ID
    
    public init(room: String, roomid: String) {
        self.room = room
        self.roomid = roomid
    }
}

// MARK: - 电费查询响应
public struct ElectricityResponse: Decodable, Sendable {
    public let errmsg: String                  // 错误消息/电费信息
    public let errcode: Int?                   // 错误代码
    
    enum CodingKeys: String, CodingKey {
        case errmsg
        case errcode
    }
}

// MARK: - 选课相关模型

/// 可选/已选课程项（来自 xk_xh_kbk）
public struct SelectableCourse: Decodable, Sendable {
    public let term: String            // xq 学期
    public let classCode: String       // bh 班级号
    public let className: String       // bj 班级名
    public let courseCode: String      // kcdm 课程代码
    public let courseName: String      // kcmc 课程名称
    public let courseSerial: String    // kch 课程序列号
    public let categoryCode: String    // lbdh 类别代码
    public let hours: Int              // xs 学时
    public let credits: Double         // xf 学分
    public let examTypeName: String    // ksfs 考试方式(文字)
    public let capacity: Int           // kkrs 开课人数/容量
    public let courseAttrCode: String  // kcxbdm 课程属性代码
    public let teacherCode: String     // jsdm 教师代码
    public let teacherName: String     // jsmc 教师名称
    public let isExamType: Int         // ksxzm 考试性质码
    public let examMode: Int           // ksfsm 考试方式码
    public let idn: Int                // idn 课程标识
    public let selectionStatus: String // xkqk 选课情况（"已选"/空）
    public let selectedId: Int         // xkidn 已选记录ID（未选为0）
    public let studyType: String       // xklb 修读类别

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case classCode = "bh"
        case className = "bj"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case courseSerial = "kch"
        case categoryCode = "lbdh"
        case hours = "xs"
        case credits = "xf"
        case examTypeName = "ksfs"
        case capacity = "kkrs"
        case courseAttrCode = "kcxbdm"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case isExamType = "ksxzm"
        case examMode = "ksfsm"
        case idn
        case selectionStatus = "xkqk"
        case selectedId = "xkidn"
        case studyType = "xklb"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        classCode = try c.decode(String.self, forKey: .classCode).trimmingCharacters(in: .whitespaces)
        className = try c.decode(String.self, forKey: .className).trimmingCharacters(in: .whitespaces)
        courseCode = try c.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        courseSerial = try c.decode(String.self, forKey: .courseSerial).trimmingCharacters(in: .whitespaces)
        categoryCode = try c.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        hours = try c.decode(Int.self, forKey: .hours)
        credits = try c.decode(Double.self, forKey: .credits)
        examTypeName = try c.decode(String.self, forKey: .examTypeName).trimmingCharacters(in: .whitespaces)
        capacity = try c.decode(Int.self, forKey: .capacity)
        courseAttrCode = try c.decode(String.self, forKey: .courseAttrCode).trimmingCharacters(in: .whitespaces)
        teacherCode = try c.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        isExamType = try c.decode(Int.self, forKey: .isExamType)
        examMode = try c.decode(Int.self, forKey: .examMode)
        idn = try c.decode(Int.self, forKey: .idn)
        selectionStatus = (try c.decodeIfPresent(String.self, forKey: .selectionStatus) ?? "").trimmingCharacters(in: .whitespaces)
        selectedId = try c.decode(Int.self, forKey: .selectedId)
        studyType = try c.decode(String.self, forKey: .studyType).trimmingCharacters(in: .whitespaces)
    }
}

/// 简单响应（message 可能是 Int 或 String）
public struct SimpleJWResponse: Decodable, Sendable {
    public let status: Int
    public let token: String?
    public let messageInt: Int?
    public let messageString: String?

    enum CodingKeys: String, CodingKey { case status, token, message }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        status = try c.decode(Int.self, forKey: .status)
        token = try c.decodeIfPresent(String.self, forKey: .token)
        // message 可能为数字或字符串
        if let intVal = try? c.decode(Int.self, forKey: .message) {
            messageInt = intVal
            messageString = nil
        } else if let strVal = try? c.decode(String.self, forKey: .message) {
            messageInt = nil
            messageString = strVal
        } else {
            messageInt = nil
            messageString = nil
        }
    }
}

// MARK: - 选课批次与权限

/// 选课批次信息（学期对应的选课时间窗）
public struct SelectionBatch: Decodable, Sendable {
    public let code: String               // dm 批次代码如 "0003-004"
    public let name: String               // mc 批次名称如"学分制选课"
    public let grade: Int                 // nj 年级
    public let term: String               // xkxq 对应学期如 "25-26-2"
    public let remark: String             // bz 备注
    public let selectionMethod: String    // cxbmfs 选课方式
    public let maxCourses: Int            // xkmc 最多选课数
    public let beginDate: String          // begindate ISO 时间
    public let endDate: String            // enddate ISO 时间
    public let isSelectable: Bool         // xk 是否可选

    /// 是否在开放时间段内
    public var isOpen: Bool {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let begin = formatter.date(from: beginDate),
           let end = formatter.date(from: endDate) {
            return now >= begin && now <= end
        }
        return false
    }
    
    /// 是否允许选课（等同于 isSelectable）
    public var isAllowed: Bool {
        return isSelectable
    }

    enum CodingKeys: String, CodingKey {
        case code = "dm"
        case name = "mc"
        case grade = "nj"
        case term = "xkxq"
        case remark = "bz"
        case selectionMethod = "cxbmfs"
        case maxCourses = "xkmc"
        case beginDate = "begindate"
        case endDate = "enddate"
        case isSelectable = "xk"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        code = try c.decode(String.self, forKey: .code).trimmingCharacters(in: .whitespaces)
        name = try c.decode(String.self, forKey: .name).trimmingCharacters(in: .whitespaces)
        grade = try c.decode(Int.self, forKey: .grade)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        remark = (try c.decodeIfPresent(String.self, forKey: .remark) ?? "").trimmingCharacters(in: .whitespaces)
        selectionMethod = (try c.decodeIfPresent(String.self, forKey: .selectionMethod) ?? "").trimmingCharacters(in: .whitespaces)
        maxCourses = try c.decode(Int.self, forKey: .maxCourses)
        beginDate = try c.decode(String.self, forKey: .beginDate)
        endDate = try c.decode(String.self, forKey: .endDate)
        isSelectable = try c.decode(Bool.self, forKey: .isSelectable)
    }
}

/// 选课权限（某批次是否对该年级开放）
public struct SelectionPermission: Decodable, Sendable {
    public let isAllowed: Bool            // xk 是否有权选课（后端返回整数0/1）
    public let term: String               // xkxq 对应学期
    public let remark: String             // bz 备注
    public let selectionMethod: String    // cxbmfs 选课方式
    public let maxCourses: Int            // xkmc 最多选课数

    enum CodingKeys: String, CodingKey {
        case isAllowed = "xk"
        case term = "xkxq"
        case remark = "bz"
        case selectionMethod = "cxbmfs"
        case maxCourses = "xkmc"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // 后端返回整数 0/1，需要先解码为 Int 再转换为 Bool
        let xkInt = try c.decode(Int.self, forKey: .isAllowed)
        isAllowed = xkInt != 0
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        remark = (try c.decodeIfPresent(String.self, forKey: .remark) ?? "").trimmingCharacters(in: .whitespaces)
        selectionMethod = (try c.decodeIfPresent(String.self, forKey: .selectionMethod) ?? "").trimmingCharacters(in: .whitespaces)
        maxCourses = try c.decode(Int.self, forKey: .maxCourses)
    }
}

// MARK: - 通识类选修课程相关模型

/// 通识类选修课程项（来自 yxk_xk_xh_kxkc_gx）
public struct GeneralElectiveCourse: Decodable, Sendable {
    public let term: String                    // xq 学期
    public let courseSerial: Int               // kcxh 课程序号
    public let courseCode: String              // kcdm 课程代码
    public let courseName: String              // kcmc 课程名称
    public let teacherCode: String             // jsdm 教师代码
    public let teacherName: String             // jsmc 教师名称
    public let hours: Int                      // xs 学时
    public let credits: Double                 // xf 学分
    public let categoryCode: String            // lbdh 类别代码
    public let categoryName: String            // lbmc 类别名称
    public let timeDescription: String         // sj 时间描述
    public let capacity: Int                   // xxrs 限选人数
    public let selectedCount: Int              // xkrs 已选人数
    public let availableCount: Int             // kxrs 可选人数
    public let batchCode: String               // lbdm 批次代码
    public let description: String?            // xxsm 详细说明
    public let campus: String                  // jse 教学地点
    public let week: Int                       // zc 周次
    public let startSlot: Int                  // jc1 开始节次
    public let endSlot: Int                    // jc2 结束节次

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case courseSerial = "kcxh"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case hours = "xs"
        case credits = "xf"
        case categoryCode = "lbdh"
        case categoryName = "lbmc"
        case timeDescription = "sj"
        case capacity = "xxrs"
        case selectedCount = "xkrs"
        case availableCount = "kxrs"
        case batchCode = "lbdm"
        case description = "xxsm"
        case campus = "jse"
        case week = "zc"
        case startSlot = "jc1"
        case endSlot = "jc2"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        courseSerial = try c.decode(Int.self, forKey: .courseSerial)
        courseCode = try c.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        teacherCode = try c.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        hours = try c.decode(Int.self, forKey: .hours)
        credits = try c.decode(Double.self, forKey: .credits)
        categoryCode = try c.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        categoryName = try c.decode(String.self, forKey: .categoryName).trimmingCharacters(in: .whitespaces)
        timeDescription = try c.decode(String.self, forKey: .timeDescription).trimmingCharacters(in: .whitespaces)
        capacity = try c.decode(Int.self, forKey: .capacity)
        selectedCount = try c.decode(Int.self, forKey: .selectedCount)
        availableCount = try c.decode(Int.self, forKey: .availableCount)
        batchCode = try c.decode(String.self, forKey: .batchCode).trimmingCharacters(in: .whitespaces)
        description = try c.decodeIfPresent(String.self, forKey: .description)?.trimmingCharacters(in: .whitespaces)
        campus = try c.decode(String.self, forKey: .campus).trimmingCharacters(in: .whitespaces)
        week = try c.decode(Int.self, forKey: .week)
        startSlot = try c.decode(Int.self, forKey: .startSlot)
        endSlot = try c.decode(Int.self, forKey: .endSlot)
    }
}

/// 已选通识类选修课程项（来自 yxk_xk_xh_yxkc_gx）
public struct SelectedGeneralElectiveCourse: Decodable, Sendable {
    public let term: String                    // xq 学期
    public let studentId: String               // xh 学号
    public let courseSerial: Int               // kcxh 课程序号
    public let courseCode: String              // kcdm 课程代码
    public let courseName: String              // kcmc 课程名称
    public let teacherCode: String             // jsdm 教师代码
    public let teacherName: String             // jsmc 教师名称
    public let hours: Int                      // xs 学时
    public let credits: Double                 // xf 学分
    public let categoryCode: String            // lbdh 类别代码
    public let categoryName: String            // lbmc 类别名称
    public let timeDescription: String         // sj 时间描述
    public let capacity: Int                   // xxrs 限选人数
    public let selectedCount: Int              // xkrs 已选人数
    public let availableCount: Int             // kxrs 可选人数
    public let batchCode: String               // lbdm 批次代码
    public let description: String?            // xxsm 详细说明
    public let campus: String                  // jse 教学地点
    public let week: Int                       // zc 周次
    public let startSlot: Int                  // jc1 开始节次
    public let endSlot: Int                    // jc2 结束节次

    enum CodingKeys: String, CodingKey {
        case term = "xq"
        case studentId = "xh"
        case courseSerial = "kcxh"
        case courseCode = "kcdm"
        case courseName = "kcmc"
        case teacherCode = "jsdm"
        case teacherName = "jsmc"
        case hours = "xs"
        case credits = "xf"
        case categoryCode = "lbdh"
        case categoryName = "lbmc"
        case timeDescription = "sj"
        case capacity = "xxrs"
        case selectedCount = "xkrs"
        case availableCount = "kxrs"
        case batchCode = "lbdm"
        case description = "xxsm"
        case campus = "jse"
        case week = "zc"
        case startSlot = "jc1"
        case endSlot = "jc2"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        studentId = try c.decode(String.self, forKey: .studentId).trimmingCharacters(in: .whitespaces)
        courseSerial = try c.decode(Int.self, forKey: .courseSerial)
        courseCode = try c.decode(String.self, forKey: .courseCode).trimmingCharacters(in: .whitespaces)
        courseName = try c.decode(String.self, forKey: .courseName).trimmingCharacters(in: .whitespaces)
        teacherCode = try c.decode(String.self, forKey: .teacherCode).trimmingCharacters(in: .whitespaces)
        teacherName = try c.decode(String.self, forKey: .teacherName).trimmingCharacters(in: .whitespaces)
        hours = try c.decode(Int.self, forKey: .hours)
        credits = try c.decode(Double.self, forKey: .credits)
        categoryCode = try c.decode(String.self, forKey: .categoryCode).trimmingCharacters(in: .whitespaces)
        categoryName = try c.decode(String.self, forKey: .categoryName).trimmingCharacters(in: .whitespaces)
        timeDescription = try c.decode(String.self, forKey: .timeDescription).trimmingCharacters(in: .whitespaces)
        capacity = try c.decode(Int.self, forKey: .capacity)
        selectedCount = try c.decode(Int.self, forKey: .selectedCount)
        availableCount = try c.decode(Int.self, forKey: .availableCount)
        batchCode = try c.decode(String.self, forKey: .batchCode).trimmingCharacters(in: .whitespaces)
        description = try c.decodeIfPresent(String.self, forKey: .description)?.trimmingCharacters(in: .whitespaces)
        campus = try c.decode(String.self, forKey: .campus).trimmingCharacters(in: .whitespaces)
        week = try c.decode(Int.self, forKey: .week)
        startSlot = try c.decode(Int.self, forKey: .startSlot)
        endSlot = try c.decode(Int.self, forKey: .endSlot)
    }
}

/// 通识类选修课程批次权限（来自 yxk_xkqx_dm_nj）
public struct GeneralElectivePermission: Decodable, Sendable {
    public let isAllowed: Bool                 // xk 是否有权选课
    public let term: String                    // xkxq 对应学期
    public let remark: String                  // bz 备注
    public let selectionMethod: String         // cxbmfs 选课方式
    public let maxCourses: Int                 // xkmc 最多选课数

    enum CodingKeys: String, CodingKey {
        case isAllowed = "xk"
        case term = "xkxq"
        case remark = "bz"
        case selectionMethod = "cxbmfs"
        case maxCourses = "xkmc"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let xkInt = try c.decode(Int.self, forKey: .isAllowed)
        isAllowed = xkInt != 0
        term = try c.decode(String.self, forKey: .term).trimmingCharacters(in: .whitespaces)
        remark = (try c.decodeIfPresent(String.self, forKey: .remark) ?? "").trimmingCharacters(in: .whitespaces)
        selectionMethod = (try c.decodeIfPresent(String.self, forKey: .selectionMethod) ?? "").trimmingCharacters(in: .whitespaces)
        maxCourses = try c.decode(Int.self, forKey: .maxCourses)
    }
}

