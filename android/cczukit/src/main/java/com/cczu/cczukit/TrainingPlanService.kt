package com.cczu.cczukit

import com.cczu.cczukit.models.TrainingPlan
import com.cczu.cczukit.models.TrainingPlanParser

/** 获取并缓存培养方案（内存 + 磁盘缓存） */
public suspend fun JwqywxApplication.getTrainingPlan(forceRefresh: Boolean = false): TrainingPlan {
    if (!forceRefresh) {
        cachedTrainingPlan()?.let { return it }
    }
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val stuNum = studentNumber ?: throw CCZUError.NotLoggedIn

    if (!forceRefresh) {
        runCatching { loadTrainingPlanFromDisk(studentNumber = stuNum) }.getOrNull()?.let { disk ->
            storeTrainingPlan(disk)
            return disk
        }
    }

    val url = CCZUConstants.Jwqywx.trainingPlanURL
    val cleanStudentNumber = stuNum.trim()
    val requestData: MutableMap<String, Any?> = mutableMapOf(
        "xh" to authId,
        "yhid" to authId
    )

    val basic = getStudentBasicInfo()
    val info = basic.message.firstOrNull() ?: throw CCZUError.MissingData("学生基本信息")
    requestData["nj"] = info.grade
    requestData["xz"] = info.studyLength
    if (info.majorCode.isNotEmpty()) requestData["zydm"] = info.majorCode

    var (data, _) = postAuthenticatedJson(url = url, fields = requestData)
    lastTrainingPlanRawResponse = data.toString(Charsets.UTF_8)

    val plan: TrainingPlan = try {
        TrainingPlanParser.parse(data.toString(Charsets.UTF_8), basicInfo = info)
    } catch (e: Exception) {
        if (e is kotlinx.coroutines.CancellationException) throw e
        // 失败或返回空数组时，回退用学号作为 xh 再试一次
        requestData["xh"] = cleanStudentNumber
        val retry = postAuthenticatedJson(url = url, fields = requestData)
        data = retry.data
        lastTrainingPlanRawResponse = data.toString(Charsets.UTF_8)
        TrainingPlanParser.parse(data.toString(Charsets.UTF_8), basicInfo = info)
    }

    storeTrainingPlan(plan)
    runCatching { saveTrainingPlanToDisk(plan, studentNumber = stuNum) }
    return plan
}

/** 预取培养方案（触发网络并落盘） */
public suspend fun JwqywxApplication.prefetchTrainingPlan(): TrainingPlan {
    authorizationId ?: throw CCZUError.NotLoggedIn
    studentNumber ?: throw CCZUError.NotLoggedIn
    return getTrainingPlan()
}

/** 删除磁盘缓存 */
public fun JwqywxApplication.deleteTrainingPlanDiskCache() {
    val stuNum = studentNumber ?: return
    runCatching { trainingPlanCacheFile(stuNum).delete() }
}

private fun JwqywxApplication.saveTrainingPlanToDisk(plan: TrainingPlan, studentNumber: String) {
    val file = trainingPlanCacheFile(studentNumber)
    file.writeText(plan.toJson().toString(), Charsets.UTF_8)
}

private fun JwqywxApplication.loadTrainingPlanFromDisk(studentNumber: String): TrainingPlan? {
    val file = trainingPlanCacheFile(studentNumber)
    if (!file.exists()) return null
    val root = parseJsonObject(file.readText(Charsets.UTF_8)) ?: return null
    return TrainingPlan.fromJson(root)
}
