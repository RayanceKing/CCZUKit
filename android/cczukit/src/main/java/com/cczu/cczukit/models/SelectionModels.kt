package com.cczu.cczukit.models

import com.cczu.cczukit.flexBool
import com.cczu.cczukit.flexDouble
import com.cczu.cczukit.flexDoubleOrNull
import com.cczu.cczukit.flexInt
import com.cczu.cczukit.flexIntOrNull
import com.cczu.cczukit.flexString
import com.cczu.cczukit.flexStringOrNull
import com.google.gson.JsonObject
import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** 可选 / 已选课程项（来自 xk_xh_kbk） */
public data class SelectableCourse(
    val term: String,            // xq 学期
    val classCode: String,       // bh 班级号
    val className: String,       // bj 班级名
    val courseCode: String,      // kcdm 课程代码
    val courseName: String,      // kcmc 课程名称
    val courseSerial: String,    // kch 课程序列号
    val categoryCode: String,    // lbdh 类别代码
    val hours: Int,              // xs 学时
    val credits: Double,         // xf 学分
    val examTypeName: String,    // ksfs 考试方式（文字）
    val capacity: Int,           // kkrs 开课人数 / 容量
    val courseAttrCode: String,  // kcxbdm 课程属性代码
    val teacherCode: String,     // jsdm 教师代码
    val teacherName: String,     // jsmc 教师名称
    val isExamType: Int,         // ksxzm 考试性质码
    val examMode: Int,           // ksfsm 考试方式码
    val idn: Int,                // idn 课程标识
    val selectionStatus: String, // xkqk 选课情况（"已选" / 空）
    val selectedId: Int,         // xkidn 已选记录 ID（未选为 0）
    val studyType: String        // xklb 修读类别
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): SelectableCourse = SelectableCourse(
            term = obj["xq"].flexString(),
            classCode = obj["bh"].flexString(),
            className = obj["bj"].flexString(),
            courseCode = obj["kcdm"].flexString(),
            courseName = obj["kcmc"].flexString(),
            courseSerial = obj["kch"].flexString(),
            categoryCode = obj["lbdh"].flexString(),
            hours = obj["xs"].flexInt(),
            credits = obj["xf"].flexDouble(),
            examTypeName = obj["ksfs"].flexString(),
            capacity = obj["kkrs"].flexInt(),
            courseAttrCode = obj["kcxbdm"].flexString(),
            teacherCode = obj["jsdm"].flexString(),
            teacherName = obj["jsmc"].flexString(),
            isExamType = obj["ksxzm"].flexInt(),
            examMode = obj["ksfsm"].flexInt(),
            idn = obj["idn"].flexInt(),
            selectionStatus = obj["xkqk"].flexString(),
            selectedId = obj["xkidn"].flexInt(),
            studyType = obj["xklb"].flexString()
        )
    }
}

/** 简单响应（message 可能是 Int 或 String） */
public data class SimpleJWResponse(
    val status: Int,
    val token: String?,
    val messageInt: Int?,
    val messageString: String?
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): SimpleJWResponse {
            val status = obj["status"].flexInt()
            val messageInt = obj["message"].flexIntOrNull()
            val messageString = if (messageInt == null) obj["message"].flexStringOrNull() else null
            return SimpleJWResponse(
                status = status,
                token = obj["token"].flexStringOrNull(),
                messageInt = messageInt,
                messageString = messageString
            )
        }
    }
}

