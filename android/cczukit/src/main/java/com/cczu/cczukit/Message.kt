package com.cczu.cczukit

import com.google.gson.JsonObject

/**
 * 教务接口通用响应包装
 * 只有 status == 0 才视为成功；否则抛出 [TeachingResponseError.Rejected]
 */
public class Message<T>(
    public val status: Int,
    public val message: List<T>,
    public val token: String?
)

/**
 * 解析 `{"status":0,"message":[...],"token":"..."}` 结构
 * 与 Swift 版 `Message<T>` 的 `init(from:)` 语义一致：status != 0 直接失败
 */
internal fun <T> parseMessage(
    root: JsonObject,
    elementParser: (JsonObject) -> T
): Message<T> {
    val status = root["status"]?.flexInt()
        ?: throw TeachingResponseError.MalformedResponse
    val token = root["token"]?.flexStringOrNull()
    if (status != 0) {
        val reason = (root["message"]?.flexStringOrNull())?.takeIf { it.isNotEmpty() }
        throw TeachingResponseError.Rejected(status, reason)
    }
    val array = root.arr("message") ?: throw TeachingResponseError.MalformedResponse
    val items = ArrayList<T>(array.size())
    for (element in array) {
        if (!element.isJsonObject) continue
        items.add(elementParser(element.asJsonObject))
    }
    return Message(status, items, token)
}

internal fun <T> parseMessageFromJson(
    text: String,
    elementParser: (JsonObject) -> T
): Message<T> {
    val root = parseJsonObject(text) ?: throw TeachingResponseError.MalformedResponse
    return parseMessage(root, elementParser)
}
