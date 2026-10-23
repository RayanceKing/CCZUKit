package com.cczu.cczukit

import com.google.gson.JsonObject
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull

/** 教务系统响应错误（对应 Swift 版 TeachingResponseError） */
public sealed class TeachingResponseError(message: String) : Exception(message) {
    public object AuthenticationExpired :
        TeachingResponseError("教务登录已失效，请重新登录后重试。")

    public object RecoveryFailed :
        TeachingResponseError("自动重新登录后，教务系统仍未接受登录状态。请稍后重试或重新登录。")

    public class HttpStatus(public val status: Int) :
        TeachingResponseError("教务系统请求失败（HTTP $status），请稍后重试。")

    public class Rejected(public val status: Int, public val reason: String?) : TeachingResponseError(
        reason?.let { "教务系统未能完成请求：$it（错误码 $status）" }
            ?: "教务系统未能完成请求（错误码 $status），请稍后重试。"
    )

    public object MalformedResponse : TeachingResponseError("教务系统返回的数据格式异常，本次更新未完成。")
}

internal object TeachingResponseValidator {

    private val authMessages = listOf(
        "未登录", "未登陆", "请先登录", "请先登陆", "登录失效", "登录已失效",
        "登录过期", "登录已过期", "登录超时", "登陆失效", "登陆过期",
        "重新登录", "重新登陆", "token expired", "token is expired",
        "invalid token", "token无效", "token失效", "token过期", "not logged in",
        "unauthorized", "jwt expired"
    )

    private val credentialMessages = listOf(
        "密码错误", "密码不正确", "用户名不存在", "账号或密码"
    )

    fun validate(data: ByteArray, response: HttpResponse) {
        val loginPath = CCZUConstants.Jwqywx.loginURL.toHttpUrlOrNull()?.encodedPath
        val isLogin = response.url.toHttpUrlOrNull()?.encodedPath == loginPath

        if (response.statusCode == 401) {
            if (isLogin) throw CCZUError.InvalidCredentials
            throw TeachingResponseError.AuthenticationExpired
        }
        if (response.statusCode >= 500) {
            throw TeachingResponseError.HttpStatus(response.statusCode)
        }

        val objectJson: JsonObject? = parseJsonObject(data.toString(Charsets.UTF_8))
        val message = (objectJson?.get("message")?.flexStringOrNull()
            ?: objectJson?.get("msg")?.flexStringOrNull()
            ?: "").lowercase()

        // 只有明确的认证失败才触发重新登录；403/5xx 可能是权限、维护或写入失败
        if (isLogin && credentialMessages.any { message.contains(it) }) {
            throw CCZUError.InvalidCredentials
        }
        if (authMessages.any { message.contains(it) }
            || objectJson?.get("status")?.flexIntOrNull() == 401
            || objectJson?.get("code")?.flexIntOrNull() == 401
        ) {
            throw TeachingResponseError.AuthenticationExpired
        }
        if (response.statusCode !in 200..299) {
            throw TeachingResponseError.HttpStatus(response.statusCode)
        }

        val status = objectJson?.get("status")?.flexIntOrNull()
            ?: throw TeachingResponseError.MalformedResponse
        if (status != 0) {
            val reason = (objectJson["message"]?.flexStringOrNull()
                ?: objectJson["msg"]?.flexStringOrNull())?.take(200)
            throw TeachingResponseError.Rejected(status, reason)
        }
    }
}
