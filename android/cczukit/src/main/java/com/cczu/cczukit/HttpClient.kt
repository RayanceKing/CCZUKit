package com.cczu.cczukit

import com.google.gson.JsonElement
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.suspendCancellableCoroutine
import okhttp3.Call
import okhttp3.Callback
import okhttp3.Cookie
import okhttp3.CookieJar
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import okhttp3.Response
import okhttp3.MediaType.Companion.toMediaType
import java.io.IOException
import java.util.concurrent.TimeUnit

/** HTTP 响应（不暴露 OkHttp 的 Response，body 已一次性读取） */
public class HttpResponse(
    public val code: Int,
    public val url: String,
    private val rawHeaders: Map<String, String> = emptyMap()
) {
    public val headers: Map<String, String> get() = rawHeaders

    public fun header(name: String): String? =
        rawHeaders.entries.firstOrNull { it.key.equals(name, ignoreCase = true) }?.value

    /** 对应 Swift 版 `HTTPURLResponse.statusCode` */
    public val statusCode: Int get() = code
}

/** 请求结果：`(Data, HTTPURLResponse)` 的 Kotlin 等价物 */
public data class HttpResult(
    public val data: ByteArray,
    public val response: HttpResponse
)

private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()
private val FORM_MEDIA_TYPE = "application/x-www-form-urlencoded".toMediaType()

/** HTTP 客户端协议（对应 Swift 版 HTTPClient） */
public interface HttpClient {
    public val account: Account
    public val okHttpClient: OkHttpClient
    public val properties: PropertyStorage

    public suspend fun request(
        url: String,
        method: String = "GET",
        headers: Map<String, String>? = null,
        body: RequestBody? = null
    ): HttpResult
}

/**
 * 简易内存 CookieJar。
 * 除了正常的请求注入，还允许读取指定 URL 下的 Cookie（SSO 登录需要读取 clientInfo）
 */
public class CCZUCookieJar : CookieJar {
    private val lock = Any()
    private val store: LinkedHashMap<String, LinkedHashMap<String, Cookie>> = LinkedHashMap()

    override fun saveFromResponse(url: HttpUrl, cookies: List<Cookie>) {
        synchronized(lock) {
            for (cookie in cookies) {
                val bucket = store.getOrPut(cookie.domain) { LinkedHashMap() }
                if (cookie.value.isEmpty()) bucket.remove(cookie.name) else bucket[cookie.name] = cookie
            }
        }
    }

    override fun loadForRequest(url: HttpUrl): List<Cookie> = cookiesFor(url)

    public fun cookiesFor(url: HttpUrl): List<Cookie> = synchronized(lock) {
        val now = System.currentTimeMillis()
        val result = ArrayList<Cookie>()
        for ((domain, cookies) in store) {
            if (!matches(url.host, domain)) continue
            for (cookie in cookies.values) {
                if (cookie.expiresAt <= now) continue
                if (cookie.secure && !url.isHttps) continue
                result.add(cookie)
            }
        }
        result
    }

    public fun cookie(url: HttpUrl, name: String): Cookie? =
        cookiesFor(url).firstOrNull { it.name == name }

    public fun clear() {
        synchronized(lock) { store.clear() }
    }

    private fun matches(host: String, domain: String): Boolean =
        host.equals(domain, ignoreCase = true) || host.endsWith(".$domain", ignoreCase = true)
}

/** 默认 OkHttp 客户端，超时与 Swift 版 URLSessionConfiguration 对齐 */
public fun defaultOkHttpClientBuilder(cookieJar: CookieJar = CCZUCookieJar()): OkHttpClient.Builder =
    OkHttpClient.Builder()
        .cookieJar(cookieJar)
        // Swift: timeoutIntervalForRequest = 20 / timeoutIntervalForResource = 30
        .connectTimeout(20, TimeUnit.SECONDS)
        .readTimeout(20, TimeUnit.SECONDS)
        .writeTimeout(20, TimeUnit.SECONDS)
        .callTimeout(30, TimeUnit.SECONDS)
        // SSO 登录需要自行处理 302 与 Location，因此关闭自动跟随重定向
        .followRedirects(false)
        .followSslRedirects(false)
        .retryOnConnectionFailure(true)

