package com.cczu.cczukit

import com.cczu.cczukit.models.SelectableCourse
import com.cczu.cczukit.models.SelectionBatch
import com.cczu.cczukit.models.SelectionPermission
import com.cczu.cczukit.models.SimpleJWResponse
import com.google.gson.JsonArray
import com.google.gson.JsonObject

public suspend fun JwqywxApplication.checkSelectionPermission(
    userId: String,
    functionCode: String = CCZUConstants.Jwqywx.defaultSelectionFunctionCode
) {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val body = mapOf(
        "yhdm" to userId,
        "gnmk" to functionCode,
        "yhid" to authId
    )
    debugLog("checkSelectionPermission body=$body")
    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.checkSelectionPermissionURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { it.stringMap() }
    if (msg.status != 0) throw CCZUError.Unknown("选课权限检查失败")
    debugLog("checkSelectionPermission OK")
}

/** 获取该年级的选课批次列表 */
public suspend fun JwqywxApplication.getSelectionBatches(grade: Int): List<SelectionBatch> {
    val userId = studentNumber ?: throw CCZUError.NotLoggedIn
    val body: Map<String, Any?> = mapOf(
        "yhdm" to userId,
        "nj" to grade
    )
    debugLog("getSelectionBatches body=$body")
    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.selectionBatchesURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { SelectionBatch.fromJson(it) }
    debugLog("getSelectionBatches batches=${msg.message.size}")
    return msg.message
}

/** 获取通识类选修课对应的选课批次（优先名称含“通识”的批次） */
public suspend fun JwqywxApplication.getGeneralElectiveSelectionBatch(grade: Int): SelectionBatch? {
    val batches = getSelectionBatches(grade = grade)
    debugLog("getGeneralElectiveSelectionBatch batches=${batches.map { it.name }}")
    return batches.firstOrNull {
        it.name.contains("通识") || it.name.contains("通识教育") || it.name.contains("通识类")
    } ?: batches.firstOrNull()
}

/** 检查某批次的选课权限 */
public suspend fun JwqywxApplication.checkBatchPermission(
    batchCode: String,
    grade: Int
): SelectionPermission {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val body: Map<String, Any?> = mapOf(
        "dm" to batchCode,
        "nj" to grade,
        "yhid" to authId
    )
    debugLog("checkBatchPermission body=$body")
    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.batchPermissionURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { SelectionPermission.fromJson(it) }
    val perm = msg.message.firstOrNull() ?: throw CCZUError.MissingData("未获得选课权限")
    if (!perm.isAllowed) throw CCZUError.Unknown("该批次对你的年级未开放选课权限")
    debugLog("checkBatchPermission OK, term=${perm.term}")
    return perm
}

/** 综合前置检查后，获取当前允许批次的可选课程 */
public suspend fun JwqywxApplication.getCurrentSelectableCoursesWithPreflight(
    classCode: String,
    grade: Int
): List<SelectableCourse> {
    val userId = studentNumber ?: throw CCZUError.NotLoggedIn
    // 1) 功能权限
    checkSelectionPermission(userId = userId)
    // 2) 获取批次并选择处于开放状态的批次
    val batches = getSelectionBatches(grade = grade)
    val candidate = batches.firstOrNull { it.isOpen && it.isAllowed }
        ?: batches.sortedByDescending { it.endDate }.firstOrNull()
    val batch = candidate ?: throw CCZUError.MissingData("当前年级没有开放的选课批次")
    // 3) 批次权限校验以获得正确学期
    val perm = checkBatchPermission(batchCode = batch.code, grade = grade)
    // 4) 按正确学期拉取可选课程
    val courses = getSelectableCourses(term = perm.term, classCode = classCode)
    debugLog("getCurrentSelectableCoursesWithPreflight term=${perm.term}, courses=${courses.size}")
    return courses
}

/** 查询选课状态 / 课程列表（xk_xh_kbk） */
public suspend fun JwqywxApplication.getSelectableCourses(
    term: String,
    classCode: String
): List<SelectableCourse> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn
    val body = mapOf(
        "xq" to term,
        "bh" to classCode,
        "xh" to stuNum,
        "yhid" to authId
    )
    debugLog("xk_xh_kbk body=$body")
    val (data, _) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.selectableCoursesURL, fields = body)
    val msg = parseMessageFromJson(data.toString(Charsets.UTF_8)) { SelectableCourse.fromJson(it) }
    debugLog("xk_xh_kbk items=${msg.message.size}")
    return msg.message
}

