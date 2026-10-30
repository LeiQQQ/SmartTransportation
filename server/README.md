# 后端服务（Node + TypeScript + Fastify）

> 面向没写过 Node 的同学：你只需要会 **3 个命令**。代码主体（算法、接口）会在 P1 阶段逐步填充并配好注释。

配套文档：[后端技术方案](../docs/后端技术方案.md)（V3.0）

---

## 一、三步启动

> **本机环境提示**：Node 装在 `D:\nodejs`，**未加入系统 PATH**，终端直接敲 `node` 会提示找不到命令。
> 每个新终端先执行一次：`$env:PATH = "D:\nodejs;$env:PATH"`（PowerShell）。
> 若已把 `D:\nodejs` 加进系统环境变量，可跳过这步。

```powershell
# ① 装依赖（只需做一次）
$env:PATH = "D:\nodejs;$env:PATH"
npm install
npm install-scripts approve esbuild   # npm 11 默认拦截安装脚本，需放行 tsx 依赖的 esbuild

# ② 启动（改代码自动重启）
npm run dev

# ③ 验证：浏览器打开
#    http://localhost:8080/api/v1/health
```

看到 `{"code":0,...,"data":{"status":"ok",...}}` 就说明跑通了。

**常用命令**

| 命令 | 作用 |
| --- | --- |
| `npm run dev` | 开发启动，改代码自动重启 |
| `npm run typecheck` | 只检查类型错误，不产出文件 |
| `npm run build` | 编译到 `dist/` |
| `npm start` | 运行编译产物（答辩当天用这个更稳） |

换端口：`PORT=3000 npm run dev`（Windows PowerShell：`$env:PORT=3000; npm run dev`）

---

## 二、目录结构（当前为骨架，标注了各层何时填充）

```
server/
├── package.json          # 依赖与脚本
├── tsconfig.json         # TypeScript 配置
├── README.md             # 本文件
├── data/                 # 运行时数据（network.json、store.db）
└── src/
    ├── index.ts          # ✅ 已实现：服务入口 + /health
    ├── types/            # 实体定义，与端侧 model/ 同名同字段
    ├── routes/           # 路由：参数校验 + 响应包装（P1）
    ├── service/          # 业务：流量、配时、事件（P1）
    ├── algo/             # 算法：从端侧 XianWallMock.ets 平移（P1）
    ├── source/           # 数据源适配器：仿真 / OSM / 地图 API（P1~P4）
    ├── store/            # 存储：JSON → SQLite（P1~P2）
    └── task/             # 定时任务（P2）
```

**各层一句话职责**

- `routes`：接口长什么样（URL、参数、返回）
- `service`：业务怎么算（调 `algo`）
- `algo`：纯算法（Webster 配时、延误、流量仿真）
- `source`：数据从哪来（仿真 / OSM / 地图 API）
- `store`：数据存到哪（JSON 文件 / SQLite）

---

## 三、当前状态

| 阶段 | 内容 | 状态 |
| --- | --- | --- |
| P0 | 接口契约定稿 + 端侧网络层 | ✅ 已完成（`HttpUtil` / `ApiResponse` / `RemoteDtos` / `RemoteTrafficRepository` / 三态工厂） |
| P1 | 本工程骨架 + 算法平移 + 全部接口 | ✅ 已完成，11 个接口实测通过 |
| P2 | SQLite 落库 + 定时任务 | 未开始 |
| P3 | OSM 导出真实路网坐标 | 未开始 |
| P4 | 地图 API 适配器（可选） | 未开始 |

**已实现模块**

| 文件 | 职责 |
| --- | --- |
| `src/config.ts` | 全部参数（算法、区域、场景、服务端口） |
| `src/types/` | 实体定义，与端侧 `model/` 同名同字段 |
| `src/algo/simulator.ts` | 流量仿真、拥堵指数 |
| `src/algo/webster.ts` | 最优周期与绿信比分配 |
| `src/algo/delay.ts` | Webster 延误 |
| `src/data/network.ts` | 20 路口 + 32 路段静态路网（与端侧严格一致） |
| `src/source/` | 数据源抽象与仿真实现 |
| `src/service/` | 流量 / 配时 / 事件三类业务 |
| `src/routes/` | health / area / traffic / signal / event 五组路由 |
| `src/container.ts` | 依赖装配 |

---

## 四、给不熟悉 Node 的五条保命提示

1. **`npm install` 失败**：多半是网络问题，可换镜像 `npm config set registry https://registry.npmmirror.com` 后重试。
2. **`'node' is not recognized`**：PATH 里没有 Node，先执行 `$env:PATH = "D:\nodejs;$env:PATH"`（常见于 esbuild 安装脚本报错）。
3. **端口占用**：`8080` 被别的程序占了就换 `PORT=3000 npm run dev`，同时改端侧 `AppConstants.BASE_URL`。
4. **控制台中文乱码**：Windows 控制台编码问题，不影响接口返回，可忽略。
5. **端侧连不上**：先用浏览器访问 `http://<本机IP>:8080/api/v1/health` 确认服务本身是通的，再去排查鸿蒙端的明文放行与 IP（详见后端方案 §9.3）。
   服务启动时会打印所有监听地址（`127.0.0.1`、局域网 IP、VMware 虚拟网卡 IP），**真机联调用其中的局域网 IP**，每次联网后可能变化，以 `ipconfig` 为准。

---

### 本机实测记录（2026-10-30）

| 项 | 实测结果 |
| --- | --- |
| Node | `D:\nodejs`，v26.13.0（另有 DevEco 内置 v24.14.1，未使用） |
| npm | v11.20.0 |
| 依赖安装 | 54 个包，2 秒完成（走 npmmirror 镜像） |
| Fastify | **^5.2.0**（Node 26 与 Fastify 4 兼容性不佳，已升到 5.x） |
| 启动验证 | ✅ `GET /api/v1/health` 返回 `{"code":0,"data":{"status":"ok","dataSource":"SIMULATION"}}` |
| 监听地址 | `127.0.0.1`、局域网 IP（本次为 `10.124.10.210`）、VMware 虚拟网卡 IP |

---

## 五、与端侧的关系

```
鸿蒙端（ArkTS，entry/）──HTTP/JSON──▶ 本服务
```

- 端侧**只认 HTTP + JSON**，本服务用什么语言写对它无影响
- 接口字段统一驼峰 + 毫秒时间戳，与端侧 `entry/src/main/ets/model/` 同名
- 端侧 `RepositoryFactory` 将支持 `MOCK / AUTO / REMOTE` 三态：`AUTO` 会先请求 `/health`，失败自动回落本地仿真数据，**答辩当天服务没起来也能演示**

## 六、算法同步约定（重要）

`src/algo/` 与端侧 `entry/src/main/ets/mock/XianWallMock.ets` 是同一套算法的两份实现。
**任一侧修改参数，另一侧必须同步**，否则会出现"前后端算出的周期不一致"这种难以排查的问题。