/** 默认 HTTP 客户端实现 */
public class DefaultHttpClient(
    override val account: Account = Account.DEFAULT,
    cookieJar: CookieJar = CCZUCookieJar(),
    builder: OkHttpClient.Builder = defaultOkHttpClientBuilder(cookieJar),
    override val properties: PropertyStorage = PropertyStorage()
) : HttpClient {

    public constructor(username: String, password: String) : this(Account(username, password))

    override val okHttpClient: OkHttpClient = builder.build()

    override suspend fun request(
        url: String,
        method: String,
        headers: Map<String, String>?,
        body: RequestBody?
    ): HttpResult {
        val verb = method.uppercase()
        val requestBody: RequestBody? = body ?: if (verb == "POST" || verb == "PUT" || verb == "PATCH") {
            ByteArray(0).toRequestBody(null, 0, 0)
        } else {
            null
        }

        val request = Request.Builder()
            .url(url)
            .method(verb, requestBody)
            .apply {
                for ((key, value) in CCZUConstants.defaultHeaders) header(key, value)
                headers?.forEach { (key, value) -> header(key, value) }
            }
            .build()

        val response = okHttpClient.newCall(request).await()
        return response.use { resp ->
            val bytes = resp.body?.bytes() ?: ByteArray(0)
            val httpResponse = HttpResponse(resp.code, resp.request.url.toString(), resp.headers.toMap())
            val result = HttpResult(bytes, httpResponse)
            if (isLoginEndpoint(url)) {
                TeachingResponseValidator.validate(bytes, httpResponse)
            }
            result
        }
    }

    public companion object {
        @JvmStatic
        public fun withCredentials(username: String, password: String): DefaultHttpClient =
            DefaultHttpClient(Account(username, password))

        internal fun isLoginEndpoint(url: String): Boolean {
            val target = url.toHttpUrlOrNull() ?: return false
            val login = CCZUConstants.Jwqywx.loginURL.toHttpUrlOrNull() ?: return false
            return target.host == login.host
        }
    }
}

private suspend fun Call.await(): Response = suspendCancellableCoroutine { cont ->
    cont.invokeOnCancellation { cancel() }
    enqueue(object : Callback {
        override fun onResponse(call: Call, response: Response) {
            cont.resumeWith(Result.success(response))
        }

        override fun onFailure(call: Call, e: IOException) {
            val error: Throwable =
                if (call.isCanceled()) CancellationException("Request canceled") else CCZUError.NetworkError(e)
            if (cont.isActive) cont.resumeWith(Result.failure(error))
        }
    })
}

// MARK: - 便捷方法

public suspend fun HttpClient.get(
    url: String,
    headers: Map<String, String>? = null
): HttpResult = request(url, "GET", headers)

public suspend fun HttpClient.post(
    url: String,
    headers: Map<String, String>? = null,
    body: RequestBody? = null
): HttpResult = request(url, "POST", headers, body)

/** 发送 JSON（Content-Type: application/json;charset=utf-8），对应 Swift 的 anyJSON 版本 */
public suspend fun HttpClient.postJson(
    url: String,
    headers: Map<String, String> = emptyMap(),
    json: JsonElement
): HttpResult {
    val allHeaders = headers.toMutableMap()
    allHeaders["Content-Type"] = "application/json;charset=utf-8"
    return request(url, "POST", allHeaders, json.toString().toRequestBody(JSON_MEDIA_TYPE))
}

/** 发送 JSON（Content-Type: application/json），对应 Swift 的 Encodable 版本 */
public suspend fun HttpClient.postJson(
    url: String,
    headers: Map<String, String>? = null,
    fields: Map<String, Any?>
): HttpResult {
    val allHeaders = (headers ?: emptyMap()).toMutableMap()
    allHeaders["Content-Type"] = "application/json"
    val json = com.google.gson.JsonObject().apply {
        for ((key, value) in fields) add(key, value.toJsonElement())
    }
    return request(url, "POST", allHeaders, json.toString().toRequestBody(JSON_MEDIA_TYPE))
}

/** 发送表单，OkHttp 会负责 urlencode（比 Swift 的手工转义更规范） */
public suspend fun HttpClient.postForm(
    url: String,
    headers: Map<String, String>? = null,
    form: Map<String, String>
): HttpResult {
    val allHeaders = (headers ?: emptyMap()).toMutableMap()
    allHeaders["Content-Type"] = "application/x-www-form-urlencoded"
    val builder = okhttp3.FormBody.Builder()
    for ((key, value) in form) builder.add(key, value)
    return request(url, "POST", allHeaders, builder.build())
}