/** 选课批次信息 */
public data class SelectionBatch(
    val code: String,            // dm 批次代码，如 "0003-004"
    val name: String,            // mc 批次名称
    val grade: Int,              // nj 年级
    val term: String,            // xkxq 对应学期
    val remark: String,          // bz 备注
    val selectionMethod: String, // cxbmfs 选课方式
    val maxCourses: Int,         // xkmc 最多选课数
    val beginDate: String,       // begindate
    val endDate: String,         // enddate
    val isSelectable: Boolean    // xk 是否可选
) {
    /** 是否在开放时间段内 */
    public val isOpen: Boolean
        get() {
            val now = Instant.now()
            val begin = parseInstant(beginDate) ?: return false
            val end = parseInstant(endDate) ?: return false
            return !now.isBefore(begin) && !now.isAfter(end)
        }

    /** 是否允许选课（等同 isSelectable） */
    public val isAllowed: Boolean get() = isSelectable

    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): SelectionBatch = SelectionBatch(
            code = obj["dm"].flexString(),
            name = obj["mc"].flexString(),
            grade = obj["nj"].flexInt(),
            term = obj["xkxq"].flexString(),
            remark = obj["bz"].flexString(),
            selectionMethod = obj["cxbmfs"].flexString(),
            maxCourses = obj["xkmc"].flexInt(),
            beginDate = obj["begindate"].flexString(),
            endDate = obj["enddate"].flexString(),
            isSelectable = obj["xk"].flexBool()
        )

        internal fun parseInstant(raw: String): Instant? {
            val value = raw.trim()
            if (value.isEmpty()) return null
            runCatching { Instant.parse(value) }.getOrNull()?.let { return it }
            runCatching { OffsetDateTime.parse(value).toInstant() }.getOrNull()?.let { return it }
            val fallback = runCatching {
                DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss")
                    .withZone(ZoneId.systemDefault())
                    .parse(value, Instant::from)
            }.getOrNull()
            return fallback
        }
    }
}

/** 选课权限（某批次是否对该年级开放） */
public data class SelectionPermission(
    val isAllowed: Boolean,      // xk 是否有权选课（后端返回 0/1）
    val term: String,            // xkxq 对应学期
    val remark: String,          // bz 备注
    val selectionMethod: String, // cxbmfs 选课方式
    val maxCourses: Int          // xkmc 最多选课数
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): SelectionPermission = SelectionPermission(
            isAllowed = obj["xk"].flexInt() != 0,
            term = obj["xkxq"].flexString(),
            remark = obj["bz"].flexString(),
            selectionMethod = obj["cxbmfs"].flexString(),
            maxCourses = obj["xkmc"].flexInt()
        )
    }
}

/** 通识类选修课程项（来自 yxk_xk_xh_kxkc_gx） */
public data class GeneralElectiveCourse(
    val term: String,               // xq
    val courseSerial: Int,          // kcxh 课程序号
    val courseCode: String,         // kcdm
    val courseName: String,         // kcmc
    val teacherCode: String,        // jsdm
    val teacherName: String,        // jsmc
    val hours: Int,                 // xs
    val credits: Double,            // xf
    val categoryCode: String,       // lbdh
    val categoryName: String,       // lbmc
    val timeDescription: String,    // sj
    val capacity: Int,              // xxrs 限选人数
    val selectedCount: Int,         // xkrs 已选人数
    val availableCount: Int,        // kxrs 可选人数
    val batchCode: String,          // lbdm
    val description: String?,       // xxsm
    val campus: String,             // jse 教学地点
    val week: Int,                  // zc
    val startSlot: Int,             // jc1
    val endSlot: Int                // jc2
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): GeneralElectiveCourse = GeneralElectiveCourse(
            term = obj["xq"].flexString(),
            courseSerial = obj["kcxh"].flexInt(),
            courseCode = obj["kcdm"].flexString(),
            courseName = obj["kcmc"].flexString(),
            teacherCode = obj["jsdm"].flexString(),
            teacherName = obj["jsmc"].flexString(),
            hours = obj["xs"].flexInt(),
            credits = obj["xf"].flexDoubleOrNull()
                ?: obj["xf"].flexIntOrNull()?.toDouble() ?: 0.0,
            categoryCode = obj["lbdh"].flexString(),
            categoryName = obj["lbmc"].flexString(),
            timeDescription = obj["sj"].flexString(),
            capacity = obj["xxrs"].flexInt(),
            selectedCount = obj["xkrs"].flexInt(),
            availableCount = obj["kxrs"].flexInt(),
            batchCode = obj["lbdm"].flexString(),
            description = obj["xxsm"].flexStringOrNull(),
            campus = obj["jse"].flexString(),
            week = obj["zc"].flexInt(),
            startSlot = obj["jc1"].flexInt(),
            endSlot = obj["jc2"].flexInt()
        )
    }

    /** 复制并覆盖已选 / 可选人数（合并实际已选人数时使用） */
    public fun withCounts(selectedCount: Int, availableCount: Int): GeneralElectiveCourse =
        copy(selectedCount = selectedCount, availableCount = availableCount)
}

