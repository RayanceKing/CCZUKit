package com.cczu.cczukit

/**
 * API 常量（与 Swift 版 CCZUKit 保持一致）
 */
public object CCZUConstants {
    /** 统一身份认证登录入口 */
    public const val rootSSOLogin: String = "http://sso.cczu.edu.cn/sso/login"
    /** WebVPN 根地址 */
    public const val rootVPNURL: String = "https://zmvpn.cczu.edu.cn"
    /** 教务企业微信应用根地址 */
    public const val wechatAppAPI: String = "http://jwqywx.cczu.edu.cn"

    public val defaultHeaders: Map<String, String> = mapOf(
        "User-Agent" to "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
        "Accept" to "application/json, text/plain, */*",
        "Accept-Language" to "zh-CN,zh;q=0.9,en;q=0.8"
    )

    public object Jwqywx {
        public const val origin: String = "http://jwqywx.cczu.edu.cn"
        public const val referer: String = "http://jwqywx.cczu.edu.cn/"
        public const val apiBase: String = "http://jwqywx.cczu.edu.cn/api"

        public const val authHeader: String = "Authorization"
        public const val bearerPrefix: String = "Bearer "

        public const val noTermFoundMessage: String = "No term found"
        public const val noBasicInfoMessage: String = "No basic info"
        public const val defaultExamType: String = "学分制考试"
        public const val defaultSelectionFunctionCode: String = "xkbm_fsxz"

        public const val cacheDirectoryName: String = "CCZUKit"
        public const val trainingPlanCachePrefix: String = "training_plan_"
        public const val trainingPlanCacheExtension: String = ".json"

        public const val loginURL: String = "$apiBase/login"
        public const val gradesURL: String = "$apiBase/cj_xh"
        public const val creditsAndRankURL: String = "$apiBase/cj_xh_xfjd"
        public const val termsURL: String = "$apiBase/xqall"
        public const val trainingPlanURL: String = "$apiBase/cj_xh_jxjh_cj"
        public const val studentBasicInfoURL: String = "$apiBase/xs_xh_jbxx"
        public const val classScheduleURL: String = "$apiBase/kb_xq_xh"
        public const val courseTeacherSupplementURL: String = "$apiBase/kbk_xq_xh"
        public const val examArrangementsURL: String = "$apiBase/ks_xs_kslb"
        public const val evaluatableClassesURL: String = "$apiBase/pj_xspj_kcxx"
        public const val submittedEvaluationsURL: String = "$apiBase/pj_xh_pjxx"
        public const val submitTeacherEvaluationURL: String = "$apiBase/pj_insert_xspj"

        public const val checkSelectionPermissionURL: String = "$apiBase/qx_yhdm_gnmk_syqx"
        public const val selectionBatchesURL: String = "$apiBase/xk_xkxm_nj"
        public const val batchPermissionURL: String = "$apiBase/xkqx_dm_nj"
        public const val selectableCoursesURL: String = "$apiBase/xk_xh_kbk"
        public const val selectCoursesURL: String = "$apiBase/xk_insert_xfz"
        public const val dropCoursesURL: String = "$apiBase/xk_delete_xfzxkmd"

        public const val generalElectiveCoursesURL: String = "$apiBase/yxk_xk_xh_kxkc_gx"
        public const val generalElectiveActualCountsURL: String = "$apiBase/yxk_xk_xkrs_gx"
        public const val selectedGeneralElectiveCoursesURL: String = "$apiBase/yxk_xk_xh_yxkc_gx"
        public const val checkGeneralElectivePermissionURL: String = "$apiBase/yxk_xkqx_dm_nj"
        public const val selectGeneralElectiveCoursesURL: String = "$apiBase/yxk_xk_insert_ggxx"
        public const val dropGeneralElectiveCourseURL: String = "$apiBase/yxk_xk_delete_ggxx"
    }

    public object SSO {
        public const val loginURL: String = CCZUConstants.rootSSOLogin

        public fun serviceLoginURL(service: String): String =
            if (service.isEmpty()) loginURL else "$loginURL?service=$service"
    }

    public object Electricity {
        public const val account: String = "1"
        public const val queryBuildingURL: String =
            "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecBuilding.html"
        public const val queryRoomURL: String =
            "http://wxxy.cczu.edu.cn/wechat/callinterface/queryElecRoomInfo.html"

        public const val buildingUserAgent: String =
            "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340157 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"
        public const val roomUserAgent: String =
            "Mozilla/5.0 (Linux; Android 15; V2232A Build/AP3A.240905.015.A2; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/134.0.6998.136 Mobile Safari/537.36 XWEB/1340125 MMWEBSDK/20250201 MMWEBID/140 wxwork/4.1.38 MicroMessenger/7.0.1 NetType/WIFI Language/zh Lang/zh ColorScheme/Light wwmver/3.26.38.639"

        public data class PredefinedArea(
            val area: String,
            val areaname: String,
            val aid: String
        )

        public val predefinedAreas: List<PredefinedArea> = listOf(
            PredefinedArea("西太湖校区", "西太湖校区", "0030000000002501"),
            PredefinedArea("武进校区", "武进校区", "0030000000002502"),
            PredefinedArea("西太湖校区1-7,10-11", "西太湖校区1-7,10-11", "0030000000002503")
        )
    }
}
