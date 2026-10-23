package com.cczu.cczukit

import com.cczu.cczukit.models.Building
import com.cczu.cczukit.models.ElectricityArea
import com.cczu.cczukit.models.ElectricityResponse
import com.google.gson.JsonObject
import java.io.IOException

/** 预置校区列表 */
public fun JwqywxApplication.getElectricityAreas(): List<ElectricityArea> =
    CCZUConstants.Electricity.predefinedAreas.map {
        ElectricityArea(area = it.area, areaname = it.areaname, aid = it.aid)
    }

/** 获取指定校区的建筑物列表 */
public suspend fun JwqywxApplication.getBuildings(area: ElectricityArea): List<Building> {
    val areaJson = JsonObject().apply {
        addProperty("areaname", area.areaname)
        addProperty("area", area.area)
    }.toString()

    val payload = mapOf(
        "account" to CCZUConstants.Electricity.account,
        "area" to areaJson,
        "aid" to area.aid
    )

    val headers = customHeaders.toMutableMap().apply {
        this["User-Agent"] = CCZUConstants.Electricity.buildingUserAgent
    }

    val (data, response) = client.postForm(
        url = CCZUConstants.Electricity.queryBuildingURL,
        headers = headers,
        form = payload
    )

    if (response.statusCode != 200) {
        throw CCZUError.NetworkError(IOException("HTTP status code: ${response.statusCode}"))
    }

    // 后端 JSON 不规范，手动解析
    val root = parseJsonObject(data.toString(Charsets.UTF_8)) ?: return emptyList()
    val buildingArray = root.arr("buildingtab") ?: return emptyList()

    val buildings = ArrayList<Building>()
    for (element in buildingArray) {
        val obj = element.takeIf { it.isJsonObject }?.asJsonObject ?: continue
        val building = obj["building"].flexStringOrNull() ?: continue
        val buildingId = obj["buildingid"].flexStringOrNull() ?: continue
        buildings.add(Building(building = building, buildingid = buildingId))
    }
    return buildings
}

/** 查询电费信息 */
public suspend fun JwqywxApplication.queryElectricity(
    area: ElectricityArea,
    building: Building,
    roomId: String
): ElectricityResponse {
    val areaJson = JsonObject().apply {
        addProperty("area", area.area)
        addProperty("areaname", area.areaname)
    }.toString()
    val buildingJson = JsonObject().apply {
        addProperty("building", building.building)
        addProperty("buildingid", building.buildingid)
    }.toString()
    val floorJson = JsonObject().apply {
        addProperty("floorid", "")
        addProperty("floor", "")
    }.toString()
    val roomJson = JsonObject().apply {
        addProperty("room", "")
        addProperty("roomid", roomId)
    }.toString()

    val payload = mapOf(
        "aid" to area.aid,
        "account" to CCZUConstants.Electricity.account,
        "area" to areaJson,
        "building" to buildingJson,
        "floor" to floorJson,
        "room" to roomJson
    )

    val headers = customHeaders.toMutableMap().apply {
        this["User-Agent"] = CCZUConstants.Electricity.roomUserAgent
    }

    val (data, response) = client.postForm(
        url = CCZUConstants.Electricity.queryRoomURL,
        headers = headers,
        form = payload
    )

    if (response.statusCode != 200) {
        throw CCZUError.NetworkError(IOException("HTTP status code: ${response.statusCode}"))
    }

    val root = parseJsonObject(data.toString(Charsets.UTF_8))
        ?: throw TeachingResponseError.MalformedResponse
    return ElectricityResponse.fromJson(root)
}