/** 查询当前学期、本人班级的可选课程 */
public suspend fun JwqywxApplication.getCurrentSelectableCourses(): List<SelectableCourse> {
    val currentTerm = getCurrentTerm()
    val info = getStudentBasicInfo()
    val basic = info.message.firstOrNull()
        ?: throw CCZUError.MissingData(CCZUConstants.Jwqywx.noBasicInfoMessage)
    return getSelectableCourses(term = currentTerm, classCode = basic.classCode)
}

/** 选课（xk_insert_xfz），最多 5 门一组，自动分片 */
public suspend fun JwqywxApplication.selectCourses(term: String, items: List<SelectableCourse>) {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    val basic = getStudentBasicInfo()
    val name = basic.message.firstOrNull()?.name ?: ""

    // 仅对未选（xkqk 为空）的课程提交
    val pending = items.filter { it.selectionStatus.isEmpty() }
    debugLog("select pending count=${pending.size} total=${items.size}")

    val chunks = pending.chunked(5)

    for (chunk in chunks) {
        if (chunk.isEmpty()) continue
        val postdata = JsonArray()
        for (c in chunk) {
            postdata.add(
                JsonObject().apply {
                    addProperty("xq", term)
                    addProperty("bh", c.classCode)
                    addProperty("bj", c.className)
                    addProperty("kcdm", c.courseCode)
                    addProperty("kcmc", c.courseName)
                    addProperty("kch", c.courseSerial)
                    addProperty("lbdh", c.categoryCode)
                    addProperty("xs", c.hours)
                    addProperty("xf", c.credits)
                    addProperty("ksfs", c.examTypeName)
                    addProperty("kkrs", c.capacity)
                    addProperty("kcxbdm", c.courseAttrCode)
                    addProperty("jsdm", c.teacherCode)
                    addProperty("jsmc", c.teacherName)
                    addProperty("ksxzm", c.isExamType)
                    addProperty("ksfsm", c.examMode)
                    addProperty("idn", c.idn)
                    addProperty("xkqk", c.selectionStatus)
                    addProperty("xkidn", c.selectedId)
                    addProperty("xklb", c.studyType)
                }
            )
        }

        val payload = JsonObject().apply {
            addProperty("xq", term)
            addProperty("xh", stuNum)
            addProperty("xm", name)
            add("postdata", postdata)
            addProperty("yhid", authId)
        }
        debugLog("xk_insert_xfz chunk size=${chunk.size}")

        val (data, response) = postAuthenticatedJson(url = CCZUConstants.Jwqywx.selectCoursesURL, json = payload)
        if (response.statusCode != 200) {
            throw CCZUError.Unknown("HTTP Status code: ${response.statusCode}")
        }
        val res = SimpleJWResponse.fromJson(
            parseJsonObject(data.toString(Charsets.UTF_8)) ?: throw TeachingResponseError.MalformedResponse
        )
        debugLog(
            "xk_insert_xfz status=${res.status} messageInt=${res.messageInt} messageString=${res.messageString}"
        )
        if (res.status != 0) {
            throw CCZUError.Unknown(
                "选课失败: status=${res.status}, message=${res.messageString ?: res.messageInt?.toString() ?: "-1"}"
            )
        }
    }
}

/** 根据 idn 列表选课（自动查询并匹配条目） */
public suspend fun JwqywxApplication.selectCoursesByIdn(
    term: String,
    classCode: String,
    idns: List<Int>
) {
    val all = getSelectableCourses(term = term, classCode = classCode)
    val map = all.associateBy { it.idn }
    val items = idns.mapNotNull { map[it] }
    if (items.isEmpty()) return
    selectCourses(term = term, items = items)
}

/** 批量退课（xk_delete_xfzxkmd） */
public suspend fun JwqywxApplication.dropCourses(selectedIds: List<Int>): String {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    if (selectedIds.isEmpty()) return ""

    // 按抓包格式，结尾带逗号
    val idnlist = selectedIds.joinToString(",") + ","
    val (data, response) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.dropCoursesURL,
        fields = mapOf("idnlist" to idnlist, "yhid" to authId)
    )
    if (response.statusCode != 200) {
        throw CCZUError.Unknown("HTTP Status code: ${response.statusCode}")
    }
    val res = SimpleJWResponse.fromJson(
        parseJsonObject(data.toString(Charsets.UTF_8)) ?: throw TeachingResponseError.MalformedResponse
    )
    if (res.status != 0) {
        throw CCZUError.Unknown(
            "退课失败: status=${res.status}, message=${res.messageString ?: res.messageInt?.toString() ?: "-1"}"
        )
    }
    return res.messageString ?: ""
}
