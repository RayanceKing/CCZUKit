package com.cczu.cczukit

import com.cczu.cczukit.models.ParsedCourse
import com.cczu.cczukit.models.RawCourse

/** 课表矩阵解析器（对应 Swift 版 CalendarParser） */
public object CalendarParser {

    private val weekPattern = Regex("""^[\d,-]+[,，]?$""")
    private val nonRangePattern = Regex("""[^0-9\-,]""")

    /**
     * 解析周课表矩阵
     * @param matrix 课表原始数据，外层为时间节次，内层为星期
     */
    @JvmStatic
    public fun parseWeekMatrix(matrix: List<List<RawCourse>>): List<ParsedCourse> {
        val courses = ArrayList<ParsedCourse>()

        for ((timeIndex, timeCourses) in matrix.withIndex()) {
            for ((dayIndex, rawCourse) in timeCourses.withIndex()) {
                if (rawCourse.course.isEmpty()) continue

                // 格式示例: "高等数学 1-16周 教学楼A101"
                val courseParts = rawCourse.course.split("/")
                val teacherParts = rawCourse.teacher.split(",/")

                for ((index, part) in courseParts.withIndex()) {
                    val trimmed = part.trim()
                    if (trimmed.isEmpty()) continue

                    val components = trimmed.split(" ").filter { it.isNotEmpty() }
                    if (components.isEmpty()) continue

                    val name = components[0]
                    val locationParts = ArrayList<String>()
                    val weekComponents = ArrayList<String>()

                    for (component in components.drop(1)) {
                        val compTrimmed = component.trim()
                        if (compTrimmed.isEmpty()) continue

                        // 周次相关：含“周”、单/双、或纯数字 + 连字符/逗号
                        if (compTrimmed.contains("周") ||
                            compTrimmed == "单" || compTrimmed == "双" ||
                            weekPattern.containsMatchIn(compTrimmed)
                        ) {
                            weekComponents.add(compTrimmed)
                            continue
                        }

                        val cleaned = compTrimmed.trim(',', '，', ';', ':', '。')
                        if (cleaned.isNotEmpty()) locationParts.add(cleaned)
                    }

                    val weeks = if (weekComponents.isNotEmpty()) {
                        parseWeeks(weekComponents.joinToString(" "))
                    } else {
                        emptyList()
                    }
                    val location = locationParts.joinToString(" ")

                    // 按分段索引提取教师；不存在则留空，避免错误复用第一段教师
                    val teacherSource = teacherParts.getOrElse(index) { "" }
                    val teacher = teacherSource.trim().trim(',', '，')

                    courses.add(
                        ParsedCourse(
                            name = name,
                            teacher = teacher,
                            location = location,
                            weeks = weeks,
                            dayOfWeek = dayIndex + 1,
                            timeSlot = timeIndex + 1
                        )
                    )
                }
            }
        }

        return courses
    }

    /** 解析周次字符串，如 "1-16周"、"2-8,11-14 单" */
    @JvmStatic
    public fun parseWeeks(weekString: String): List<Int> {
        val weeks = ArrayList<Int>()

        var cleaned = weekString.replace("周", "").trim()
        cleaned = cleaned.trim(',', '，', ';', ':', '。')

        val isOdd = cleaned.contains("单")
        val isEven = cleaned.contains("双")
        cleaned = cleaned.replace("单", "").replace("双", "").trim()

        val rangeStr = nonRangePattern.replace(cleaned, "")
        if (rangeStr.isEmpty()) return emptyList()

        for (segment in rangeStr.split(",")) {
            if (segment.contains("-")) {
                val parts = segment.split("-").mapNotNull { it.trim().toIntOrNull() }
                if (parts.size == 2) {
                    val start = parts[0]
                    val end = parts[1]
                    for (week in start..end) {
                        appendWeek(weeks, week, isOdd, isEven)
                    }
                }
            } else {
                val week = segment.trim().toIntOrNull()
                if (week != null) appendWeek(weeks, week, isOdd, isEven)
            }
        }

        return weeks.sorted()
    }

    private fun appendWeek(weeks: MutableList<Int>, week: Int, isOdd: Boolean, isEven: Boolean) {
        val keep = when {
            isOdd -> week % 2 == 1
            isEven -> week % 2 == 0
            else -> true
        }
        if (keep && !weeks.contains(week)) weeks.add(week)
    }
}
