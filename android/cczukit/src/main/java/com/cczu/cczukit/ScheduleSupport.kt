package com.cczu.cczukit

import com.cczu.cczukit.models.RawCourse
import com.google.gson.JsonElement
import com.google.gson.JsonObject

/** 课表行数据（一行 = 一个时间节的 7 天） */
internal class CourseScheduleRow(private val fields: Map<String, JsonElement>) {

    companion object {
        fun from(obj: JsonObject): CourseScheduleRow {
            val fields = LinkedHashMap<String, JsonElement>()
            for ((key, value) in obj.entrySet()) fields[key] = value
            return CourseScheduleRow(fields)
        }
    }

    fun toCourses(fallbackTeachersByCourseName: Map<String, String> = emptyMap()): List<RawCourse> {
        // 提取课程信息 (kc1-kc7)
        val courses = ArrayList<String>(7)
        for (index in 1..7) {
            courses.add(fields["kc$index"].strictStringOrNull() ?: "")
        }

        // 提取教师信息 (kcmc1-kcmc20 与 skjs1-skjs20)
        val teachers = LinkedHashMap<String, String>()
        for (index in 1..20) {
            val name = fields["kcmc$index"].strictStringOrNull()
            val teacher = fields["skjs$index"].strictStringOrNull()
            if (name != null && teacher != null) teachers[name] = teacher
        }

        return courses.map { course ->
            val courseParts = course.split("/")
            val teacherParts = courseParts.map { part ->
                val partText = part.trim()
                val matchedName = matchedCourseName(partText, teachers.keys)
                if (matchedName != null) {
                    teachers[matchedName]?.takeIf { it.isNotEmpty() }?.let { return@map it }
                    fallbackTeachersByCourseName[matchedName]?.takeIf { it.isNotEmpty() }
                        ?.let { return@map it }
                }
                val normalizedPartText = normalizedCourseName(partText)
                val matchedNormalizedName =
                    matchedCourseName(normalizedPartText, fallbackTeachersByCourseName.keys)
                if (matchedNormalizedName != null) {
                    return@map fallbackTeachersByCourseName[matchedNormalizedName] ?: ""
                }
                ""
            }

            // 保留空占位，确保与课程分段索引对齐，避免后续解析时教师错位
            RawCourse(course = course, teacher = teacherParts.joinToString(",/"))
        }
    }

    private fun normalizedCourseName(name: String): String =
        name.trim().replace("（", "(").replace("）", ")")

    private fun matchedCourseName(part: String, names: Set<String>): String? {
        val normalizedPart = normalizedCourseName(part)
        return names.filter { it.trim().isNotEmpty() }
            .sortedByDescending { it.length }
            .firstOrNull { candidate -> normalizedPart.startsWith(normalizedCourseName(candidate)) }
    }
}

/** 授课教师补充项（kbk_xq_xh） */
internal data class CourseTeacherSupplementItem(
    val courseName: String,
    val teacherName: String
) {
    companion object {
        fun from(obj: JsonObject): CourseTeacherSupplementItem = CourseTeacherSupplementItem(
            courseName = obj["kcmc"].flexString(),
            teacherName = obj["jsmc"].flexString()
        )
    }
}
