# CCZUKit 项目结构

## 文件结构

```
CCZUKit/
├── Package.swift              # Swift Package 配置文件
├── README.md                  # 项目说明文档
├── QUICKSTART.md             # 快速开始指南
├── LICENSE                    # MIT 许可证
├── .gitignore                # Git 忽略文件
│
├── Sources/CCZUKit/          # 主要源代码目录
│   ├── CCZUKit.swift         # 库入口和版本信息
│   │
│   ├── Core/                 # 核心功能模块
│   │   ├── Constants.swift   # API常量和配置
│   │   └── HTTPClient.swift  # HTTP客户端实现
│   │
│   ├── Models/               # 数据模型
│   │   ├── Account.swift     # 账号模型
│   │   ├── CCZUError.swift   # 错误类型定义
│   │   ├── Property.swift    # 属性类型
│   │   └── JwqywxModels.swift # 教务微信数据模型
│   │
│   ├── Services/             # 服务实现
│   │   ├── Application.swift # JwqywxApplication 主类定义
│   │   ├── SSOLogin.swift    # SSO统一登录服务
│   │   ├── Auth.swift        # 身份验证和授权
│   │   ├── Academic.swift    # 成绩、绩点、评价等学术功能
│   │   ├── ScheduleSupport.swift # 课表支持功能
│   │   ├── Selection.swift   # 课程选修功能
│   │   ├── GeneralElective.swift # 通识选修课程
│   │   ├── Electricity.swift # 电费查询功能
│   │   └── TrainingPlanService.swift # 培养方案查询
│   │
│   └── Utils/                # 工具类
│       └── CalendarParser.swift # 课表解析工具
│
├── Tests/CCZUKitTests/       # 测试代码
│   └── CCZUKitTests.swift    # 单元测试
│
└── Examples/                 # 示例代码
    └── Example.swift         # 使用示例
```

## 模块说明

### Core - 核心模块

#### Constants.swift
- 定义所有API端点URL
- 默认HTTP请求头
- 全局配置常量

#### HTTPClient.swift
- `HTTPClient` 协议: 定义HTTP客户端接口
- `DefaultHTTPClient`: 默认HTTP客户端实现
- `PropertyStorage`: 线程安全的属性存储(使用Actor)
- 提供GET、POST、POST JSON、POST Form等便捷方法

### Models - 数据模型

#### Account.swift
- `Account`: 账号信息结构体
- 包含用户名和密码

#### CCZUError.swift
- `CCZUError`: 统一错误类型枚举
- 支持的错误类型:
  - networkError: 网络错误
  - invalidResponse: 无效响应
  - loginFailed: 登录失败
  - notLoggedIn: 未登录
  - decodingError: 数据解析错误
  - missingData: 缺少数据
  - unknown: 未知错误

#### Property.swift
- `Property`: 动态属性类型
- 支持 String、Int、Bool 类型

#### JwqywxModels.swift
包含教务企业微信相关的所有数据模型:
- `Message<T>`: 通用响应消息
- `LoginUserData`: 登录用户数据
- `CourseGrade`: 课程成绩
- `StudentPoint`: 学生绩点信息
- `Term`: 学期信息
- `RawCourse`: 原始课程信息
- `ParsedCourse`: 解析后的课程信息
- `ElinkLoginInfo`: Elink登录信息

### Services - 服务模块


#### Application.swift
中心应用类定义:
- `JwqywxApplication`: 教务企业微信应用主类
- 统一的登录接口
- Token管理和会话保持
- 自动请求头配置

#### Auth.swift
身份验证和授权:
- SSO集成登录
- 教务系统登录
- Token获取和刷新
- 权限检查接口

#### Academic.swift
学术信息查询:
- 成绩查询（单学期/全部）
- 学分绩点查询
- 学期列表获取
- 考试安排查询
- 学生基本信息
- 可评价课程列表
- 已提交评价信息
- 提交教师评价

#### ScheduleSupport.swift
课表相关功能:
- 指定学期课表查询
- 当前学期课表查询
- 课表矩阵解析
- 课程信息补充