/** 实际已选人数项（yxk_xk_xkrs_gx） */
public data class ActualSelectedCount(
    val courseSerial: Int, // kcxh
    val selectedCount: Int // xkrs
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): ActualSelectedCount = ActualSelectedCount(
            courseSerial = obj["kcxh"].flexInt(),
            selectedCount = obj["xkrs"].flexInt()
        )
    }
}

/** 已选通识类选修课程项（来自 yxk_xk_xh_yxkc_gx） */
public data class SelectedGeneralElectiveCourse(
    val term: String,
    val studentId: String,
    val courseSerial: Int,
    val courseCode: String,
    val courseName: String,
    val teacherCode: String,
    val teacherName: String,
    val hours: Int,
    val credits: Double,
    val categoryCode: String,
    val categoryName: String,
    val timeDescription: String,
    val capacity: Int,
    val selectedCount: Int,
    val availableCount: Int,
    val batchCode: String,
    val description: String?,
    val campus: String,
    val week: Int,
    val startSlot: Int,
    val endSlot: Int
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): SelectedGeneralElectiveCourse {
            val capacity = obj["xxrs"].flexIntOrNull() ?: 0
            val selected = obj["xkrs"].flexIntOrNull() ?: 0
            return SelectedGeneralElectiveCourse(
                term = obj["xq"].flexString(),
                studentId = obj["xh"].flexString(),
                courseSerial = obj["kcxh"].flexInt(),
                courseCode = obj["kcdm"].flexString(),
                courseName = obj["kcmc"].flexString(),
                teacherCode = obj["jsdm"].flexString(),
                teacherName = obj["jsmc"].flexString(),
                hours = obj["xs"].flexInt(),
                credits = obj["xf"].flexDoubleOrNull()
                    ?: obj["xf"].flexIntOrNull()?.toDouble() ?: 0.0,
                categoryCode = obj["lbdh"].flexString(),
                categoryName = obj["lbmc"].flexString(),
                timeDescription = obj["sj"].flexString(),
                capacity = capacity,
                selectedCount = selected,
                availableCount = obj["kxrs"].flexIntOrNull()
                    ?: (capacity - selected).coerceAtLeast(0),
                batchCode = obj["lbdm"].flexString(),
                description = obj["xxsm"].flexStringOrNull(),
                campus = obj["jse"].flexString(),
                week = obj["zc"].flexInt(),
                startSlot = obj["jc1"].flexInt(),
                endSlot = obj["jc2"].flexInt()
            )
        }
    }
}

/** 通识类选修批次权限（yxk_xkqx_dm_nj） */
public data class GeneralElectivePermission(
    val isAllowed: Boolean,
    val term: String,
    val remark: String,
    val selectionMethod: String,
    val maxCourses: Int
) {
    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): GeneralElectivePermission = GeneralElectivePermission(
            isAllowed = obj["xk"].flexInt() != 0,
            term = obj["xkxq"].flexString(),
            remark = obj["bz"].flexString(),
            selectionMethod = obj["cxbmfs"].flexString(),
            maxCourses = obj["xkmc"].flexInt()
        )
    }
}
