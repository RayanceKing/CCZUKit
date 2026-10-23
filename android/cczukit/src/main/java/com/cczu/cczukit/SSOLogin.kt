package com.cczu.cczukit

import com.cczu.cczukit.models.ElinkLoginInfo
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import java.util.Base64

/** SSO 登录连接类型 */
public enum class SSOLoginConnectType(public val rawValue: String) {
    WEBVPN("WEBVPN"),
    COMMON("COMMON")
}

/** SSO 统一登录 */
public suspend fun DefaultHttpClient.ssoUniversalLogin(): ElinkLoginInfo? {
    val url = CCZUConstants.SSO.loginURL
    val (_, response) = get(url)

    return when (response.statusCode) {
        302 -> handleWebVPNLogin(response)          // WebVPN 模式
        200 -> {                                     // 普通模式
            ssoServiceLogin(service = "")
            properties.set("SSOLoginConnectType", Property.string(SSOLoginConnectType.COMMON.rawValue))
            null
        }
        else -> throw CCZUError.LoginFailed("Unexpected status code: ${response.statusCode}")
    }
}

/** SSO 服务登录 */
public suspend fun DefaultHttpClient.ssoServiceLogin(service: String): HttpResult {
    val url = CCZUConstants.SSO.serviceLoginURL(service)
    val (data, response) = get(url)

    // 已登录，直接重定向
    if (response.statusCode == 302) {
        val location = response.header("Location")
        val redirectURL = location?.let { resolveUrl(url, it) }
        if (redirectURL != null) return recursionRedirectHandle(redirectURL)
    }

    // 需要登录
    val html = data.toString(Charsets.UTF_8)
    val loginParam = parseHiddenValues(html).toMutableMap().apply {
        put("username", account.username)
        put("password", base64(account.password))
    }

    val (_, loginResponse) = postForm(url = url, form = loginParam)

    if (loginResponse.statusCode == 302) {
        val location = loginResponse.header("Location")
        val redirectURL = location?.let { resolveUrl(url, it) }
        if (redirectURL != null) return recursionRedirectHandle(redirectURL)
    }

    if (loginResponse.statusCode == 200) {
        // 账号密码错误时返回 200 + 登录页
        val responseHtml = data.toString(Charsets.UTF_8)
        if (responseHtml.contains("用户名不存在") ||
            responseHtml.contains("密码错误") ||
            responseHtml.contains("用户名或密码错误")
        ) {
            throw CCZUError.InvalidCredentials
        }
        return HttpResult(ByteArray(0), loginResponse)
    }

    throw CCZUError.SsoLoginFailed("SSO服务登录失败")
}

private suspend fun DefaultHttpClient.handleWebVPNLogin(response: HttpResponse): ElinkLoginInfo? {
    val location = response.header("Location") ?: throw CCZUError.SsoLoginFailed("缺少重定向地址")
    val redirectURL = resolveUrl(response.url, location)
        ?: throw CCZUError.SsoLoginFailed("缺少重定向地址")

    val (pageData, _) = recursionRedirectHandle(redirectURL)
    val html = pageData.toString(Charsets.UTF_8)

    val form = parseHiddenValues(html).toMutableMap().apply {
        put("username", account.username)
        put("password", base64(account.password))
    }

    val (_, loginResponse) = postForm(url = redirectURL, form = form)

    // 没有 Location 表示登录失败
    val loginLocation = loginResponse.header("Location")
        ?: throw CCZUError.InvalidCredentials
    val loginRedirectURL = resolveUrl(redirectURL, loginLocation)
        ?: throw CCZUError.InvalidCredentials

    val headers = CCZUConstants.defaultHeaders.toMutableMap().apply {
        put("Referer", CCZUConstants.rootVPNURL)
    }
    get(url = loginRedirectURL, headers = headers)

    // 从 Cookie 中提取 clientInfo
    val httpUrl = loginRedirectURL.toHttpUrlOrNull() ?: throw CCZUError.SsoLoginFailed("无法提取登录信息")
    val jar = okHttpClient.cookieJar as? CCZUCookieJar
        ?: throw CCZUError.SsoLoginFailed("无法提取登录信息")
    val cookieValue = jar.cookie(httpUrl, "clientInfo")?.value
        ?: throw CCZUError.SsoLoginFailed("无法提取登录信息")

    val decoded = runCatching { Base64.getDecoder().decode(cookieValue) }
        .recoverCatching { Base64.getMimeDecoder().decode(cookieValue) }
        .getOrNull() ?: throw CCZUError.SsoLoginFailed("无法提取登录信息")

    val loginInfo = parseJsonObject(decoded.toString(Charsets.UTF_8))
        ?: throw CCZUError.SsoLoginFailed("无法提取登录信息")

    properties.set("SSOLoginConnectType", Property.string(SSOLoginConnectType.WEBVPN.rawValue))
    return ElinkLoginInfo.fromJson(loginInfo)
}

/** 递归处理重定向，最多 10 层 */
private suspend fun DefaultHttpClient.recursionRedirectHandle(
    url: String,
    depth: Int = 0
): HttpResult {
    if (depth >= 10) throw CCZUError.Unknown("Too many redirects")

    val (data, response) = get(url)

    if (response.statusCode == 302) {
        val location = response.header("Location")
        if (location != null) {
            val nextURL = if (location.startsWith("http", ignoreCase = true)) {
                location
            } else {
                resolveUrl(url, location) ?: throw CCZUError.Unknown("Invalid relative redirect URL")
            }
            return recursionRedirectHandle(nextURL, depth + 1)
        }
    }

    return HttpResult(data, response)
}

private fun base64(value: String): String =
    Base64.getEncoder().encodeToString(value.toByteArray(Charsets.UTF_8))

internal fun resolveUrl(base: String, location: String): String? {
    if (location.startsWith("http", ignoreCase = true)) return location
    val baseUrl = base.toHttpUrlOrNull() ?: return null
    return baseUrl.resolve(location)?.toString()
}

/** 解析 HTML 中的 `<input type="hidden">` 字段 */
internal fun parseHiddenValues(html: String): Map<String, String> {
    val result = LinkedHashMap<String, String>()
    val pattern = Regex("""<input[^>]*type\s*=\s*["']hidden["'][^>]*>""", RegexOption.IGNORE_CASE)
    for (match in pattern.findAll(html)) {
        val tag = match.value
        val name = extractAttribute("name", tag)
        val value = extractAttribute("value", tag)
        if (name != null && value != null) result[name] = value
    }
    return result
}

/** 提取 HTML 属性值 */
internal fun extractAttribute(attribute: String, html: String): String? {
    val pattern = Regex(
        """$attribute\s*=\s*["']([^"']*)["']""",
        setOf(RegexOption.IGNORE_CASE)
    )
    return pattern.find(html)?.groupValues?.getOrNull(1)
}

/** 解析 HTML 中的 `<input type="hidden">` 字段 */