package com.cczu.cczukit.models

import com.cczu.cczukit.CCZUError
import com.cczu.cczukit.arr
import com.cczu.cczukit.flexDouble
import com.cczu.cczukit.flexDoubleOrNull
import com.cczu.cczukit.flexInt
import com.cczu.cczukit.flexIntOrNull
import com.cczu.cczukit.flexString
import com.cczu.cczukit.flexStringOrNull
import com.cczu.cczukit.parseJsonElement
import com.google.gson.JsonArray
import com.google.gson.JsonObject

/** 培养方案课程条目（接口原始字段） */
public data class RawTrainingPlanItem(
    val nj: Int?,         // 年级
    val zydm: String?,    // 专业代码
    val xz: String?,      // 学制
    val xq: Int,          // 学期
    val kcdm: String,     // 课程代码
    val kcmc: String,     // 课程名称
    val lbdh: String,     // 类别代号 A1/B1/B2/C1/C3/S
    val xf: Double,       // 学分
    val lbmc: String,     // 类别名称
    val xh: String?,      // 学号
    val kscj: Double?,    // 成绩
    val lb: String?,      // 类别（必修/专业任选/实践环节）
    val zymc: String?     // 专业名称
)

/** 课程类型归类 */
public enum class PlanCourseType {
    /** 必修（A1/B1/C1） */
    required,

    /** 选修（C3 及其他任选） */
    elective,

    /** 实践（S） */
    practice;

    internal companion object {
        fun fromCategory(raw: String): PlanCourseType = when (raw.trim()) {
            "A1", "B1", "C1" -> required
            else -> if (raw.trim().uppercase().startsWith("S")) practice else elective
        }

        fun fromName(name: String): PlanCourseType = runCatching { valueOf(name) }.getOrNull() ?: elective
    }
}

/** 计划课程 */
public data class PlanCourse(
    val id: String,
    val name: String,
    val code: String,
    val credits: Double,
    val type: PlanCourseType,
    val teacher: String?
) {
    internal fun toJson(): JsonObject = JsonObject().apply {
        addProperty("id", id)
        addProperty("name", name)
        addProperty("code", code)
        addProperty("credits", credits)
        addProperty("type", type.name)
        teacher?.let { addProperty("teacher", it) }
    }

    internal companion object {
        fun fromJson(obj: JsonObject): PlanCourse = PlanCourse(
            id = obj["id"].flexString(),
            name = obj["name"].flexString(),
            code = obj["code"].flexString(),
            credits = obj["credits"].flexDouble(),
            type = PlanCourseType.fromName(obj["type"].flexString()),
            teacher = obj["teacher"].flexStringOrNull()
        )
    }
}

/** 培养方案聚合模型 */
public data class TrainingPlan(
    val majorName: String,
    val degree: String,
    val durationYears: Int,
    val totalCredits: Double,
    val requiredCredits: Double,
    val electiveCredits: Double,
    val practiceCredits: Double,
    val objectives: String?,
    val coursesBySemester: Map<Int, List<PlanCourse>>
) {
    /** 磁盘缓存用序列化 */
    public fun toJson(): JsonObject = JsonObject().apply {
        addProperty("majorName", majorName)
        addProperty("degree", degree)
        addProperty("durationYears", durationYears)
        addProperty("totalCredits", totalCredits)
        addProperty("requiredCredits", requiredCredits)
        addProperty("electiveCredits", electiveCredits)
        addProperty("practiceCredits", practiceCredits)
        objectives?.let { addProperty("objectives", it) }
        val semesters = JsonObject()
        for ((semester, courses) in coursesBySemester) {
            val array = JsonArray()
            courses.forEach { array.add(it.toJson()) }
            semesters.add(semester.toString(), array)
        }
        add("coursesBySemester", semesters)
    }

    public companion object {
        @JvmStatic
        public fun fromJson(obj: JsonObject): TrainingPlan {
            val semesters = LinkedHashMap<Int, List<PlanCourse>>()
            obj.objOrNull("coursesBySemester")?.entrySet()?.forEach { (key, value) ->
                val semester = key.toIntOrNull() ?: return@forEach
                val array = value.takeIf { it.isJsonArray }?.asJsonArray ?: return@forEach
                val courses = ArrayList<PlanCourse>(array.size())
                array.forEach { el ->
                    if (el.isJsonObject) courses.add(PlanCourse.fromJson(el.asJsonObject))
                }
                semesters[semester] = courses
            }
            return TrainingPlan(
                majorName = obj["majorName"].flexString(),
                degree = obj["degree"].flexString(),
                durationYears = obj["durationYears"].flexInt(),
                totalCredits = obj["totalCredits"].flexDouble(),
                requiredCredits = obj["requiredCredits"].flexDouble(),
                electiveCredits = obj["electiveCredits"].flexDouble(),
                practiceCredits = obj["practiceCredits"].flexDouble(),
                objectives = obj["objectives"].flexStringOrNull(),
                coursesBySemester = semesters
            )
        }
    }
}

