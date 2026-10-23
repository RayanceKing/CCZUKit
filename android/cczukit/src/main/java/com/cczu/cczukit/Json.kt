package com.cczu.cczukit

import com.google.gson.JsonArray
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import com.google.gson.JsonParser
import com.google.gson.JsonPrimitive

/** 教务接口字段类型不稳定（数字可能是字符串、字段可能缺失），统一做宽容解析 */

internal fun JsonElement?.flexString(): String {
    val el = this ?: return ""
    if (el.isJsonNull) return ""
    return if (el.isJsonPrimitive) el.asString.trim() else el.toString().trim()
}

internal fun JsonElement?.flexStringOrNull(): String? {
    val el = this ?: return null
    if (el.isJsonNull) return null
    return if (el.isJsonPrimitive) el.asString.trim() else el.toString().trim()
}

internal fun JsonElement?.flexInt(): Int = flexIntOrNull() ?: 0

internal fun JsonElement?.flexIntOrNull(): Int? {
    val el = this ?: return null
    if (el.isJsonNull || !el.isJsonPrimitive) return null
    val primitive = el.asJsonPrimitive
    if (primitive.isNumber) return primitive.asInt
    val raw = primitive.asString.trim()
    if (raw.isEmpty()) return null
    raw.toIntOrNull()?.let { return it }
    raw.toDoubleOrNull()?.let { return it.toInt() }
    return null
}

internal fun JsonElement?.flexDouble(): Double = flexDoubleOrNull() ?: 0.0

internal fun JsonElement?.flexDoubleOrNull(): Double? {
    val el = this ?: return null
    if (el.isJsonNull || !el.isJsonPrimitive) return null
    val primitive = el.asJsonPrimitive
    if (primitive.isNumber) return primitive.asDouble
    val raw = primitive.asString.trim()
    if (raw.isEmpty()) return null
    raw.toDoubleOrNull()?.let { return it }
    raw.toIntOrNull()?.let { return it.toDouble() }
    return null
}

internal fun JsonElement?.flexBool(): Boolean {
    val el = this ?: return false
    if (el.isJsonNull || !el.isJsonPrimitive) return false
    val primitive = el.asJsonPrimitive
    if (primitive.isBoolean) return primitive.asBoolean
    if (primitive.isNumber) return primitive.asInt != 0
    val raw = primitive.asString.trim().lowercase()
    return raw == "1" || raw == "true" || raw == "y" || raw == "yes"
}

internal fun JsonObject.obj(name: String): JsonObject? =
    get(name)?.takeIf { it.isJsonObject }?.asJsonObject

/** 只接受真正的 JSON 字符串（数字 / bool 视为缺失），用于课表这类混合类型的字段 */
internal fun JsonElement?.strictStringOrNull(): String? {
    val el = this ?: return null
    if (!el.isJsonPrimitive) return null
    val primitive = el.asJsonPrimitive
    return if (primitive.isString) primitive.asString.trim() else null
}

internal fun JsonObject.arr(name: String): JsonArray? =
    get(name)?.takeIf { it.isJsonArray }?.asJsonArray

internal fun JsonObject.stringMap(): Map<String, String> {
    val result = LinkedHashMap<String, String>()
    for ((key, value) in entrySet()) {
        result[key] = value.flexString()
    }
    return result
}

/** 把任意 Kotlin 值转成 JsonElement，用于构造请求体 */
internal fun Any?.toJsonElement(): JsonElement = when (this) {
    null -> com.google.gson.JsonNull.INSTANCE
    is JsonElement -> this
    is Map<*, *> -> JsonObject().also { obj ->
        for ((k, v) in this) {
            obj.add(k.toString(), v.toJsonElement())
        }
    }
    is Iterable<*> -> JsonArray().also { arr ->
        for (item in this) arr.add(item.toJsonElement())
    }
    is Array<*> -> JsonArray().also { arr ->
        for (item in this) arr.add(item.toJsonElement())
    }
    is Number -> JsonPrimitive(this)
    is Boolean -> JsonPrimitive(this)
    else -> JsonPrimitive(toString())
}

internal fun parseJsonObject(text: String): JsonObject? {
    val el = runCatching { JsonParser.parseString(text) }.getOrNull() ?: return null
    return el.takeIf { it.isJsonObject }?.asJsonObject
}

internal fun parseJsonElement(text: String): JsonElement? =
    runCatching { JsonParser.parseString(text) }.getOrNull()
