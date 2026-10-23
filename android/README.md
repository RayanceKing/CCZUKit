# CCZUKit Android（Kotlin 版）

Swift 版 `CCZUKit` 的 Android 移植：一个独立的 Android Library（`:cczukit`，产物 AAR），
使用 **OkHttp + kotlinx.coroutines + Gson**，API 全部为 `suspend` 函数。

## 目录结构

```
android/
├── settings.gradle.kts
├── build.gradle.kts                 # AGP 8.7.3 / Kotlin 2.0.21
├── gradle/wrapper/                  # Gradle 8.9
└── cczukit/
    ├── build.gradle.kts             # minSdk 26 / compileSdk 35
    ├── consumer-rules.pro
    └── src/main/java/com/cczu/cczukit/
        ├── CCZUConstants.kt         # 端点与默认请求头
        ├── CCZUError.kt             # 统一错误类型
        ├── TeachingResponseValidator.kt
        ├── HttpClient.kt            # OkHttp 封装 + CookieJar
        ├── JwqywxApplication.kt     # 教务应用主类
        ├── Auth.kt                  # 登录 / 成绩 / 绩点 / 学期
        ├── Academic.kt              # 课表 / 考试 / 评价
        ├── ScheduleSupport.kt       # 课表行解析
        ├── Selection.kt             # 选课 / 退课
        ├── GeneralElective.kt       # 通识选修
        ├── Electricity.kt           # 电费查询
        ├── TrainingPlanService.kt   # 培养方案（含磁盘缓存）
        ├── SSOLogin.kt              # SSO / WebVPN 登录
        ├── CalendarParser.kt        # 课表矩阵解析
        ├── Json.kt / Message.kt     # 宽容 JSON 解析
        └── models/                  # 数据模型
```

## 集成

方式一（推荐）：Android Studio → `Settings.gradle.kts` 所在目录作为独立工程打开，或
把 `android/` 作为子工程 include 进你的项目：

```kotlin
// settings.gradle.kts
include(":cczukit")
project(":cczukit").projectDir = file("../CCZUKit/android/cczukit")
```

```kotlin
// app/build.gradle.kts
dependencies { implementation(project(":cczukit")) }
```

方式二：本地发布 AAR

```bash
cd android
./gradlew :cczukit:assembleRelease   # 产物 cczukit/build/outputs/aar/cczukit-release.aar
./gradlew :cczukit:test              # 本地单元测试
```

> 库清单已声明 `android:usesCleartextTraffic="true"` 与 `INTERNET` 权限
> （教务 / WebVPN / 电费接口均为 http），manifest merger 会自动合并进宿主 App。

## 使用

```kotlin
import com.cczu.cczukit.*
import com.cczu.cczukit.models.*
import kotlinx.coroutines.launch

val client = DefaultHttpClient(username = "2400130204", password = "******")
val app = JwqywxApplication(client)          // 可选第二参数 cacheDir: File

viewModelScope.launch {
    // 1) SSO（可选，WebVPN 场景）
    val loginInfo = client.ssoUniversalLogin()

    // 2) 教务登录
    app.login()

    // 3) 成绩 / 绩点
    val grades = app.getGrades()
    val points = app.getCreditsAndRank()

    // 4) 课表（原始矩阵 -> 解析后的课程）
    val matrix = app.getCurrentClassSchedule()
    val courses = CalendarParser.parseWeekMatrix(matrix)

    // 5) 考试 / 评价
    val exams = app.getCurrentExamArrangements()
    val evaluatable = app.getCurrentEvaluatableClasses()

    // 6) 培养方案（内存 + 磁盘缓存，缓存目录默认 java.io.tmpdir/CCZUKit）
    val plan = app.getTrainingPlan()

    // 7) 电费
    val areas = app.getElectricityAreas()
    val buildings = app.getBuildings(areas.first())
    val electricity = app.queryElectricity(areas.first(), buildings.first(), roomId = "101")

    // 8) 选课
    val selectable = app.getCurrentSelectableCourses()
    app.selectCourses(term = app.getCurrentTerm(), items = selectable)
    app.dropCourses(selectedIds = listOf(1234))
}
```

错误处理：

```kotlin
try { app.login() } catch (e: CCZUError.InvalidCredentials) { /* 账号或密码错误 */ }
catch (e: TeachingResponseError.AuthenticationExpired) { /* 登录失效，重新登录 */ }
```

## 与 Swift 版的对应关系

| Swift | Kotlin |
|---|---|
| `DefaultHTTPClient` (URLSession) | `DefaultHttpClient`（OkHttp） |
| `HTTPClient` protocol | `HttpClient` interface |
| `PropertyStorage` (actor) | `PropertyStorage`（synchronized） |
| `JwqywxApplication` (@MainActor) | `JwqywxApplication`（Mutex + CoroutineScope，全 suspend） |
| `Message<T: Decodable>` | `Message<T>` + `parseMessageFromJson` |
| `CCZUError` enum | `CCZUError` sealed class |
| `TeachingResponseError` enum | `TeachingResponseError` sealed class |
| `CalendarParser.parseWeekMatrix` | `CalendarParser.parseWeekMatrix` |
| `TrainingPlanParser.parse` | `TrainingPlanParser.parse` |
| `URLSessionConfiguration` 20s/30s | OkHttp connect/read 20s、call 30s |
| `HTTPCookieStorage.shared` | `CCZUCookieJar`（内存，可读取 clientInfo） |

## 行为差异（有意为之）

1. **重定向**：关闭了 OkHttp 自动跟随重定向（`followRedirects=false`），
   这样 SSO 登录才能像 Swift 版一样读到 302 的 `Location`。
2. **表单编码**：`postForm` 由 OkHttp 做标准 urlencode，比 Swift 的手工转义更规范。
3. **并发模型**：Swift 用 `@MainActor` + `Task`；Kotlin 用不可变快照 headers + `Volatile`
   状态 + `Mutex` 保护登录去重，调用方无需切到主线程。
4. **JSON 解析**：教务接口字段类型不稳定（数字可能是字符串、字段可能缺失），
   因此没有用 Gson 反射，而是统一的“宽容解析”helper（`flexInt/flexDouble/flexString...`），
   与 Swift 版 `decodeIfPresent + trimming` 的容错效果一致。
5. **培养方案缓存目录**：Swift 用系统 Caches 目录；Kotlin 默认 `java.io.tmpdir/CCZUKit`，
   建议传入 `context.cacheDir` 下的目录：
   `JwqywxApplication(client, cacheDir = File(context.cacheDir, "CCZUKit"))`。
6. **minSdk 26**：使用了 `java.time`（Instant/OffsetDateTime）解析选课批次时间窗。

## 单元测试

`./gradlew :cczukit:test` 覆盖课表矩阵解析、周次解析、Message 状态校验、
宽容数字解析、培养方案聚合。