private fun JsonObject.objOrNull(name: String): JsonObject? =
    get(name)?.takeIf { it.isJsonObject }?.asJsonObject

/** 培养方案解析器（对应 Swift 版 TrainingPlanParser） */
public object TrainingPlanParser {

    @JvmStatic
    public fun parse(text: String, basicInfo: StudentBasicInfo? = null): TrainingPlan {
        val root = parseJsonElement(text)
            ?: throw CCZUError.Unknown("Unexpected training plan response format")

        // 1) message 为字符串的错误响应
        if (root is JsonObject) {
            val status = root["status"]?.flexIntOrNull()
            val messageString = root["message"]?.takeIf { !it.isJsonArray }?.flexStringOrNull()
            if (status != null && status != 0 && messageString != null) {
                throw CCZUError.Unknown(messageString)
            }
            root.arr("message")?.let { return aggregate(parseItems(it), basicInfo) }
        }

        // 2) 顶层为数组
        if (root is JsonArray) {
            return aggregate(parseItems(root), basicInfo)
        }

        throw CCZUError.Unknown("Unexpected training plan response format")
    }

    private fun parseItems(array: JsonArray): List<RawTrainingPlanItem> {
        val items = ArrayList<RawTrainingPlanItem>(array.size())
        for (element in array) {
            val e = element.takeIf { it.isJsonObject }?.asJsonObject ?: continue
            items.add(
                RawTrainingPlanItem(
                    nj = e["nj"].flexIntOrNull(),
                    zydm = e["zydm"].flexStringOrNull(),
                    xz = e["xz"].flexStringOrNull(),
                    xq = e["xq"].flexIntOrNull() ?: e["xq"].flexStringOrNull()?.toIntOrNull() ?: 0,
                    kcdm = e["kcdm"].flexString(),
                    kcmc = e["kcmc"].flexString(),
                    lbdh = e["lbdh"].flexStringOrNull()?.takeIf { it.isNotEmpty() }
                        ?: e["lb"].flexString(),
                    xf = e["xf"].flexDoubleOrNull()
                        ?: e["xf"].flexStringOrNull()?.toDoubleOrNull() ?: 0.0,
                    lbmc = e["lbmc"].flexStringOrNull()?.takeIf { it.isNotEmpty() }
                        ?: e["lb"].flexString(),
                    xh = e["xh"].flexStringOrNull(),
                    kscj = e["kscj"].flexDoubleOrNull(),
                    lb = e["lb"].flexStringOrNull(),
                    zymc = e["zymc"].flexStringOrNull()
                )
            )
        }
        return items
    }

    private fun aggregate(
        items: List<RawTrainingPlanItem>,
        basicInfo: StudentBasicInfo?
    ): TrainingPlan {
        val majorName = basicInfo?.major?.trim()
            ?.takeIf { it.isNotEmpty() }
            ?: items.firstOrNull()?.zymc?.trim()
            ?: ""
        val durationYears = (basicInfo?.studyLength ?: items.firstOrNull()?.xz ?: "0")
            .trim().toIntOrNull() ?: 0

        val coursesBySemester = LinkedHashMap<Int, MutableList<PlanCourse>>()
        var requiredCredits = 0.0
        var electiveCredits = 0.0
        var practiceCredits = 0.0
        var totalCredits = 0.0

        for (item in items) {
            val credits = item.xf
            totalCredits += credits
            val type = PlanCourseType.fromCategory(item.lbdh)
            when (type) {
                PlanCourseType.required -> requiredCredits += credits
                PlanCourseType.practice -> practiceCredits += credits
                PlanCourseType.elective -> electiveCredits += credits
            }
            val course = PlanCourse(
                id = item.kcdm,
                name = item.kcmc.trim(),
                code = item.kcdm,
                credits = credits,
                type = type,
                teacher = null
            )
            coursesBySemester.getOrPut(item.xq) { ArrayList() }.add(course)
        }

        return TrainingPlan(
            majorName = majorName,
            degree = "",
            durationYears = durationYears,
            totalCredits = totalCredits,
            requiredCredits = requiredCredits,
            electiveCredits = electiveCredits,
            practiceCredits = practiceCredits,
            objectives = null,
            coursesBySemester = coursesBySemester
        )
    }
}
