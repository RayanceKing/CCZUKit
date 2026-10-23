package com.cczu.cczukit

/**
 * CCZU API 错误类型（对应 Swift 版 CCZUError）
 */
public sealed class CCZUError(message: String, cause: Throwable? = null) : Exception(message, cause) {
    public class NetworkError(cause: Throwable) :
        CCZUError("网络错误: ${cause.message ?: cause::class.java.simpleName}", cause)

    public object InvalidResponse : CCZUError("无效的响应")

    public class LoginFailed(reason: String) : CCZUError("登录失败: $reason")

    /** 账号或密码错误 */
    public object InvalidCredentials : CCZUError("账号或密码错误，请检查输入")

    public class SsoLoginFailed(reason: String) : CCZUError("SSO登录失败: $reason")

    public object NotLoggedIn : CCZUError("未登录")

    public class DecodingError(cause: Throwable) :
        CCZUError("数据解析错误: ${cause.message ?: cause::class.java.simpleName}", cause)

    public class MissingData(description: String) : CCZUError("缺少数据: $description")

    public class Unknown(message: String) : CCZUError("未知错误: $message")
}
