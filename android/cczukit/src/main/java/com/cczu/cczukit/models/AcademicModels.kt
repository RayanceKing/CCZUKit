package com.cczu.cczukit.models

import com.cczu.cczukit.flexDouble
import com.cczu.cczukit.flexInt
import com.cczu.cczukit.flexIntOrNull
import com.cczu.cczukit.flexString
import com.cczu.cczukit.flexStringOrNull
import com.google.gson.JsonObject

/** 登录用户数据 */
public data class LoginUserData(
    val userid: String,      // yhdm
    val username: String,    // yhmc
    val userident: String,   // yhsf
    val term: String,        // xq
    val currentValue: Int,   // dqz
    val position: Int,       // zc
    val employeeNumber: String, // gh
    val smscode: String,
    val gender: String,      // xb
    val permission: String,  // yhqx
    val id: String           // yhid
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): LoginUserData = LoginUserData(
            userid = obj["yhdm"].flexString(),
            username = obj["yhmc"].flexString(),
            userident = obj["yhsf"].flexString(),
            term = obj["xq"].flexString(),
            currentValue = obj["dqz"].flexInt(),
            position = obj["zc"].flexInt(),
            employeeNumber = obj["gh"].flexString(),
            smscode = obj["smscode"].flexString(),
            gender = obj["xb"].flexString(),
            permission = obj["yhqx"].flexString(),
            id = obj["yhid"].flexString()
        )
    }
}

/** 课程成绩 */
public data class CourseGrade(
    val classId: String,        // bh
    val className: String,      // bj
    val studentId: String,      // xh
    val studentName: String,    // xm
    val courseId: String,       // kcdm
    val courseName: String,     // kcmc
    val term: Int,              // xq
    val courseType: String,     // kclb
    val courseTypeName: String, // lbmc
    val courseHours: Int,       // xs
    val courseCredits: Double,  // xf
    val teacherName: String,    // jsmc
    val isExamType: Int,        // ksxzm
    val examType: String,       // ksxz
    val examGrade: String,      // kscj
    val ident: Int,             // idn
    val grade: Double,          // cj
    val gradePoints: Double     // xfjd
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): CourseGrade = CourseGrade(
            classId = obj["bh"].flexString(),
            className = obj["bj"].flexString(),
            studentId = obj["xh"].flexString(),
            studentName = obj["xm"].flexString(),
            courseId = obj["kcdm"].flexString(),
            courseName = obj["kcmc"].flexString(),
            term = obj["xq"].flexInt(),
            courseType = obj["kclb"].flexString(),
            courseTypeName = obj["lbmc"].flexString(),
            courseHours = obj["xs"].flexInt(),
            courseCredits = obj["xf"].flexDouble(),
            teacherName = obj["jsmc"].flexString(),
            isExamType = obj["ksxzm"].flexInt(),
            examType = obj["ksxz"].flexString(),
            examGrade = obj["kscj"].flexString(),
            ident = obj["idn"].flexInt(),
            grade = obj["cj"].flexDouble(),
            gradePoints = obj["xfjd"].flexDouble()
        )
    }
}

/** 学生绩点信息 */
public data class StudentPoint(
    val classId: String,
    val className: String,
    val studentId: String,
    val studentName: String,
    val studentGender: String,
    val studentStatus: String,
    val studentBirthday: String,
    val studentXid: String,
    val gradePoints: Double
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): StudentPoint = StudentPoint(
            classId = obj["bh"].flexString(),
            className = obj["bj"].flexString(),
            studentId = obj["xh"].flexString(),
            studentName = obj["xm"].flexString(),
            studentGender = obj["xb"].flexString(),
            studentStatus = obj["xjqk"].flexString(),
            studentBirthday = obj["csny"].flexString(),
            studentXid = obj["xsid"].flexString(),
            gradePoints = obj["pjxfjd"].flexDouble()
        )
    }
}

/** 学期信息 */
public data class Term(
    val term: String // xq
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): Term = Term(term = obj["xq"].flexString())
    }
}

/** 课表原始课程（课程名 / 教师，可能包含 "/" 分隔的多段） */
public data class RawCourse(
    val course: String,
    val teacher: String
)

