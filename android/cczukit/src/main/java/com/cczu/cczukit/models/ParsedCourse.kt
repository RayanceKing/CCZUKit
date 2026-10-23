package com.cczu.cczukit.models

/** 课程信息（已解析） */
public data class ParsedCourse(
    val name: String,
    val teacher: String,
    val location: String,
    val weeks: List<Int>,
    val dayOfWeek: Int,
    val timeSlot: Int
)
