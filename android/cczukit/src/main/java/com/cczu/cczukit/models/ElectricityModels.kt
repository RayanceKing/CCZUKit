package com.cczu.cczukit.models

import com.cczu.cczukit.flexIntOrNull
import com.cczu.cczukit.flexString
import com.google.gson.JsonObject

/** 校区信息 */
public data class ElectricityArea(
    val area: String,
    val areaname: String,
    val aid: String
)

/** 建筑物信息 */
public data class Building(
    val building: String,
    val buildingid: String
)

/** 房间信息 */
public data class Room(
    val room: String,
    val roomid: String
)

/** 电费查询响应 */
public data class ElectricityResponse(
    val errmsg: String,
    val errcode: Int?
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): ElectricityResponse = ElectricityResponse(
            errmsg = obj["errmsg"].flexString(),
            errcode = obj["errcode"].flexIntOrNull()
        )
    }
}
