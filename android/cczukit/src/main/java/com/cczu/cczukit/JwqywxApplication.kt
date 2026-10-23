package com.cczu.cczukit

import com.cczu.cczukit.models.LoginUserData
import com.cczu.cczukit.models.TrainingPlan
import com.google.gson.JsonElement
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.io.File
import kotlin.coroutines.coroutineContext

/**
 * 教务企业微信应用（对应 Swift 版 JwqywxApplication）
 *
 * Swift 版是 @MainActor 类；Kotlin 版内部用锁 + 协程 scope 保证状态安全，
 * 所有方法都是 suspend，可在任意调度器上调用。
 */
public class JwqywxApplication(
    public val client: DefaultHttpClient,
    private val cacheDir: File? = null
) {

    internal val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    internal val loginMutex = Mutex()

    @Volatile
    internal var loginDeferred: Deferred<Message<LoginUserData>>? = null

    /** 登录成功后写入，形如 "Bearer xxx" */
    @Volatile
    public var authorizationToken: String? = null
        internal set

    /** 授权 ID（yhid） */
    @Volatile
    public var authorizationId: String? = null
        internal set

    /** 学号 */
    @Volatile
    public var studentNumber: String? = null
        internal set

    @Volatile
    internal var customHeaders: Map<String, String> =
        CCZUConstants.defaultHeaders.toMutableMap().apply {
            this["Referer"] = CCZUConstants.Jwqywx.referer
            this["Origin"] = CCZUConstants.Jwqywx.origin
        }

    @Volatile
    internal var authenticationGeneration: Int = 0

    /** 培养方案最近一次原始响应（调试用） */
    @Volatile
    public var lastTrainingPlanRawResponse: String? = null
        internal set

    public var enableDebugLogging: Boolean = false

    private val trainingPlanMutex = Mutex()

    @Volatile
    private var trainingPlanCache: TrainingPlan? = null

    internal fun debugLog(message: String) {
        if (enableDebugLogging) println("[DEBUG] $message")
    }

    // MARK: - 带认证的公共请求入口

    /**
     * 执行一次需要登录态的请求；遇到明确的登录失效会自动重新登录并重试一次。
     */
    internal suspend fun authenticatedRequest(
        operation: suspend (headers: Map<String, String>) -> HttpResult
    ): HttpResult {
        ensureLoggedIn()
        val rejectedGeneration = authenticationGeneration
        try {
            return operation(customHeaders)
        } catch (expired: TeachingResponseError.AuthenticationExpired) {
            coroutineContext.ensureActive()
            // 其他请求可能已经刷新过会话，只有代次未变时才重新登录
            if (authenticationGeneration == rejectedGeneration) login()
            coroutineContext.ensureActive()
            try {
                return operation(customHeaders)
            } catch (retryExpired: TeachingResponseError.AuthenticationExpired) {
                throw TeachingResponseError.RecoveryFailed
            }
        }
    }

    internal suspend fun postAuthenticatedJson(
        url: String,
        json: JsonElement
    ): HttpResult = authenticatedRequest { headers ->
        client.postJson(url = url, headers = headers, json = json)
    }

    internal suspend fun postAuthenticatedJson(
        url: String,
        fields: Map<String, Any?>
    ): HttpResult = authenticatedRequest { headers ->
        client.postJson(url = url, headers = headers, fields = fields)
    }

    internal suspend fun getAuthenticated(url: String): HttpResult =
        authenticatedRequest { headers -> client.get(url = url, headers = headers) }

    // MARK: - 培养方案内存缓存

    internal suspend fun cachedTrainingPlan(): TrainingPlan? =
        trainingPlanMutex.withLock { trainingPlanCache }

    internal suspend fun storeTrainingPlan(plan: TrainingPlan) {
        trainingPlanMutex.withLock { trainingPlanCache = plan }
    }

    public suspend fun clearTrainingPlanCache() {
        trainingPlanMutex.withLock { trainingPlanCache = null }
    }

    // MARK: - 磁盘缓存目录

    internal fun cacheDirectory(): File {
        val base = cacheDir ?: File(System.getProperty("java.io.tmpdir") ?: ".", CCZUConstants.Jwqywx.cacheDirectoryName)
        if (!base.exists()) base.mkdirs()
        return base
    }

    internal fun trainingPlanCacheFile(studentNumber: String): File = File(
        cacheDirectory(),
        "${CCZUConstants.Jwqywx.trainingPlanCachePrefix}$studentNumber${CCZUConstants.Jwqywx.trainingPlanCacheExtension}"
    )
}
