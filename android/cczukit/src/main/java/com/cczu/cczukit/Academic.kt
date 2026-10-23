package com.cczu.cczukit

import com.cczu.cczukit.models.EvaluatableClass
import com.cczu.cczukit.models.ExamArrangement
import com.cczu.cczukit.models.RawCourse
import com.cczu.cczukit.models.StudentBasicInfo
import com.cczu.cczukit.models.SubmittedEvaluation

public suspend fun JwqywxApplication.getStudentBasicInfo(): Message<StudentBasicInfo> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.studentBasicInfoURL,
        fields = mapOf("xh" to stuNum, "yhid" to authId)
    )
    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { StudentBasicInfo.fromJson(it) }
}

// MARK: - 课表

public suspend fun JwqywxApplication.getClassSchedule(term: String): List<List<RawCourse>> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn

    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.classScheduleURL,
        fields = mapOf(
            "xh" to client.account.username,
            "xq" to term,
            "yhid" to authId
        )
    )

    val parsed = parseMessageFromJson(data.toString(Charsets.UTF_8)) { CourseScheduleRow.from(it) }

    // 使用补充接口兜底授课教师（失败时不影响主流程）
    val fallbackTeachers = fetchCourseTeacherSupplements(term = term, authId = authId)
    return parsed.message.map { it.toCourses(fallbackTeachers) }
}

public suspend fun JwqywxApplication.getCurrentClassSchedule(): List<List<RawCourse>> {
    val currentTerm = getCurrentTerm()
    return getClassSchedule(term = currentTerm)
}

private suspend fun JwqywxApplication.fetchCourseTeacherSupplements(
    term: String,
    authId: String
): Map<String, String> {
    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.courseTeacherSupplementURL,
        fields = mapOf(
            "xh" to client.account.username,
            "xq" to term,
            "yhid" to authId
        )
    )
    val message = parseMessageFromJson(data.toString(Charsets.UTF_8)) { CourseTeacherSupplementItem.from(it) }

    val result = LinkedHashMap<String, String>()
    for (item in message.message) {
        if (item.courseName.isEmpty() || item.teacherName.isEmpty()) continue

        // 合并同名课程的多个教师，避免覆盖
        val existing = result[item.courseName]
        if (existing != null && existing.isNotEmpty() && !existing.contains(item.teacherName)) {
            result[item.courseName] = "$existing,${item.teacherName}"
        } else if (existing == null) {
            result[item.courseName] = item.teacherName
        }

        val normalizedName = item.courseName.replace("（", "(").replace("）", ")")
        if (normalizedName != item.courseName && result[normalizedName] == null) {
            result[normalizedName] = result[item.courseName] ?: ""
        }
    }
    return result
}

// MARK: - 考试安排

public suspend fun JwqywxApplication.getExamArrangements(
    term: String? = null,
    examType: String = CCZUConstants.Jwqywx.defaultExamType
): List<ExamArrangement> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn

    val examTerm = term ?: getCurrentTerm()

    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.examArrangementsURL,
        fields = mapOf(
            "xq" to examTerm,
            "yhdm" to client.account.username,
            "dm" to examType,
            "yhid" to authId
        )
    )
    val message = parseMessageFromJson(data.toString(Charsets.UTF_8)) { ExamArrangement.fromJson(it) }
    return message.message
}

public suspend fun JwqywxApplication.getCurrentExamArrangements(): List<ExamArrangement> =
    getExamArrangements()

// MARK: - 教师评价

public suspend fun JwqywxApplication.getEvaluatableClasses(term: String): List<EvaluatableClass> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn

    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.evaluatableClassesURL,
        fields = mapOf(
            "pjxq" to term,
            "xh" to client.account.username,
            "yhid" to authId
        )
    )
    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { EvaluatableClass.fromJson(it) }.message
}

public suspend fun JwqywxApplication.getCurrentEvaluatableClasses(): List<EvaluatableClass> =
    getEvaluatableClasses(term = getCurrentTerm())

public suspend fun JwqywxApplication.getSubmittedEvaluations(term: String): List<SubmittedEvaluation> {
    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.submittedEvaluationsURL,
        fields = mapOf(
            "pjxq" to term,
            "xh" to client.account.username
        )
    )
    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { SubmittedEvaluation.fromJson(it) }.message
}

public suspend fun JwqywxApplication.getCurrentSubmittedEvaluations(): List<SubmittedEvaluation> =
    getSubmittedEvaluations(term = getCurrentTerm())

public suspend fun JwqywxApplication.submitTeacherEvaluation(
    term: String,
    evaluatableClass: EvaluatableClass,
    overallScore: Int,
    scores: List<Int>,
    comments: String
) {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn

    // 分数数组转逗号分隔字符串，末尾加逗号
    val scoresString = scores.joinToString(",") + ","

    val (_, response) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.submitTeacherEvaluationURL,
        fields = mapOf(
            "pjxq" to term,
            "yhdm" to client.account.username,
            "jsdm" to evaluatableClass.teacherCode,
            "kcdm" to evaluatableClass.courseCode,
            "zhdf" to overallScore.toString(),
            "pjjg" to scoresString,
            "yjjy" to comments,
            "yhid" to authId
        )
    )

    if (response.statusCode != 200) {
        throw CCZUError.Unknown("HTTP Status code: ${response.statusCode}")
    }
}
