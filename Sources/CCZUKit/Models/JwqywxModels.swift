import Foundation

// MARK: - 通用响应消息
public struct Message<T: Decodable>: Decodable, Sendable where T: Sendable {
    public let status: Int
    public let message: [T]
    public let token: String?
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

// MARK: - Elink登录信息
public struct ElinkLoginInfo: Decodable, Sendable {
    public let userid: String
    public let username: String?
    
    enum CodingKeys: String, CodingKey {
        case userid
        case username
    }
}