#### Selection.swift
课程选修功能:
- 获取可选课程
- 批量选课（支持分片和重试）
- 批量退课
- 选课权限检查
- 选课批次查询

#### GeneralElective.swift
通识选修课程（抢课）:
- 获取通识课程列表
- 获取已选课程
- 批量选课（每次最多2门）
- 退课
- 权限检查

#### Electricity.swift
电费查询功能:
- 获取校区列表
- 获取建筑物列表
- 实时电费查询

#### TrainingPlanService.swift
培养方案相关:
- 获取培养方案
- 课程缓存管理

### Utils - 工具模块

#### CalendarParser.swift
课表解析工具:
- `CalendarParser`: 静态解析器
- `parseWeekMatrix`: 解析周课表矩阵
- 支持解析:
  - 课程名称
  - 教师姓名
  - 上课地点
  - 周次(支持单周/双周)
  - 星期
  - 时间节次

## 关键特性

### 1. 类型安全
- 所有数据模型都是强类型
- 使用 Swift 的 Codable 协议进行序列化
- 完整的错误类型系统

### 2. 并发支持
- 基于 Swift Concurrency (async/await)
- 使用 Actor 确保线程安全
- 所有类型都符合 Sendable 协议

### 3. 跨平台
- 支持 iOS 13.0+
- 支持 macOS 10.15+
- 支持 watchOS 6.0+
- 支持 tvOS 13.0+

### 4. 可扩展性
- 协议导向设计
- 易于添加新的服务
- 清晰的模块划分

## 依赖关系

```
CCZUKit (无外部依赖)
├── Foundation (Apple SDK)
└── XCTest (测试框架)
```

## 测试覆盖

测试包括:
- ✓ 账号创建测试
- ✓ 属性类型测试
- ✓ HTTP客户端测试
- ✓ 日历解析测试
- ✓ 错误处理测试
- ✓ 数据模型测试

## 与 Rust 版本的对应关系

| Rust 模块 | Swift 模块 |
|-----------|-----------|
| `src/base/client.rs` | `Core/HTTPClient.swift` |
| `src/base/typing.rs` | `Models/CCZUError.swift` |
| `src/impls/client.rs` | `Core/HTTPClient.swift` |
| `src/impls/login/sso.rs` | `Services/SSOLogin.swift` |
| `src/impls/apps/wechat/jwqywx.rs` | `Services/Application.swift`（+ 功能模块） |
| `src/impls/apps/wechat/grades.rs` | `Services/Academic.swift` |
| `src/impls/apps/wechat/schedule.rs` | `Services/ScheduleSupport.swift` |
| `src/impls/apps/wechat/selection.rs` | `Services/Selection.swift` |
| `src/impls/apps/wechat/electricity.rs` | `Services/Electricity.swift` |
| `src/extension/calendar.rs` | `Utils/CalendarParser.swift` |
| `src/internals/fields.rs` | `Core/Constants.swift` |

## 开发指南

### 添加新服务
1. 在 `Services/` 目录创建新文件
2. 定义服务协议
3. 为 `DefaultHTTPClient` 添加扩展实现
4. 在 `Models/` 添加相关数据模型
5. 编写单元测试

### 添加新的数据模型
1. 在 `Models/` 目录添加新模型
2. 遵循 `Decodable`、`Sendable` 协议
3. 使用 `CodingKeys` 映射JSON字段
4. 添加便捷初始化方法

### 运行测试
```bash
swift test
```

### 构建发布版本
```bash
swift build -c release
```

## 性能优化

1. **Cookie管理**: 使用系统 HTTPCookieStorage
2. **并发控制**: 使用 Actor 避免数据竞争
3. **内存管理**: 自动引用计数(ARC)
4. **网络请求**: 复用 URLSession

## 安全考虑

1. 密码使用 Base64 编码传输(与服务器API一致)
2. 支持 HTTPS
3. Cookie 自动管理
4. 建议使用 Keychain 存储敏感信息

## 未来计划

- [ ] 添加更多服务支持(如图书馆、一卡通等)
- [ ] 支持缓存机制
- [ ] 添加请求重试逻辑
- [ ] 提供更多日历解析选项
- [ ] 支持 Combine 框架
- [ ] 完善文档和示例
