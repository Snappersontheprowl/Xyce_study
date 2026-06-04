# analysis lifecycle of dc and tran

记录日期：2026-06-04

## 这篇的定位

这一篇只回答：

```text
DCSweep 和 Transient 在控制流程上分别怎么跑起来？
```

这里的重点是生命周期结构，不是方程细节。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_DCSweep.h](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.h)
- [src/AnalysisPKG/N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_Transient.h](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.h)
- [src/AnalysisPKG/N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)

## 当前结论先写在前面

从控制流程上看，这两类分析都可以先压成：

```text
doInit()
-> doLoopProcess()
-> doFinish()
```

但 `Transient` 比 `DCSweep` 多出一个关键阶段：

```text
doTranOP()
```

所以生命周期上最值得先记住的是：

```text
.DC  = 初始化 + sweep loop + 收尾
.TRAN = 初始化 + DCOP 预处理 + time stepping loop + 收尾
```

## `.DC` 的生命周期

看：

- [N_ANP_DCSweep.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
  里的 `DCSweep::doRun()`

它很清楚地组织成：

```text
doInit()
-> doLoopProcess()
-> doFinish()
```

### `doInit()` 在做什么

在：

- `DCSweep::doInit()`

里，最关键的动作有：

- 把 `.DC` 参数整理成 `dcSweepVector_`
- `setupSweepLoop(...)`
- 设置输出的 DC sweep 上下文
- 把 time integration method 设成 `NO_TIME_INTEGRATION`

从生命周期视角看，这一步最重要的意义是：

```text
告诉系统：接下来要做的是一系列 operating point calculations
```

### `doLoopProcess()` 在做什么

这一层从控制流角度先理解成就够了：

- 对每个 sweep point
- 更新扫值
- 执行一次 operating point 求解
- 处理输出和推进

这里先不展开 Newton 细节，因为那属于 `06`。

## `.TRAN` 的生命周期

看：

- [N_ANP_Transient.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)
  里的 `Transient::doRun()`

它的结构是：

```text
doInit()
-> doTranOP()
-> doLoopProcess()
-> doFinish()
```

### `doInit()` 在做什么

`Transient::doInit()` 这一层更偏“时间推进前的准备”，包括：

- 配 breakpoints
- 决定是否先做 DCOP
- 设定 time integration method
- 处理 `.IC` / `.NODESET` / restart / UIC / NOOP

这一步先不要把它理解成“求解器本体”，而要理解成：

```text
为 time stepping 建立运行条件
```

### `doTranOP()` 为什么重要

这是 `.TRAN` 生命周期里最关键的一个额外阶段。

它说明：

```text
Transient 通常不会直接进入时间步进，
而是先做一次 DC operating point 初始化
```

这也是 `.TRAN` 和 `.DC` 在控制流程上的重要关系点。

### `doLoopProcess()` 在做什么

从控制流角度看，这里才是真正的 time stepping loop：

- 取下一步
- 调用瞬态步进流程
- 检查是否接受当前步
- 推进输出和时间状态

但这一篇先不深入“每一步具体在解什么方程”，因为那已经是 [06-solver-and-assembly](../06-solver-and-assembly/README.md) 的主题。

## 这一篇最想让你先吃下来的本质

从控制流程层面，`.DC` 和 `.TRAN` 的主要差别不在“底层容器对象完全不同”，而在：

```text
一个是 sweep control flow
一个是 time stepping control flow
```

所以这一篇读完之后，最重要的是先把生命周期结构稳定记住，而不要急着把它和 residual / Jacobian 混在一起。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `.TRAN` 比 `.DC` 多出来的关键生命周期阶段是 `doTranOP()`？
2. 在这一篇里，我们为什么只强调“控制流程”，而故意不展开每一步里的 Newton 方程？
