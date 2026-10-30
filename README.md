# 智行西安 · 基于 HarmonyOS 的片区信号配时优化与交通态势可视化系统

以 **西安城墙内片区** 为例的本科毕业设计项目。面向 11.3 km² 的古城核心区，构建「**感知 → 优化 → 评价 → 服务**」的交通信号配时闭环：以 Webster 模型按实时流量重算配时方案，鸿蒙端将优化过程与结果可视化，并把算法结论翻译成用户能理解的信息（如「该方向还需等待 26 秒」）。

> **实现状态**：本期为**纯端侧实现**——算法与仿真在 ArkTS 端完成，无需后端即可完整演示；
> 后端服务、Map Kit 真实底图、状态管理 V2、本地关系库等**尚未实现**。
> 后端方案已定稿为 **Node.js + TypeScript + Fastify**（算法可从端侧零成本平移，工期 4~5 天）。
> 逐项「已做 / 未做」对照见 **[docs/实现状态清单.md](docs/实现状态清单.md)**。

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
| 感知 | 采集 20 个路口 × 各进口道的流量、排队、延误，计算饱和度并分级 |
| 优化 | 按 Webster 最优周期模型重算周期与绿信比，输出四相位配时方案 |
| 评价 | 用 Webster 延误模型对比优化前后的延误、排队、通行量、停车次数 |
| 服务 | 将配时结果翻译为「预计等待 N 秒」，并对拥堵进口道给出诊断建议 |

---

## 核心特性

- **流量自适应配时**：按进口道流量重算周期，`C₀ = (1.5L + 5) / (1 - Y)`，并按流量比分配各相位绿灯
- **路口动态可视化**：Canvas 绘制十字路口俯视图，车辆按相位放行消散，红绿灯倒计时同步
- **配时方案看板**：周期/损失时间/相位分配 + 优化前后四项指标对比 + 时段切换
  （⚠️ 时段切换当前不参与计算；四项指标中通行量、停车次数为演示性估算值）
- **拥堵态势分级**：饱和度 v/c 五级色阶（畅通 / 基本畅通 / 轻度 / 中度 / 严重）
- **事件中心**：事故、施工、管制、拥堵四类事件，支持列表与类型筛选
  （⚠️ 上报表单已实现，但提交后不持久化）
- **离线可用**：Repository 抽象 + Mock 数据源，无网络或无后端时完整演示
- **收藏与个性化**：preferences 持久化收藏路口

---

## 技术栈

| 层次 | 选型 |
| --- | --- |
| 应用模型 | HarmonyOS **Stage 模型**（UIAbility + WindowStage） |
| 语言 | **ArkTS**（TypeScript 超集，静态类型） |
| UI | **ArkUI 声明式** + `@Component` / `@State` / `@Prop` / `@Watch` |
| 路由 | `Navigation` + `NavPathStack` + `NavDestination` |
| 图形 | `Canvas`（RenderingContext2D）自绘路网、车流、仪表盘、相位条 |
| 状态管理 | **V2**（`@ComponentV2` / `@Local` / `@Param` / `@Monitor`） |
| 存储 | `@kit.ArkData` preferences（仅收藏）；关系库未建 |
| 手势 | `PinchGesture` / `PanGesture` 缩放平移 |
| 后端 | **Node.js 20 + TypeScript + Fastify + SQLite**（方案 V3.0 已定稿，尚未实现，见 [`后端技术方案.md`](docs/后端技术方案.md)） |
| 构建 | Hvigor（`targetSdkVersion 26.0.0` / `compatibleSdkVersion 6.1.1(24)`） |

> 地图采用 **Canvas 拓扑自绘**（零依赖、必定可运行）。花瓣地图 Map Kit 仅保留为可选增强方案，
> 接口位（`AppConstants.MAP_MODE`、`IMapRenderer`）已预留但**未实现**——本项目需在图上叠加相位、排队、倒计时等动态要素，
> 拓扑图比真实底图更清晰，且模拟器与签名证书门槛高。

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

---

## 工程结构

```
SmartTransportation/
├── AppScope/                     # 应用级配置与资源
├── entry/                        # 主模块（HAP）
│   └── src/main/ets/
│       ├── common/
│       │   ├── constants/        # 主题、区域边界、全局配置
│       │   ├── utils/            # 指标换算、收藏、存储、提示、日志
│       │   └── base/             # 路由、跳转参数
│       ├── model/                # 路口、配时、流量、评价、事件实体
│       ├── mock/                 # 西安城墙内 20 路口仿真数据源 + 全部算法
│       ├── repository/           # 数据仓库抽象 + Mock 实现（Remote 待补）
│       ├── components/           # 仪表盘、闪屏、空态、加载态
│       ├── pages/                # 10 个页面
│       ├── viewmodel/            # （规划，未建）
│       ├── renderer/             # （规划，未建）
│       └── entryability/         # 应用入口
├── server/                       # 后端服务（Node + TS，骨架已建，代码待填）
│   └── src/                      # index/routes/service/algo/source/store/task
├── docs/
│   ├── 项目设计文档.md            # 定位、需求、架构、数据模型、算法、UI
│   ├── 后端技术方案.md            # 数据源定位、表结构、接口契约、算法、联调（方案，未实现）
│   └── 实现状态清单.md            # 已做 / 未做逐项对照
└── build-profile.json5
```

