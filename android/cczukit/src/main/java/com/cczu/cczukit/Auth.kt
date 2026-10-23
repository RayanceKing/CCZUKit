package com.cczu.cczukit

import com.cczu.cczukit.models.CourseGrade
import com.cczu.cczukit.models.LoginUserData
import com.cczu.cczukit.models.StudentPoint
import com.cczu.cczukit.models.Term
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.async
import kotlinx.coroutines.ensureActive
import kotlin.coroutines.coroutineContext
import kotlinx.coroutines.sync.withLock

/** 登录教务企业微信（并发调用会复用同一次登录，与 Swift 的 Task 去重一致） */
public suspend fun JwqywxApplication.login(): Message<LoginUserData> {
    val deferred = loginMutex.withLock {
        loginDeferred ?: scope.async(start = CoroutineStart.LAZY) { loginOnce() }
            .also { loginDeferred = it }
    }
    return try {
        deferred.await()
    } finally {
        loginMutex.withLock { if (loginDeferred === deferred) loginDeferred = null }
    }
}

public suspend fun JwqywxApplication.ensureLoggedIn() {
    loginDeferred?.let { deferred ->
        deferred.await()
        return
    }
    if (authorizationToken == null) login()
    coroutineContext.ensureActive()
}

private suspend fun JwqywxApplication.loginOnce(): Message<LoginUserData> {
    val url = CCZUConstants.Jwqywx.loginURL

    val loginFields: Map<String, String> = mapOf(
        "userid" to client.account.username,
        "userpwd" to client.account.password
    )

    // 登录请求不携带 Authorization
    val loginHeaders = customHeaders.toMutableMap().apply {
        remove(CCZUConstants.Jwqywx.authHeader)
    }

    val (data, response) = client.postJson(url = url, headers = loginHeaders, fields = loginFields)

    if (response.statusCode != 200) {
        throw CCZUError.LoginFailed("HTTP Status code: ${response.statusCode}")
    }

    val message = parseMessageFromJson(data.toString(Charsets.UTF_8)) { LoginUserData.fromJson(it) }

    val token = message.token ?: throw CCZUError.LoginFailed("未收到认证令牌")
    val userData = message.message.firstOrNull() ?: throw CCZUError.LoginFailed("未收到用户数据")

    // 用户 ID 为空表示账号或密码错误
    if (userData.id.isEmpty() || userData.userid.isEmpty()) {
        throw CCZUError.InvalidCredentials
    }

    authorizationToken = "${CCZUConstants.Jwqywx.bearerPrefix}$token"
    authorizationId = userData.id
    studentNumber = userData.userid

    customHeaders = customHeaders.toMutableMap().apply {
        put(CCZUConstants.Jwqywx.authHeader, authorizationToken ?: "")
    }
    authenticationGeneration += 1

    return message
}

// MARK: - 成绩查询

public suspend fun JwqywxApplication.getGrades(): Message<CourseGrade> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.gradesURL,
        fields = mapOf("xh" to authId)
    )
    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { CourseGrade.fromJson(it) }
}

public suspend fun JwqywxApplication.getCreditsAndRank(): Message<StudentPoint> {
    val authId = authorizationId ?: throw CCZUError.NotLoggedIn
    val (data, _) = postAuthenticatedJson(
        url = CCZUConstants.Jwqywx.creditsAndRankURL,
        fields = mapOf("xh" to authId)
    )
    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { StudentPoint.fromJson(it) }
}

// MARK: - 学期信息

public suspend fun JwqywxApplication.getTerms(): Message<Term> {
    val (data, _) = getAuthenticated(CCZUConstants.Jwqywx.termsURL)
    return parseMessageFromJson(data.toString(Charsets.UTF_8)) { Term.fromJson(it) }
}

/** 当前学期号（如 "25-26-1"） */
public suspend fun JwqywxApplication.getCurrentTerm(): String {
    val terms = getTerms()
    return terms.message.firstOrNull()?.term
        ?: throw CCZUError.MissingData(CCZUConstants.Jwqywx.noTermFoundMessage)
}
