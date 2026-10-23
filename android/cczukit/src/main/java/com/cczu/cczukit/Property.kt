package com.cczu.cczukit

/** 客户端属性（对应 Swift 版 Property） */
public sealed class Property {
    public data class Str(val value: String) : Property()
    public data class Integer(val value: Int) : Property()
    public data class Bool(val value: Boolean) : Property()

    public val stringValue: String? get() = (this as? Str)?.value
    public val intValue: Int? get() = (this as? Integer)?.value
    public val boolValue: Boolean? get() = (this as? Bool)?.value

    public companion object {
        @JvmStatic
        public fun string(value: String): Property = Str(value)

        @JvmStatic
        public fun int(value: Int): Property = Integer(value)

        @JvmStatic
        public fun bool(value: Boolean): Property = Bool(value)
    }
}

/** 线程安全的属性存储（对应 Swift 版 actor PropertyStorage） */
public class PropertyStorage {
    private val lock = Any()
    private val storage: MutableMap<String, Property> = HashMap()

    public fun get(key: String): Property? = synchronized(lock) { storage[key] }

    public fun set(key: String, value: Property) {
        synchronized(lock) { storage[key] = value }
    }

    public fun remove(key: String) {
        synchronized(lock) { storage.remove(key) }
    }
}
