# Xyce 导航地图

记录日期：2026-05-26

这份文档记录第一阶段“建立整体地图”的结果。

当前目标不是吃透每个实现细节，而是先建立一张可导航的源码地图：

- 程序从哪里启动
- 顶层 simulator 是哪个类
- 主要 package 各自负责什么
- 下一步应该沿着哪条主线继续往下读

## 当前观察范围

这一版导航地图主要基于以下信息整理：

- [src/CMakeLists.txt](../../vendor/Xyce-7.10.0/src/CMakeLists.txt)
- [src/Xyce.C](../../vendor/Xyce-7.10.0/src/Xyce.C)
- [src/CircuitPKG/N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h)
- [src/AnalysisPKG/N_ANP_AnalysisManager.h](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)
- `src/` 下各 package 的目录名与代表文件名

这里有两类结论：

- 已确认：能直接从入口文件、类定义或构建文件看出来的事实
- 工作假设：目前主要依据目录命名和代表文件推断，后续可能修正

## 顶层入口

### 已确认结论

- `src/CMakeLists.txt` 定义了可执行程序 `Xyce`，其入口源文件是 [src/Xyce.C](../../vendor/Xyce-7.10.0/src/Xyce.C)。
- `main()` 位于 [src/Xyce.C](../../vendor/Xyce-7.10.0/src/Xyce.C) 附近。
- 默认执行路径是：
  - 创建 `Xyce::Circuit::Simulator`
  - 调用 `xyce.run(argc, argv)`
