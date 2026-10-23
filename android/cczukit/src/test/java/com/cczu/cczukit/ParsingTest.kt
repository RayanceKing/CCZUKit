package com.cczu.cczukit

import com.cczu.cczukit.models.CourseGrade
import com.cczu.cczukit.models.Term
import com.cczu.cczukit.models.TrainingPlanParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ParsingTest {

    @Test
    fun rejectsNonZeroStatus() {
        val json = """{"status":9,"message":"操作失败","token":null}"""
        val thrown = runCatching { parseMessageFromJson(json) { Term.fromJson(it) } }.exceptionOrNull()
        assertTrue(thrown is TeachingResponseError.Rejected)
        assertEquals(9, (thrown as TeachingResponseError.Rejected).status)
    }

    @Test
    fun parsesTermList() {
        val json = """{"status":0,"message":[{"xq":"25-26-1"},{"xq":"25-26-2"}],"token":"abc"}"""
        val message = parseMessageFromJson(json) { Term.fromJson(it) }
        assertEquals(2, message.message.size)
        assertEquals("25-26-1", message.message.first().term)
        assertEquals("abc", message.token)
    }

    @Test
    fun toleratesNumericStrings() {
        val json = """
            {"status":0,"message":[{
                "bh":"01","bj":"软件251","xh":"2400130204","xm":"张三",
                "kcdm":"A101","kcmc":"高等数学","xq":"2025","kclb":"B","lbmc":"必修",
                "xs":"64","xf":"4.0","jsmc":"李四","ksxzm":"1","ksxz":"考试",
                "kscj":"90","idn":"12","cj":"90","xfjd":"4.0"
            }]}
        """.trimIndent()
        val grade = parseMessageFromJson(json) { CourseGrade.fromJson(it) }.message.first()
        assertEquals(2025, grade.term)
        assertEquals(64, grade.courseHours)
        assertEquals(4.0, grade.courseCredits, 0.001)
        assertEquals(90.0, grade.grade, 0.001)
        assertEquals(12, grade.ident)
    }

    @Test
    fun parsesTrainingPlan() {
        val json = """
            {"status":0,"message":[
                {"nj":2025,"xq":1,"kcdm":"A1","kcmc":"高等数学","lbdh":"A1","xf":5,"lbmc":"必修"},
                {"nj":2025,"xq":1,"kcdm":"S1","kcmc":"军训","lbdh":"S","xf":2,"lbmc":"实践"},
                {"nj":2025,"xq":2,"kcdm":"C3","kcmc":"选修课","lbdh":"C3","xf":3,"lbmc":"任选"}
            ]}
        """.trimIndent()
        val plan = TrainingPlanParser.parse(json)
        assertEquals(10.0, plan.totalCredits, 0.001)
        assertEquals(5.0, plan.requiredCredits, 0.001)
        assertEquals(2.0, plan.practiceCredits, 0.001)
        assertEquals(3.0, plan.electiveCredits, 0.001)
        assertEquals(2, plan.coursesBySemester[1]?.size)
        assertEquals(1, plan.coursesBySemester[2]?.size)
    }
}
