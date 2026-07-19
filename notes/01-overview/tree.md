# Xyce 项目结构

记录日期：2026-07-19


### 1. 先给总判断

- `Xyce` 的真正核心在 `src/`
- `src/` 里面不是按技术层随意堆代码，而是按仿真子系统拆成多个 package
- 顶层入口在 `src/Xyce.C`
- 顶层总控类在 `CircuitPKG`
- 主要阅读主线通常是 `入口 -> Simulator -> Analysis / Topology / Device / Solver`

### 2. 给精简目录树，而不是全量目录树

目录树只保留“有结构意义”的节点，不要把太多零散文件塞进去。

像下面这种粒度比较合适：

```text
Xyce-7.10.0/
├── src/                    # 核心源码
│   ├── Xyce.C             # 程序入口
│   ├── CircuitPKG/        # 顶层仿真器与总调度
│   ├── AnalysisPKG/       # .OP / .DC / .TRAN / .AC 等分析调度
│   ├── IOInterfacePKG/    # 命令行、netlist、输出接口
│   ├── TopoManagerPKG/    # 电路拓扑构建与节点管理
│   ├── DeviceModelPKG/    # 器件框架与具体器件模型
│   ├── LoaderServicesPKG/ # 装配器件贡献到方程系统
│   ├── LinearAlgebraServicesPKG/  # 线性系统、矩阵、向量
│   ├── NonlinearSolverPKG/        # 牛顿法和非线性求解
│   ├── TimeIntegrationPKG/        # 瞬态时间积分
│   ├── ParallelDistPKG/           # MPI 并行与分布式数据结构
│   ├── UtilityPKG/                # 通用基础设施
│   └── ErrorHandlingPKG/          # 错误与消息处理
├── test/                   # 回归测试与包级测试
├── utils/                  # 辅助脚本、接口工具、插件工具
├── cmake/                  # CMake 构建逻辑
├── config/                 # Autotools / 配置探测脚本
├── doc/                    # 上游文档资源
├── distribution/           # 打包与发布脚本
└── gitlab-ci/              # CI 配置
```

### 3. 按职责解释关键目录

目录树下面不要继续贴更多树，而是改成“讲解模式”。

最适合 Xyce 的顺序通常是：

1. 顶层入口
2. 仿真主流程
3. 电路建模与装配
4. 求解基础设施
5. 构建、测试、工具

因为这更接近“程序实际怎么跑”。

### 4. 给阅读主线

这是最容易漏掉，但最有价值的一部分。

只讲目录职责，读者仍然可能不知道下一步该读哪里。  
所以最好明确给出阅读顺序，例如：

```text
src/Xyce.C
  -> CircuitPKG/N_CIR_Xyce.*
  -> IOInterfacePKG + TopoManagerPKG
  -> DeviceModelPKG + LoaderServicesPKG
  -> AnalysisPKG
  -> LinearAlgebraServicesPKG + NonlinearSolverPKG + TimeIntegrationPKG
```

这样文档就从“静态目录说明”变成了“动态学习导航”。

## 一句话总览

`Xyce` 的源码主体集中在 `src/`，其内部按仿真子系统拆成多个 package；顶层从 `src/Xyce.C` 进入，经 `CircuitPKG` 的 `Simulator` 完成初始化与调度，再把工作分发到 netlist、拓扑、器件、装配、分析和求解等模块。

## 顶层目录应该怎么理解

### `src/`

这是最核心的目录，几乎所有“仿真程序本身怎么工作”的问题，最后都会回到这里。

### `test/`

这是测试目录，用来验证主要包和功能。学习源码主线时通常不是第一优先级，但在确认行为或找最小例子时很有帮助。

### `utils/`

这里主要是辅助工具和接口资源，例如插件工具、脚本、外部接口示例。它们重要，但不属于模拟器主执行路径。

### `cmake/` 与 `config/`

这两部分更偏构建系统：

- `cmake/` 是当前主构建逻辑
- `config/` 更偏历史的 Autotools / 配置探测

只有当你研究“这个功能为何能编进来”或“依赖如何启用”时，才需要重点进入。

### `distribution/` 与 `gitlab-ci/`

这两部分主要服务于发布和持续集成，不是理解仿真核心算法的第一入口。

## `src/` 里的核心分层

`src/` 不是随意分包，而是大致围绕“仿真主流程”展开的。

### 第一层：入口与总控

- `Xyce.C`
- `CircuitPKG/`

这里负责：

- 程序启动
- 构造顶层 `Simulator`
- 组织初始化阶段
- 调度后续各个子系统

如果把 Xyce 看成一家公司，这一层像“总控台”。

### 第二层：输入、电路构建、器件接入

- `IOInterfacePKG/`
- `TopoManagerPKG/`
- `DeviceModelPKG/`
- `LoaderServicesPKG/`

这里负责把外部 netlist 逐步变成内部仿真对象：

- 解析输入
- 建立节点和拓扑
- 实例化器件
- 把器件对方程的贡献装配进系统

这是从“文本描述的电路”走向“可求解方程系统”的关键链路。

