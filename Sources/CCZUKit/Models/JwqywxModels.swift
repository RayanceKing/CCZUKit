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
    public let examSeat: String?
    public let classNumber: String
    public let teacherRoomId: Int
    public let startTeacherSlot: String?
    public let endTeacherSlot: String?
    
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
        case examTime = "kssj"
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
