package com.cczu.cczukit

import com.cczu.cczukit.models.RawCourse
import org.junit.Assert.assertEquals
import org.junit.Test

class CalendarParserTest {

    @Test
    fun parsesSingleCourse() {
        val matrix = listOf(
            listOf(
                RawCourse(course = "高等数学 1-16周 教学楼A101", teacher = "张三"),
                RawCourse(course = "", teacher = "")
            )
        )
        val parsed = CalendarParser.parseWeekMatrix(matrix)
        assertEquals(1, parsed.size)
        val course = parsed.first()
        assertEquals("高等数学", course.name)
        assertEquals("张三", course.teacher)
        assertEquals("教学楼A101", course.location)
        assertEquals((1..16).toList(), course.weeks)
        assertEquals(1, course.dayOfWeek)
        assertEquals(1, course.timeSlot)
    }

    @Test
    fun parsesMultiSegmentCourseWithMatchingTeachers() {
        val matrix = listOf(
            listOf(
                RawCourse(course = "", teacher = ""),
                RawCourse(course = "大学英语/体育 1-8周 操场", teacher = "李四,/王五")
            )
        )
        val parsed = CalendarParser.parseWeekMatrix(matrix)
        assertEquals(2, parsed.size)
        assertEquals("大学英语", parsed[0].name)
        assertEquals("体育", parsed[1].name)
        assertEquals("李四", parsed[0].teacher)
        assertEquals("王五", parsed[1].teacher)
        assertEquals(2, parsed[0].dayOfWeek)
    }

    @Test
    fun parsesOddAndEvenWeeks() {
        assertEquals(listOf(1, 3, 5, 7, 9), CalendarParser.parseWeeks("1-9 单"))
        assertEquals(listOf(2, 4, 6, 8), CalendarParser.parseWeeks("2-8 双"))
        assertEquals(listOf(2, 3, 4, 11, 12, 13, 14), CalendarParser.parseWeeks("2-4,11-14周"))
        assertEquals(emptyList<Int>(), CalendarParser.parseWeeks(""))
    }
}