### 第三层：分析与求解

- `AnalysisPKG/`
- `LinearAlgebraServicesPKG/`
- `NonlinearSolverPKG/`
- `TimeIntegrationPKG/`
- `MultiTimePDEPKG/`

这里负责：

- 选择分析类型
- 组织 DC / TRAN / AC / NOISE / HB 等分析流程
- 建立和求解线性与非线性系统
- 处理时间积分或更高级的多时间尺度分析

这部分是“仿真真正算起来”的地方。

### 第四层：基础设施

- `ParallelDistPKG/`
- `UtilityPKG/`
- `ErrorHandlingPKG/`

这里提供的是横向支撑能力：

- MPI 并行与分布式数据结构
- 通用工具、日志、参数、辅助类
- 错误、消息与报告机制

它们不一定直接体现某个分析算法，但很多主线都会依赖它们。

## 讲目录时，最该突出哪些 package

如果只想让读者快速抓主线，最值得优先解释的是这 8 个：

1. `CircuitPKG`
   顶层 `Simulator`，总调度中心。
2. `AnalysisPKG`
   各类仿真分析的统一入口。
3. `IOInterfacePKG`
   命令行、netlist、输出接口所在层。
4. `TopoManagerPKG`
   电路节点和连接关系的组织层。
5. `DeviceModelPKG`
   器件框架与器件模型主体。
6. `LoaderServicesPKG`
   从器件贡献到方程装配的桥梁层。
7. `LinearAlgebraServicesPKG`
   矩阵、向量、线性系统与线性求解服务。
8. `NonlinearSolverPKG`
   牛顿法及非线性求解框架。

只要把这 8 个讲顺，读者对 Xyce 的整体结构就已经有骨架了。

## 最适合学习者的阅读顺序

如果这份 Markdown 面向“源码学习”，我建议把阅读顺序写死，而不是让读者自己猜。

推荐写法：

```text
第一步：看入口
src/Xyce.C

第二步：看顶层总控
src/CircuitPKG/N_CIR_Xyce.h
src/CircuitPKG/N_CIR_Xyce.C

第三步：看输入与电路构建
src/IOInterfacePKG/
src/TopoManagerPKG/
src/DeviceModelPKG/
src/LoaderServicesPKG/

第四步：看分析调度与求解
src/AnalysisPKG/
src/LinearAlgebraServicesPKG/
src/NonlinearSolverPKG/
src/TimeIntegrationPKG/

第五步：按专题补基础设施
src/ParallelDistPKG/
src/UtilityPKG/
src/ErrorHandlingPKG/
```

这样写有一个很大的好处：

- 它承认 `src/` 很大
- 但又把读者的注意力稳稳锁在主线，而不是把人淹死在目录海里

## 一个更适合长期维护的模板

如果你后面还想持续更新 `tree.md`，建议固定成下面这种结构：

````md
# Xyce 项目结构地图

## 目标
- 这份文档回答什么问题

## 一句话总览
- 用 3-5 句话概括项目结构

## 精简目录树
```text
...
```

## 顶层目录说明
- src/
- test/
- utils/
- cmake/
- config/

## src/ 主干分层
- 入口与总控
- 输入与电路构建
- 分析与求解
- 基础设施

## 关键 package 速查
- CircuitPKG: ...
- AnalysisPKG: ...
- DeviceModelPKG: ...

## 推荐阅读顺序
- 从哪里开始
- 下一步读哪里

## 暂时可以先不读的部分
- distribution/
- gitlab-ci/
- ...
````

注意：如果文档里要放代码块嵌套展示，实际写文件时需要把内层围栏换成更多反引号，避免 Markdown 提前闭合。

## 当前这份 `tree.md` 应该怎么改

如果只针对当前文件，我建议你遵循这 3 个改法：

1. 删除终端提示符和命令回显  
   不要保留 `(base) [eda@eda Xyce-7.10.0]$ tree -L 2` 这种内容，文档里只保留“树本身”和“树的解释”。

2. 把完整树改成精简树  
   顶层保留，`src/` 下保留关键 package，零散文件只保留最能代表角色的几个，例如 `Xyce.C`、`CMakeLists.txt`。

3. 在树下面增加“职责说明 + 阅读顺序”  
   这是让它从“静态列表”升级为“学习地图”的关键一步。

## 这轮最重要的结论

想把整个 Xyce 项目整体结构讲清楚，核心不是“树画得更完整”，而是让读者知道：

- 哪些目录是主干
- 每层各自负责什么
- 它们怎么串成一条执行主线
- 自己下一步该读哪里

只要做到这 4 点，这份 Markdown 就已经不是目录摘录，而是一份真正有教学价值的结构地图。

## 下一步建议

最自然的下一步是把这份文档再和 [notes/01-overview/01-architecture-map.md](../notes/01-overview/01-architecture-map.md) 对齐：

- `tree.md` 负责“目录与分层”
- `01-architecture-map.md` 负责“入口、总控类、主执行链”

两份文档配合起来，会比任何一份单独的完整目录树都更清楚。
