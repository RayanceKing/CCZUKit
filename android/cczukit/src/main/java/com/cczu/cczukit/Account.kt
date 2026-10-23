package com.cczu.cczukit

/** 账号信息 */
public data class Account(
    val username: String = "",
    val password: String = ""
) {
    public companion object {
        @JvmField
        public val DEFAULT: Account = Account()
    }
}
