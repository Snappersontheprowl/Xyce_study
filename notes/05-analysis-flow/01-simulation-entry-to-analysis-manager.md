# simulation entry to analysis manager

记录日期：2026-06-04

## 这篇的定位

这一篇只回答分析流程的第一个问题：

```text
初始化做完之后，
Xyce 是怎样从 Simulator 进入分析层的？
```

这篇先不讨论 `.DC`、`.TRAN` 的具体循环，也不讨论 residual / Jacobian 的数学形式。

## 这次读了哪些文件

- [src/CircuitPKG/N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/AnalysisPKG/N_ANP_AnalysisManager.h](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)

## 当前结论先写在前面

从当前源码看，分析层的总入口主线是：

```text
Simulator::runSimulation()
-> AnalysisManager::run()
-> analysisObject_->run()
```

所以第五阶段里最应该先稳住的一件事是：

```text
分析流程的总调度中心是 AnalysisManager
```

## 从 Simulator 往下看

在：

- [N_CIR_Xyce.C](../../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)

里，初始化完成之后会进入：

- `Simulator::runSimulation()`

虽然这一层不会展开每一种分析的细节，但调用关系会把控制权交给：

- `analysisManager_->run()`

所以从学习顺序上，分析专题真正的第一个核心文件不是 `Transient.C`，而是：

- [N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)

## 为什么要先看 AnalysisManager

如果一上来就分别读 `DCSweep` 和 `Transient`，会很容易只看到“某一种分析怎么跑”，却不知道“是谁在统一组织这些分析”。

而 `AnalysisManager` 正好把最上层骨架收拢起来。

从头文件：

- [N_ANP_AnalysisManager.h](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)

先看这些成员和接口就够了：

- `run()`
- `allocateAnalysisObject(...)`
- `initializeSolverSystem(...)`
- `analysisMode_`
- `analysisObject_`
- `primaryAnalysisObject_`

这说明它至少同时管两件事：

1. 分析对象选择
2. 分析运行前的基础设施准备

所以这篇最重要的认识就是：

```text
AnalysisManager 不是某一种 analysis 的实现类，
而是分析层的总调度器。
```

## AnalysisManager::run() 在做什么

继续看：

- [N_ANP_AnalysisManager.C](../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
  里的 `AnalysisManager::run()`

它本身并不直接实现：

- DC sweep loop
- transient time stepping loop

它更像是在做：

1. 检查有没有当前分析对象
2. 准备输出环境
3. 准备若干运行时上下文
4. 把控制权交给：

```cpp
analysisObject_->run();
```

所以从调度视角看，它的职责可以先压成：

```text
准备分析运行环境
-> 把控制权交给当前顶层分析对象
```

## 这一篇的边界

到这里为止，这篇只想让“总入口”这件事稳定下来：

- `Simulator` 负责把控制权交给分析层
- `AnalysisManager` 负责组织分析层
- 真正的 `.DC` / `.TRAN` 细节要到后面的生命周期笔记再展开

而关于：

- residual / Jacobian
- `NO_TIME_INTEGRATION`
- `dQ/dt + F - B = 0`

这些都属于 [06-solver-and-assembly](../06-solver-and-assembly/README.md)。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么在分析专题里，最值得先站稳的是 `AnalysisManager`，而不是直接钻进 `Transient`？
2. `AnalysisManager::run()` 的核心职责，更像“自己跑完整个仿真”，还是“准备环境后把控制权交给具体分析对象”？
