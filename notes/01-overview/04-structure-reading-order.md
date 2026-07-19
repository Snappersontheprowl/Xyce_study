# Xyce 结构主线与阅读顺序

记录日期：2026-07-19

## 这篇的目标

前两篇已经把目录和 package 讲开了，这一篇只回答一个问题：

- 如果现在开始读 Xyce，按什么顺序最容易把整个项目结构读明白

## 先区分两种“顺序”

阅读 Xyce 时，很容易把下面两种顺序混在一起：

1. 目录排列顺序
2. 程序结构顺序

真正有用的是第二种。

因为源码学习的目标不是记住目录名，而是知道：

- 程序怎样从入口流动起来
- 每个 package 在这条流里扮演什么角色

## 结构主线

当前阶段最值得记住的一条结构主线是：

```text
src/Xyce.C
  -> CircuitPKG / Simulator
  -> IOInterfacePKG
  -> TopoManagerPKG
  -> DeviceModelPKG
  -> LoaderServicesPKG
  -> AnalysisPKG
  -> LinearAlgebraServicesPKG
  -> NonlinearSolverPKG
  -> TimeIntegrationPKG
  -> ParallelDistPKG / UtilityPKG / ErrorHandlingPKG
```

这条主线不是严格的一次性调用栈，而是一条“结构导航主线”：

- 先抓总控
- 再看输入和电路构建
- 再看分析和求解
- 最后补横向基础设施

## 推荐阅读顺序

### 第一步：看入口

先看：

- `src/Xyce.C`

这一步的目标很简单：

- 确认程序从哪里开始
- 确认顶层 simulator 是怎么被创建和调用的

这一步不要陷进细节，只要把“入口交给谁”看清楚。

### 第二步：看顶层总控

接着看：

- `src/CircuitPKG/N_CIR_Xyce.h`
- `src/CircuitPKG/N_CIR_Xyce.C`

这一步是第一轮阅读里最关键的一步。

目标是搞清：

- 顶层类是谁
- 初始化阶段怎样拆分
- 哪些核心子系统被持有和调度

如果这一步没看清，后面读各包会像看很多孤岛。

### 第三步：看输入与电路构建链

接下来读：

- `src/IOInterfacePKG/`
- `src/TopoManagerPKG/`
- `src/DeviceModelPKG/`
- `src/LoaderServicesPKG/`

这一段要建立的认识是：

- 外部 netlist 怎样进入系统
- 拓扑怎样建立
- 器件怎样被实例化
- 器件贡献怎样进入求解系统

这是从“文本电路”走向“内部方程系统”的主桥梁。

### 第四步：看分析与求解链

然后再读：

- `src/AnalysisPKG/`
- `src/LinearAlgebraServicesPKG/`
- `src/NonlinearSolverPKG/`
- `src/TimeIntegrationPKG/`

这一段的目标是：

- 看懂不同分析类型如何组织
- 看懂线性和非线性求解基础设施怎样接入
- 看懂瞬态分析为何需要时间积分层

这时你才真正开始理解“Xyce 怎样算起来”。

### 第五步：补横向基础设施

最后再看：

- `src/ParallelDistPKG/`
- `src/UtilityPKG/`
- `src/ErrorHandlingPKG/`

这一步不是因为它们不重要，而是因为：

- 先看它们，容易失去主线
- 先建立主流程，再回头看横向基础设施，理解会更稳

## 当前阶段哪些内容可以先不深读

第一轮结构阅读时，可以先不深读这些内容：

- `distribution/`
- `gitlab-ci/`
- `config/`
- `user_plugin/`
- `src/MultiTimePDEPKG/`
- `src/DakotaLinkPKG/`
- 各种细分器件模型子目录的具体实现

原因不是它们不重要，而是它们不适合作为“整体结构入门”的第一批材料。

## 为什么这个顺序更稳

这个顺序的好处是：

1. 先抓总控，再看子系统，不会迷路
2. 先看“电路怎样进入系统”，再看“系统怎样求解”，逻辑自然
3. 把横向基础设施放后面，更容易看出它们在主线里的支撑作用

它和“按目录顺序扫一遍”相比，最大的优势是：

- 读者更容易形成一张真正可导航的脑内地图

## 读完这组总览文件后，下一步该去哪

如果这一组 `01-overview/` 已经读完，后续最自然的去向通常是：

1. 去 `02-startup/`，把启动与顶层 `Simulator` 主线真正走一遍
2. 去 `03-netlist-and-circuit-build/`，开始细化输入与构建链
3. 去 `05-analysis-flow/` 和 `06-solver-and-assembly/`，把分析与求解层拆开读

## 这一篇的核心结论

Xyce 的整体结构最适合按下面这句话来记：

> 从 `Xyce.C` 进入，先抓 `CircuitPKG` 这个总控点，再沿“输入与拓扑 -> 器件与装配 -> 分析与求解 -> 横向基础设施”这条主线往下读。