/** 考试安排 */
public data class ExamArrangement(
    val id: Int,
    val courseId: String,        // kch
    val courseName: String,      // kcmc
    val courseCode: String,      // kcdm
    val classId: String,         // xsbh
    val className: String,       // xsbj
    val studentId: String,       // xh
    val studentName: String,     // xm
    val examLocation: String?,   // jse
    val examTime: String?,       // sj
    val examType: String,        // lb
    val studyType: String,       // xklb
    val campus: String,          // bmmc
    val remark: String?,         // bz
    val week: Int?,              // zc
    val startSlot: Int?,         // jc1
    val endSlot: Int?,           // jc2
    val term: String,            // xq
    val examDayInfo: String?,    // sjxx
    val isActive: Int,           // yx
    val examSeat: Int?,          // ksz
    val classNumber: String,     // BH
    val teacherRoomId: Int,      // jseid
    val startTeacherSlot: Int?,  // jkjs1
    val endTeacherSlot: Int?,    // jkjs2
    val classShortName: String   // bj
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): ExamArrangement = ExamArrangement(
            id = obj["id"].flexInt(),
            courseId = obj["kch"].flexString(),
            courseName = obj["kcmc"].flexString(),
            courseCode = obj["kcdm"].flexString(),
            classId = obj["xsbh"].flexString(),
            className = obj["xsbj"].flexString(),
            studentId = obj["xh"].flexString(),
            studentName = obj["xm"].flexString(),
            examLocation = obj["jse"].flexStringOrNull(),
            examTime = obj["sj"].flexStringOrNull(),
            examType = obj["lb"].flexString(),
            studyType = obj["xklb"].flexString(),
            campus = obj["bmmc"].flexString(),
            remark = obj["bz"].flexStringOrNull(),
            week = obj["zc"].flexIntOrNull(),
            startSlot = obj["jc1"].flexIntOrNull(),
            endSlot = obj["jc2"].flexIntOrNull(),
            term = obj["xq"].flexString(),
            examDayInfo = obj["sjxx"].flexStringOrNull(),
            isActive = obj["yx"].flexInt(),
            examSeat = obj["ksz"].flexIntOrNull(),
            classNumber = obj["BH"].flexString(),
            teacherRoomId = obj["jseid"].flexInt(),
            startTeacherSlot = obj["jkjs1"].flexIntOrNull(),
            endTeacherSlot = obj["jkjs2"].flexIntOrNull(),
            classShortName = obj["bj"].flexString()
        )
    }
}

/** 学生基本信息 */
public data class StudentBasicInfo(
    val name: String,            // xm
    val major: String,           // zymc
    val genderCode: String,      // xbdm
    val phone: String,           // smscode
    val birthday: String,        // csny
    val className: String,       // bj
    val studentId: String,       // xsid
    val collegeName: String,     // xbmc
    val gender: String,          // xb
    val grade: Int,              // nj
    val campus: String,          // bmmc
    val majorCode: String,       // zydm
    val classCode: String,       // bh
    val studyLength: String,     // xz
    val studentStatus: String,   // xjqk
    val studentNumber: String,   // xh
    val dormitoryNumber: String  // shbh
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): StudentBasicInfo = StudentBasicInfo(
            name = obj["xm"].flexString(),
            major = obj["zymc"].flexString(),
            genderCode = obj["xbdm"].flexString(),
            phone = obj["smscode"].flexString(),
            birthday = obj["csny"].flexString(),
            className = obj["bj"].flexString(),
            studentId = obj["xsid"].flexString(),
            collegeName = obj["xbmc"].flexString(),
            gender = obj["xb"].flexString(),
            grade = obj["nj"].flexInt(),
            campus = obj["bmmc"].flexString(),
            majorCode = obj["zydm"].flexString(),
            classCode = obj["bh"].flexString(),
            studyLength = obj["xz"].flexString(),
            studentStatus = obj["xjqk"].flexString(),
            studentNumber = obj["xh"].flexString(),
            dormitoryNumber = obj["shbh"].flexString()
        )
    }
}

/** 可评价的课程信息 */
public data class EvaluatableClass(
    val classId: String,          // bh
    val courseCode: String,       // kcdm
    val courseName: String,       // kcmc
    val courseSerial: String,     // kch
    val categoryCode: String,     // lbdh
    val teacherCode: String,      // jsdm
    val teacherName: String,      // jsmc
    val evaluationStatus: String?, // pjqk
    val evaluationId: Int,        // pjid
    val teacherId: String         // jsid
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): EvaluatableClass = EvaluatableClass(
            classId = obj["bh"].flexString(),
            courseCode = obj["kcdm"].flexString(),
            courseName = obj["kcmc"].flexString(),
            courseSerial = obj["kch"].flexString(),
            categoryCode = obj["lbdh"].flexString(),
            teacherCode = obj["jsdm"].flexString(),
            teacherName = obj["jsmc"].flexString(),
            evaluationStatus = obj["pjqk"].flexStringOrNull(),
            evaluationId = obj["pjid"].flexInt(),
            teacherId = obj["jsid"].flexString()
        )
    }
}

/** 已提交的评价信息 */
public data class SubmittedEvaluation(
    val term: String,          // xq
    val evaluationId: String,  // pjid
    val studentNumber: String, // xh
    val teacherCode: String,   // jsdm
    val teacherName: String,   // jsmc
    val courseCode: String,    // kcdm
    val courseName: String,    // kcmc
    val overallScore: Int,     // zhdf
    val scores: String,        // pjjg
    val comments: String       // yjjy
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): SubmittedEvaluation = SubmittedEvaluation(
            term = obj["xq"].flexString(),
            evaluationId = obj["pjid"].flexString(),
            studentNumber = obj["xh"].flexString(),
            teacherCode = obj["jsdm"].flexString(),
            teacherName = obj["jsmc"].flexString(),
            courseCode = obj["kcdm"].flexString(),
            courseName = obj["kcmc"].flexString(),
            overallScore = obj["zhdf"].flexInt(),
            scores = obj["pjjg"].flexString(),
            comments = obj["yjjy"].flexString()
        )
    }
}

/** Elink / WebVPN 登录信息 */
public data class ElinkLoginInfo(
    val userid: String,
    val username: String?
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): ElinkLoginInfo = ElinkLoginInfo(
            userid = obj["userid"].flexString(),
            username = obj["username"].flexStringOrNull()
        )
    }
}
