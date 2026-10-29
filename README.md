# 智行城墙 · 基于 HarmonyOS 的片区信号配时优化与交通态势可视化系统

以 **西安城墙内片区** 为例的本科毕业设计项目。面向 11.3 km² 的古城核心区，构建「**感知 → 优化 → 评价 → 服务**」的交通信号配时闭环：后端以 Webster 模型按实时流量重算配时方案，鸿蒙端将优化过程与结果可视化，并把算法结论翻译成用户能理解的信息（如「该方向还需等待 26 秒」）。

![platform](https://img.shields.io/badge/platform-HarmonyOS-0F6FFF)
![lang](https://img.shields.io/badge/language-ArkTS-3178C6)
![sdk](https://img.shields.io/badge/API-20%2B-00C48C)
![status](https://img.shields.io/badge/status-in%20development-orange)

---

## 项目背景

城市信号交叉口普遍采用**固定配时**，无法适应潮汐车流，导致高峰时段空放与溢流并存。西安城墙内是规整的方格路网，四条大街交汇于钟楼，是研究信号协调控制的典型场景。

本项目不做「导航」，而是聚焦 **ATMS（交通管理）+ ATIS（出行者信息）** 交叉领域：

| 层次 | 做什么 |
| --- | --- |
| 感知 | 采集 15 个路口 × 4 进口道的流量、排队、延误，计算饱和度并分级 |
| 优化 | 按 Webster 最优周期模型重算周期与绿信比，输出四相位配时方案 |
| 评价 | 用 Webster 延误模型对比优化前后的延误、排队、通行量、停车次数 |
| 服务 | 将配时结果翻译为「预计等待 N 秒」，并对拥堵进口道给出诊断建议 |

---

## 核心特性

- **流量自适应配时**：每 5 分钟按进口道流量重算周期，`C₀ = (1.5L + 5) / (1 - Y)`
- **路口动态可视化**：Canvas 绘制十字路口俯视图，车辆按相位放行消散，红绿灯倒计时同步
- **配时方案看板**：相位甘特图 + 优化前后四项指标对比 + 早高峰/平峰/晚高峰切换
- **拥堵态势分级**：饱和度 v/c 五级色阶（畅通 / 基本畅通 / 轻度 / 中度 / 严重）
- **众包事件上报**：事故、施工、管制、拥堵四类事件，支持筛选与上报
- **离线可用**：Repository 抽象 + Mock 数据源，无网络或无后端时完整演示
- **收藏与个性化**：本地持久化收藏路口，首页直出常用入口

---

## 技术栈

| 层次 | 选型 |
| --- | --- |
| 应用模型 | HarmonyOS **Stage 模型**（UIAbility + WindowStage） |
| 语言 | **ArkTS**（TypeScript 超集，静态类型） |
| UI | **ArkUI 声明式** + `@Component` / `@State` / `@Prop` / `@Watch` |
| 路由 | `Navigation` + `NavPathStack` + `NavDestination` |
| 图形 | `Canvas`（RenderingContext2D）自绘路网、车流、仪表盘、甘特图 |
| 存储 | `@kit.ArkData` preferences |
| 手势 | `PinchGesture` / `PanGesture` 缩放平移 |
| 后端 | Spring Boot 3 + MyBatis-Plus + MySQL 8（可选，见文档） |
| 构建 | Hvigor（`targetSdkVersion 26.0.0` / `compatibleSdkVersion 6.1.1(24)`） |

> 地图采用 **双渲染引擎** 设计：默认 Canvas 拓扑图（零依赖、必定可运行），可切换花瓣地图 Map Kit 作为真实底图增强。因本项目只需底图轮廓，不依赖第三方实时路况数据。

---

## 页面结构

```
MainPage（底部四 Tab）
├── HomePage              首页 · 态势总览（拥堵指数仪表盘 / 路网色块 / 拥堵 TOP3）
├── TrafficMapPage        片区路况（Canvas 拓扑 + 双指缩放 + 5s 刷新）
├── EventPage             事件中心（类型筛选 / 上报入口）
└── MinePage              我的（收藏 / 数据说明 / 深色模式）
    ├── IntersectionDetailPage   路口实时（车流动画 / 相位倒计时 / 预计等待 / 拥堵诊断）
    │   └── SignalPlanPage       配时看板（甘特图 / 优化前后对比 / 时段切换）
    ├── EventReportPage          事件上报
    ├── FavoritePage             收藏路口
    └── AboutPage                数据说明（来源 / 指标口径 / 算法 / 免责声明）
```

### 界面预览

> 运行截图待补充。建议放置：首页、片区路况、路口实时（车流动画）、配时看板、事件中心、我的，共 6 张。

---

## 工程结构

```
SmartTransportation/
├── AppScope/                     # 应用级配置与资源
├── entry/                        # 主模块（HAP）
│   └── src/main/ets/
│       ├── common/
│       │   ├── constants/        # 主题、区域边界、全局配置
│       │   ├── utils/            # 指标换算、存储、收藏、提示、日志
│       │   └── base/             # 路由、跳转参数
│       ├── model/                # 路口、配时、流量、评价、事件实体
│       ├── mock/                 # 西安城墙内 15 路口仿真数据源
│       ├── repository/           # 数据仓库抽象 + Mock 实现
│       ├── components/           # 仪表盘、空态、加载态
│       ├── pages/                # 10 个页面
│       └── entryability/         # 应用入口
├── docs/
│   ├── 项目设计文档.md            # 定位、需求、架构、数据模型、算法、UI
│   └── 后端技术方案.md            # 建表 SQL、接口、Webster 实现、联调
└── build-profile.json5
```

---

## 快速开始

### 环境要求

| 项 | 版本 |
| --- | --- |
| DevEco Studio | 6.x |
| HarmonyOS SDK | API 20+（`targetSdkVersion 26.0.0`） |
| 设备 | HarmonyOS 6.x 手机或模拟器 |

### 运行

1. DevEco Studio 打开工程根目录，等待 Sync 完成
2. 连接模拟器或真机
3. 运行 `entry` 模块

默认使用本地仿真数据（`AppConstants.USE_REMOTE = false`），无需后端即可完整演示。

### 可调参数

| 配置 | 位置 | 说明 |
| --- | --- | --- |
| `USE_REMOTE` | `common/constants/AppConstants.ets` | 是否调用后端接口 |
| `BASE_URL` | 同上 | 后端地址（模拟器用 `10.0.2.2`，真机用局域网 IP） |
| `MAP_MODE` | 同上 | `TOPOLOGY`（默认）/ `MAP_KIT` |
| `REFRESH_FLOW_MS` | 同上 | 路况刷新间隔 |
| `ANIMATION_FRAME_MS` | 同上 | 车流动画帧间隔 |

---

## 数据说明

本项目**未接入真实交通数据与信号控制系统**，所有数据均为仿真结果：

- **路网拓扑**：依据公开地图资料手工建模，坐标做示意化处理
- **交通流量**：高斯双峰模型（早 8 点、晚 18 点）叠加随机扰动生成
- **配时方案**：由 Webster 最优周期模型实时计算
- **事件数据**：预置演示数据

接口协议与真实交通数据服务保持一致，替换数据源即可接入实际系统。

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [项目设计文档](docs/项目设计文档.md) | 研究区域、需求分析、系统架构、功能模块、数据模型、接口、算法、界面效果、实施计划 |
| [后端技术方案](docs/后端技术方案.md) | 技术选型、8 张表 DDL、10 个接口、Java 版 Webster 实现、局域网联调配置 |

---

## 开发进度

- [x] 工程初始化与主框架（Navigation + Tabs）
- [x] 西安城墙内路网建模（15 路口 / 18 路段）
- [x] 流量仿真与 Webster 配时算法（端侧）
- [x] 首页、片区路况、路口实时、配时看板
- [x] 事件中心与上报、收藏、数据说明
- [ ] 接入 Spring Boot 后端
- [ ] 花瓣地图（Map Kit）真实底图
- [ ] 关系型数据库缓存与离线优先
- [ ] 深色模式资源适配

---

## 声明

本项目为本科毕业设计作品，仅用于学习与研究，不用于真实出行决策，未接入任何交通管理部门的信号控制系统。
