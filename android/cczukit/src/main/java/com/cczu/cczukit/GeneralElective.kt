package com.cczu.cczukit

import com.cczu.cczukit.models.ActualSelectedCount
import com.cczu.cczukit.models.GeneralElectiveCourse
import com.cczu.cczukit.models.GeneralElectivePermission
import com.cczu.cczukit.models.SelectedGeneralElectiveCourse
import com.cczu.cczukit.models.SimpleJWResponse
import com.google.gson.JsonObject
import kotlin.math.max

/** 获取通识类选修课程，并合并实际已选人数 */
public suspend fun JwqywxApplication.getGeneralElectiveCourses(
    term: String,
    classCode: String,
    grade: Int,
    campus: String
): List<GeneralElectiveCourse> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    val body: Map<String, Any?> = mapOf(
        "xq" to term,
        "bh" to classCode,
        "nj" to grade,
        "bmmc" to campus,
        "xh" to stuNum,
        "yhid" to authId
    )
    debugLog("getGeneralElectiveCourses body=$body")

    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.generalElectiveCoursesURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { GeneralElectiveCourse.fromJson(it) }
    debugLog("getGeneralElectiveCourses courses=${msg.message.size}")

    // 合并实际已选人数（yxk_xk_xkrs_gx）；失败则抛出原始错误
    val actuals = getGeneralElectiveActualSelectedCounts(
        term = term,
        classCode = classCode,
        grade = grade,
        campus = campus
    )
    val realCounts = actuals.associate { it.courseSerial to it.selectedCount }
    return msg.message.map { course ->
        val realSelected = realCounts[course.courseSerial]
        if (realSelected != null) {
            course.withCounts(
                selectedCount = realSelected,
                availableCount = max(0, course.capacity - realSelected)
            )
        } else {
            course
        }
    }
}

private suspend fun JwqywxApplication.getGeneralElectiveActualSelectedCounts(
    term: String,
    classCode: String,
    grade: Int,
    campus: String
): List<ActualSelectedCount> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    val body: Map<String, Any?> = mapOf(
        "xq" to term,
        "bh" to classCode,
        "nj" to grade,
        "bmmc" to campus,
        "xh" to stuNum,
        "yhid" to authId
    )
    debugLog("getGeneralElectiveActualSelectedCounts body=$body")

    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.generalElectiveActualCountsURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { ActualSelectedCount.fromJson(it) }
    debugLog("getGeneralElectiveActualSelectedCounts items=${msg.message.size}")
    return msg.message
}

/** 已选通识类选修课程（yxk_xk_xh_yxkc_gx） */
public suspend fun JwqywxApplication.getSelectedGeneralElectiveCourses(
    term: String
): List<SelectedGeneralElectiveCourse> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    val body = mapOf(
        "xq" to term,
        "xh" to stuNum,
        "yhid" to authId
    )
    debugLog("getSelectedGeneralElectiveCourses body=$body")

    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.selectedGeneralElectiveCoursesURL, fields = body)
    debugLog("getSelectedGeneralElectiveCourses raw response: ${data.toString(Charsets.UTF_8)}")

    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { SelectedGeneralElectiveCourse.fromJson(it) }.message
}

/** 通识类选修批次权限（yxk_xkqx_dm_nj） */
public suspend fun JwqywxApplication.checkGeneralElectivePermission(
    batchCode: String,
    grade: Int
): GeneralElectivePermission {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val body: Map<String, Any?> = mapOf(
        "dm" to batchCode,
        "nj" to grade,
        "yhid" to authId
    )
    debugLog("checkGeneralElectivePermission body=$body")

    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.checkGeneralElectivePermissionURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { GeneralElectivePermission.fromJson(it) }
    val perm = msg.message.firstOrNull() ?: throw CCZUError.MissingData("未获得通识选课权限")
    debugLog("checkGeneralElectivePermission OK, term=${perm.term}")
    return perm
}

/** 选通识类选修课程（yxk_xk_insert_ggxx），最多 2 门一组 */
public suspend fun JwqywxApplication.selectGeneralElectiveCourses(
    term: String,
    courses: List<GeneralElectiveCourse>
) {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    // 必要的登录态校验（xm 字段暂未使用，Swift 版同样获取了基本信息）
    getStudentBasicInfo()

    // 仅对可选课程提交（kxrs > 0）
    val available = courses.filter { it.availableCount > 0 }
    debugLog("selectGeneralElective available count=${available.size} total=${courses.size}")

    for (chunk in available.chunked(2)) {
        if (chunk.isEmpty()) continue
        val first = chunk[0]
        val payload = JsonObject().apply {
            addProperty("xq", term)
            addProperty("xh", stuNum)
            addProperty("kcxh", first.courseSerial)
            addProperty("zc", first.week)
            addProperty("jc1", first.startSlot)
            addProperty("jc2", first.endSlot)
            addProperty("xxrs", first.capacity)
            addProperty("xkmc", chunk.size) // 选课门数
            addProperty("yhid", authId)
        }
        debugLog("yxk_xk_insert_ggxx chunk size=${chunk.size}, courseSerial=${first.courseSerial}")

        val (data, response) = postAuthenticatedJson(
            url = CCZUConstants.Jwqywx.selectGeneralElectiveCoursesURL,
            json = payload
        )
        if (response.statusCode != 200) {
            throw CCZUError.Unknown("HTTP Status code: ${response.statusCode}")
        }
        val res = SimpleJWResponse.fromJson(
            parseJsonObject(data.toString(Charsets.UTF_8)) ?: throw TeachingResponseError.MalformedResponse
        )
        debugLog(
            "yxk_xk_insert_ggxx status=${res.status} messageInt=${res.messageInt} messageString=${res.messageString}"
        )
        if (res.status != 0) {
            throw CCZUError.Unknown(
                "通识选课失败: status=${res.status}, message=${res.messageString ?: res.messageInt?.toString() ?: "-1"}"
            )
        }
    }
}

/** 退通识类选修课程（yxk_xk_delete_ggxx） */
public suspend fun JwqywxApplication.dropGeneralElectiveCourse(term: String, courseSerial: Int) {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    val body: Map<String, Any?> = mapOf(
        "xq" to term,
        "xh" to stuNum,
        "kcxh" to courseSerial,
        "yhid" to authId
    )
    debugLog("dropGeneralElectiveCourse body=$body")

    val (data, response) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.dropGeneralElectiveCourseURL,
        fields = body
    )
    if (response.statusCode != 200) {
        throw CCZUError.Unknown("HTTP Status code: ${response.statusCode}")
    }
    val res = SimpleJWResponse.fromJson(
        parseJsonObject(data.toString(Charsets.UTF_8)) ?: throw TeachingResponseError.MalformedResponse
    )
    if (res.status != 0) {
        throw CCZUError.Unknown(
            "退通识选课失败: status=${res.status}, message=${res.messageString ?: res.messageInt?.toString() ?: "-1"}"
        )
    }
    debugLog("dropGeneralElectiveCourse OK")
}