- 因此，第一阶段里最关键的顶层类是 [CircuitPKG/N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 中的 `Xyce::Circuit::Simulator`。

### 入口主线

第一条最值得继续跟的主线可以先记成：

```text
main()
  -> Xyce::Circuit::Simulator
  -> Simulator::run()
  -> initialize / runSimulation
  -> 进入各子系统
```

这条主线已经足够支撑第一阶段的源码导航，不需要现在就深入每个函数实现。

## 顶层 simulator 的角色

从 [N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 可以直接看到几条关键线索。

### 已确认结论

- `Simulator` 被注释为 Xyce 的 main top level class。
- `Simulator::RunState` 已经把初始化过程拆成了多个阶段：
  - `PARSE_COMMAND_LINE`
  - `CHECK_NETLIST`
  - `ALLOCATE_SUBSYSTEMS`
  - `PARSE_NETLIST`
  - `SETUP_TOPOLOGY`
  - `INSTANTIATE_DEVICES`
  - `SETUP_MATRIX_STRUCTURE`
  - `INITIALIZE_SYSTEM`
- `Simulator` 持有或暴露多个关键 manager / subsystem：
  - `Analysis::AnalysisManager`
  - `Device::DeviceMgr`
  - `Nonlinear::Manager`
  - `Linear::System`
  - `Loader::CktLoader`

### 当前理解

这说明 `CircuitPKG` 不是器件实现本身，也不是具体分析算法本身，而更像是：

- 顶层流程编排层
- 各子系统的装配点
- 从命令行、netlist 到求解流程之间的总调度层

## package 地图

下面的地图按“当前最适合导航”的方式组织。除特别注明外，职责描述都先视为工作假设。

### 1. `CircuitPKG`

代表文件：

- [src/CircuitPKG/N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h)
- [src/CircuitPKG/N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)

当前角色判断：

- 顶层 simulator 封装
- 总初始化流程
- 子系统装配和调度

为什么这样判断：

- 可执行入口直接创建 `Xyce::Circuit::Simulator`
- `Simulator` 的成员接口直接连接 analysis、device、nonlinear、linear、loader
- `RunState` 明确暴露了仿真初始化阶段划分

### 2. `AnalysisPKG`

代表文件：

- [src/AnalysisPKG/N_ANP_AnalysisManager.h](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)
- `N_ANP_Op.h`
- `N_ANP_DCSweep.h`
- `N_ANP_Transient.h`
- `N_ANP_AC.h`

已确认线索：

- `AnalysisManager` 的注释明确写着：负责管理、分配、设置各种分析类型，例如 DC、Tran、HB。
- `AnalysisManager` 提供 `run()`、`initializeSolverSystem()`、`resetSolverSystem()` 等接口。

当前角色判断：

- 各分析类型的统一调度层
- `.OP`、`.DC`、`.TRAN`、`.AC` 等分析模式的分发入口
- 连接 analysis 层与 solver system 的桥接层

### 3. `DeviceModelPKG`

代表目录：

- `src/DeviceModelPKG/Core/`
- `src/DeviceModelPKG/OpenModels/`
- `src/DeviceModelPKG/ADMS/`
- `src/DeviceModelPKG/IBISModels/`
- `src/DeviceModelPKG/NeuronModels/`
- `src/DeviceModelPKG/TCADModels/`

`Core/` 下代表文件：

- `N_DEV_Device.h`
- `N_DEV_DeviceInstance.h`
- `N_DEV_DeviceModel.h`
- `N_DEV_DeviceMaster.h`
- `N_DEV_DeviceMgr.h`
- `N_DEV_RegisterDevices.h`
- `N_DEV_MatrixLoadData.h`

当前角色判断：

- 器件抽象基类与器件注册框架
- 器件实例、模型、参数、状态的核心数据结构
- 具体器件模型实现的承载目录

为什么这样判断：

- 文件名里直接出现 `Device`, `DeviceInstance`, `DeviceModel`, `DeviceMgr`
- `Core/` 看起来提供的是通用器件框架，而不是某一个具体器件
- 多个子目录名显示这里不仅有基础器件，还有不同来源或类别的模型实现

### 4. `IOInterfacePKG`

当前角色判断：

- 输入输出接口层
- netlist、命令行选项、输出文件管理的候选位置

支撑线索：

- 目录内文件名大量包含 `OutputMgr`、`Outputter`
- `N_CIR_Xyce.h` 中直接包含了 `N_IO_CmdParse.h`

当前提醒：

- 这里大概率是后续追 `netlist parser` 必须进入的目录之一
- 但第一阶段还没有确认“真正的 netlist 解析入口函数”具体在哪个文件

### 5. `LinearAlgebraServicesPKG`

当前角色判断：

- 线性代数基础设施层
- 矩阵、向量、线性系统抽象以及相关服务

支撑线索：

- `Simulator` 直接暴露 `Linear::System &getLinearSystem()`
- package 名字已经非常明确

当前阅读建议：

- 第一阶段只需要知道它是“矩阵和线性系统”的归属地
- 暂时不要深入具体稀疏矩阵实现

### 6. `NonlinearSolverPKG`

代表文件：

- `N_NLS_Manager.h`
- `N_NLS_NonLinearSolver.h`
- `N_NLS_DampedNewton.h`
- `N_NLS_NOX.h`
- `N_NLS_TwoLevelNewton.h`

当前角色判断：

- 非线性求解总管理层
- 牛顿法及相关求解策略实现位置
- 和 NOX / LOCA 等外部求解框架对接的位置

为什么这样判断：

- 文件名直接出现 `Manager`、`NonLinearSolver`、`DampedNewton`、`NOX`
- `Simulator` 中直接暴露了 `Nonlinear::Manager`

### 7. `TimeIntegrationPKG`

当前角色判断：

- 时间积分与 transient 步进相关逻辑

支撑线索：

- `AnalysisManager` 中出现了 `TimeIntg::TIAParams`
- package 名字直接对应时间积分

当前阅读建议：

- 第一阶段先把它归到 `.TRAN` 相关基础设施
- 等读 transient 主线时再深入

### 8. `LoaderServicesPKG`

当前角色判断：

- 负责把器件或方程信息装配到求解系统中的服务层

支撑线索：

- `Simulator` 提供了 `Loader::CktLoader &getCircuitLoader()`
- `AnalysisManager::initializeSolverSystem()` 需要 `Loader::Loader`

当前提醒：

- 这个 package 很可能会成为“器件如何进入方程系统”的关键过渡层
- 后续做器件纵向追踪时应重点关注

### 9. `TopoManagerPKG`

当前角色判断：

- 电路拓扑管理层
- 节点、连接关系、拓扑构建的候选位置

支撑线索：

- `Simulator::RunState` 中明确出现 `SETUP_TOPOLOGY`
- package 名字直接指向 topology manager

### 10. `UtilityPKG`

当前角色判断：

- 通用工具层
- 工厂、监听器、计时器、表达式、统计等公共基础设施

支撑线索：

- `AnalysisManager.h` 中包含 `N_UTL_Factory.h`、`N_UTL_Listener.h`、`N_UTL_Stats.h`、`N_UTL_Timer.h`
- `src/CMakeLists.txt` 中可以看到 expression parser 由 `UtilityPKG/ExpressionSrc` 生成

当前提醒：

- 这个目录会频繁被别的 package 引用
- 但第一轮阅读不应把它当作主线入口

### 11. `ErrorHandlingPKG`

当前角色判断：

- 错误处理、消息输出、进度报告

支撑线索：

- `Xyce.C` 直接包含 `N_ERH_ErrorMgr.h`
- 文件名中有 `ErrorMgr`、`Message`、`Messenger`、`Progress`

### 12. `ParallelDistPKG`

当前角色判断：

- MPI / 并行运行环境相关封装

支撑线索：

- `Simulator` 构造函数接收 `Parallel::Machine`
- `main()` 返回码注释明确提到了 MPI 并行退出约束

### 13. 其他相对专项的 package

- `DakotaLinkPKG`
  - 看起来是与 Dakota 耦合的接口层
  - `main()` 中检测到 `-dakota` 时会改走 `Xyce::Dakota::Controller`
- `MultiTimePDEPKG`
  - 名字显示是更专项的多时间 PDE 能力
  - 目前不适合作为第一轮主线入口

## 一张粗粒度流程图

按当前理解，可以先把 Xyce 的高层结构记成这样：

```text
Xyce executable
  -> CircuitPKG
       -> IOInterfacePKG
       -> TopoManagerPKG
       -> DeviceModelPKG
       -> LoaderServicesPKG
       -> LinearAlgebraServicesPKG
       -> NonlinearSolverPKG
       -> AnalysisPKG
       -> TimeIntegrationPKG
```

这个图不是严格依赖图，更像是第一阶段用来导航的“阅读地图”。

## 第一阶段的阅读结论

到目前为止，可以把下面这些视为已经比较稳的判断：

1. 程序入口是 [src/Xyce.C](../../vendor/Xyce-7.10.0/src/Xyce.C)。
2. 顶层 simulator 类是 [CircuitPKG/N_CIR_Xyce.h](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.h) 里的 `Xyce::Circuit::Simulator`。
3. `CircuitPKG` 是总调度层，而不是具体数值算法层。
4. `AnalysisPKG` 负责不同 analysis mode 的管理与分发。
5. `DeviceModelPKG` 是器件抽象与具体模型实现的核心区域。
6. `NonlinearSolverPKG` 和 `LinearAlgebraServicesPKG` 分别对应非线性求解与线性系统基础设施。

## 当前还没有确认的点

下面这些问题仍然留给后续阶段：

- netlist parser 的真正入口函数在哪个文件
- 拓扑建立是如何从 parser 结果进入 `TopoManagerPKG`
- device instantiate 到 matrix load 的确切调用链
- analysis manager 是在什么时机选择 `.DC`、`.TRAN`、`.AC`
- loader 和 nonlinear solver 的边界如何划分

## 下一步建议

如果延续当前主线，最自然的下一步是：

1. 继续沿着 `Simulator::run()` / `initialize()` 往下读。
2. 定位 `PARSE_NETLIST` 对应的实际函数实现。
3. 确认 `IOInterfacePKG` 中 netlist 相关的入口对象。
4. 再开始做一条 “netlist -> device instantiate” 的纵向追踪。

## 一句话版本

如果只用一句话概括当前导航地图：

Xyce 的源码第一眼应该从 `src/Xyce.C` 和 `CircuitPKG/N_CIR_Xyce.*` 入手，把 `CircuitPKG` 看成总调度层，再把 `AnalysisPKG`、`DeviceModelPKG`、`IOInterfacePKG`、`LoaderServicesPKG`、`NonlinearSolverPKG`、`LinearAlgebraServicesPKG` 视为后续要逐步打通的主干子系统。