> `server/` 与 `entry/` 平级，**不参与鸿蒙构建**（`build-profile.json5` 的 `modules` 只声明 `entry`），
> 因此不会被打进 HAP。建议在 DevEco 中把 `server/node_modules` 标记为 Excluded，避免拖慢索引。

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
| `USE_REMOTE` | `common/constants/AppConstants.ets` | 预留开关，**当前未接线**，`RepositoryFactory` 恒返回 Mock |
| `BASE_URL` | 同上 | 后端地址（模拟器用 `10.0.2.2`，真机用局域网 IP） |
| `MAP_MODE` | 同上 | 预留常量，当前无渲染实现 |
| `REFRESH_FLOW_MS` | 同上 | 路况刷新间隔，默认 5000ms |
| `ANIMATION_FRAME_MS` | 同上 | 车流动画帧间隔，默认 200ms |
| `PHASE_DEMO_SECONDS` | 同上 | 路口页每个相位的演示秒数（加速演示） |

---

## 数据说明

本项目**未接入真实交通数据与信号控制系统**，所有数据均为仿真结果：

- **路网拓扑**：依据公开地图资料手工建模，坐标做示意化处理
- **交通流量**：高斯双峰模型（早 8 点、晚 18 点）+ 确定性伪随机扰动生成
- **配时方案**：由 Webster 最优周期模型实时计算（周期、绿信比、Webster 延误）
- **优化评价**：延误用 Webster 模型计算；**通行量、停车次数与优化前基线为演示性估算值**，非仿真统计结果
- **事件数据**：预置演示数据；上报后不落库

接口协议与真实交通数据服务保持一致，替换数据源即可接入实际系统。
算法口径的差异与局限已在 [项目设计文档 §10.7](docs/项目设计文档.md) 中逐条列明。

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [项目设计文档](docs/项目设计文档.md) | 研究区域、需求分析、系统架构、功能模块、数据模型、算法推导与参数依据、界面、进度 |
| [后端技术方案](docs/后端技术方案.md) | V3.0：Node+TS 技术选型、数据源定位（仿真/OSM/地图 API）、8 张表 DDL、11 个接口契约、TS 版 Webster 实现、联调与三态降级（**方案，未实现**） |
| [实现状态清单](docs/实现状态清单.md) | 已做 / 未做逐项对照、算法口径核对、文档与实现的偏差、后续优先级 |

---

## 开发进度

已完成：

- [x] 工程初始化与主框架（Navigation + Tabs + 闪屏）
- [x] 西安城墙内路网建模（20 路口 / 32 路段，按真实主干道路与坐标）
- [x] 流量仿真与 Webster 配时、Webster 延误（端侧）
- [x] 首页、片区路况、路口实时、配时看板
- [x] 事件中心与上报、收藏、我的、数据说明
- [x] preferences 收藏持久化
- [x] 文档客观化修订（V2.1 + 实现状态清单）
- [x] **前后端分离**：后端 Node+TS 骨架与 11 个接口；端侧网络层与三态降级

未实现（含优先级）：

- [ ] **P0** 首页成效提示条改为实时计算（当前为硬编码文案）
- [ ] **P0** 配时看板时段切换真正生效（当前 `scenario` 不参与计算）
- [ ] **P1** 评价模块改为逐周期排队推演（去掉构造值）
- [ ] **P1** 事件上报落库并回显列表
- [ ] **P1** 算法单测 + 性能实测
- [ ] **P2** 饱和度与配时迭代收敛
- [ ] **P2** 深色模式资源适配
- [ ] **P1** 后端落库 SQLite + 定时任务（约 1 天；事件当前存内存）
- [ ] **P1** OSM 导出真实路网坐标（0.5~1 天）
- [ ] **P3** 后端落库 SQLite + 定时任务（约 1 天）
- [ ] **P3** OSM 导出真实路网坐标（0.5~1 天）
- [ ] **P3** 花瓣地图（Map Kit）真实底图（需真机 + 签名证书）
- [ ] **P3** 干线绿波协调（相位差）
- [ ] **P3** ViewModel 分层 / 状态管理 V2 迁移

---

## 声明

本项目为本科毕业设计作品，仅用于学习与研究，不用于真实出行决策，未接入任何交通管理部门的信号控制系统。
