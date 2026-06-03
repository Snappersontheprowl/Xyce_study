# 2026-06-02 analysis flow

## 这次读了哪些文件

这次按“从 `Simulator::runSimulation()` 进入分析流程”的顺序读了这些文件：

- [src/CircuitPKG/N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_AnalysisManager.h](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/AnalysisPKG/N_ANP_DCSweep.h](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.h)
- [src/AnalysisPKG/N_ANP_DCSweep.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C)
- [src/AnalysisPKG/N_ANP_Transient.h](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.h)
- [src/AnalysisPKG/N_ANP_Transient.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C)
- [src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C](../vendor/Xyce-7.10.0/src/LoaderServicesPKG/N_LOA_NonlinearEquationLoader.C)

## 这次带着什么问题去读

第五阶段的大纲要求是弄清：

- `.OP`、`.DC`、`.TRAN` 分别在哪里处理
- 分析类型由哪部分代码分发
- 各种分析共用了哪些基础设施
- 直流工作点求解和瞬态步进之间是什么关系

这次先不追 AC、HB、NOISE 这些分支，只抓最核心、最常见的三类：

- `.OP`
- `.DC`
- `.TRAN`

## 当前结论先写在前面

从当前源码看，分析流程的总入口是：

```text
Simulator::runSimulation()
-> AnalysisManager::run()
-> 当前 analysisObject_->run()
```

这里的关键点是：

- `AnalysisManager` 负责选择和组织分析对象
- `.TRAN` 对应 `Transient`
- `.DC` 对应 `DCSweep`
- `.OP` 不是一个完全独立的主分析类，它更多像是“要求做 DC operating point”的一个开关，最终通常落到 `DCSweep` 或别的分析类中的 DCOP 路径

所以第五阶段的第一层认识可以先记成：

```text
分析流程调度中心 = AnalysisManager
主分析对象 = DCSweep / Transient / AC / HB / ...
.OP = 触发 DC operating point 行为，而不一定是独立的主分析类型
```

## 从 `Simulator::runSimulation()` 往下看

前面几阶段已经看到，初始化完成之后，Xyce 才真正进入仿真运行阶段。

这一段的总入口在：

- [N_CIR_Xyce.C](../vendor/Xyce-7.10.0/src/CircuitPKG/N_CIR_Xyce.C)
  中的 `Simulator::runSimulation()`

虽然这次没有专门去展开整个 `runSimulation()` 的每一行，但从调用关系看，分析层真正的入口会落到：

- `analysisManager_->run()`

所以第五阶段最重要的第一个文件是：

- [N_ANP_AnalysisManager.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)

## 为什么先看 `AnalysisManager`

如果一上来分别去读 `Transient.C` 和 `DCSweep.C`，会很容易失去整体视角。

`AnalysisManager` 的作用正好是把全局骨架收拢起来。

在头文件里就已经能看出来：

- [N_ANP_AnalysisManager.h](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h)

这里最值得先注意的成员和接口有：

- `allocateAnalysisObject(...)`
- `initializeSolverSystem(...)`
- `run()`
- `analysisMode_`
- `analysisObject_`
- `primaryAnalysisObject_`
- `workingIntgMethod_`
- `stepErrorControl_`
- `nonlinearEquationLoader_`
- `dataStore_`

这说明它既管：

- 分析对象的选择
- 又管 time integration / step control / loader / datastore 这些基础设施

所以它不是“某一种分析的实现类”，而是：

```text
分析流程的总调度器
```

## 分析类型是在哪里注册进去的

分析类型不是写死在 `AnalysisManager` 构造函数里的，而是通过注册机制接进来的。

先看：

- [N_ANP_RegisterAnalysis.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这个文件里有：

- `registerAnalysisFactory(...)`

在这里，会依次注册：

- `registerDCSweepFactory(...)`
- `registerACFactory(...)`
- `registerTransientFactory(...)`
- `registerHBFactory(...)`
- `registerMPDEFactory(...)`
- `registerNOISEFactory(...)`
- `registerMORFactory(...)`
- `registerStepFactory(...)`
- `registerSamplingFactory(...)`
- `registerEmbeddedSamplingFactory(...)`

所以分析系统的整体思路是：

```text
先注册各种 analysis factory
-> netlist 解析时把相应语句挂到 factory / options manager
-> allocateAnalysisObject() 再从已注册的 creator 中选出当前分析对象
```

## `.DC` 和 `.TRAN` 的 parser 入口分别在哪里

这一点最好先看 factory 注册函数，因为它能直接告诉你：

- 哪种网表语句会创建哪种分析对象

### `.DC`

在：

- [N_ANP_DCSweep.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C) 第 1194 行附近
  `registerDCSweepFactory(...)`

这里注册了：

- `.DC` -> `extractDCData`
- `.OP` -> `extractOPData`

也就是：

```text
.DC 和 .OP 都先挂到 DCSweep 相关的注册路径上
```

这非常重要，因为它解释了一个表面上有点反直觉的事实：

- `.OP` 并不是单独一个 `OpAnalysis` 主类
- 它和 `DCSweep` 的逻辑关系非常近

### `.TRAN`

在：

- [N_ANP_Transient.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C) 第 4529 行附近
  `registerTransientFactory(...)`

这里注册了：

- `.TRAN` -> `extractTRANData`
- `.TR` -> `extractTRANData`

所以 `.TRAN` 的入口就很直接：

```text
.TRAN / .TR
-> TransientFactory
-> Transient analysis object
```

## `.OP` 为什么不能简单理解成“单独一个分析类”

- `.OP` 是一种 operating point 请求
- 在“没有别的主分析”时，会借用 `DCSweep` 来完成 DC operating point 流程
- 在 `.TRAN`、`.AC` 等分析里，它又可能作为“先做 DCOP 初始化”的一部分存在

## `AnalysisManager::allocateAnalysisObject()` 在做什么

继续看：

- [N_ANP_AnalysisManager.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C) 第 580 行附近
  `allocateAnalysisObject(...)`

这是第五阶段最重要的函数之一。

它大致做了三层事：

### 第一层：处理 “只有 `.OP`” 的特殊情况

如果：

- 有 `.OP`
- 但没有别的主分析类型

那么它会创建一个 `DCSweep` 作为 `primaryAnalysisObject_`，并把：

- `analysisMode_ = ANP_MODE_DC_SWEEP`

### 第二层：找出真正的 primary analysis

然后它会遍历 `analysisCreatorVector_`，把不是这些包装层的 creator 选出来：

- `Step`
- `Sampling`
- `EmbeddedSampling`
- `PCE`

这些不是 primary analysis。

真正的 primary analysis 可能是：

- `DCSweep`
- `Transient`
- `AC`
- `HB`
- `MPDE`
- `NOISE`
- `MOR`
- `ROL`

### 第三层：如果有外层包装分析，就把它作为 `analysisObject_`

比如：

- `.STEP`
- `Sampling`
- `EmbeddedSampling`

这时候：

- `primaryAnalysisObject_` 是里面真正干活的分析
- `analysisObject_` 则可能是外层的驱动包装器

所以这两个成员的区别非常值得记：

```text
primaryAnalysisObject_ = 真正的底层分析类型
analysisObject_        = 实际被 run() 调用的顶层驱动对象，可能是包装器
```

## `AnalysisManager::run()` 是怎么分发的

接着看：

- [N_ANP_AnalysisManager.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C) 第 526 行附近
  `AnalysisManager::run()`

这个函数本身并不直接实现 DC loop 或 transient loop。

它主要做的是：

1. 检查是否有主分析对象
2. 准备输出器
3. 让 `ActiveOutput` 按当前 `analysisMode_` 配好输出环境
4. 让 `nonlinearEquationLoader_` 加载 device error weight mask
5. 最后调用：

```cpp
runStatus = analysisObject_->run();
```

所以它本质上是在做：

```text
准备分析运行环境
-> 把控制权交给当前分析对象
```

也就是说，分析模式的“真正流程”不在 `AnalysisManager::run()` 内部展开，而是在：

- `DCSweep::doRun()`
- `Transient::doRun()`

这些具体分析类里。

## `.DC` 是怎么运行起来的

看：

- [N_ANP_DCSweep.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C) 第 276 行附近
  `DCSweep::doRun()`

它很清楚：

```text
doInit()
-> doLoopProcess()
-> doFinish()
```

这说明 DC sweep 是一个典型的“初始化 + sweep loop + 收尾”结构。

再看：

- [N_ANP_DCSweep.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_DCSweep.C) 第 289 行附近
  `DCSweep::doInit()`

这里最关键的动作有：

- 把 `.DC` 参数转换成 `dcSweepVector_`
- `setupSweepLoop(...)`
- 设置 `outputManagerAdapter_` 的 DC sweep 信息
- 把 time integration method 设成：
  - `NO_TIME_INTEGRATION`

这很重要，因为它说明：

```text
DC sweep 的本质是一系列 operating point 求解
不是时间步进
```

所以 `.DC` 的主流程可以先记成：

```text
.DC
-> DCSweep
-> setup sweep parameters
-> integration method = none
-> 对每个扫点做 DC operating point 求解
```

## `.TRAN` 是怎么运行起来的

看：

- [N_ANP_Transient.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C) 第 739 行附近
  `Transient::doRun()`

这里的总结构是：

```text
doInit()
-> doTranOP()
-> doLoopProcess()
-> doFinish()
```

跟 `DCSweep` 相比，瞬态多出来了一个非常关键的阶段：

- `doTranOP()`

这已经非常直观地回答了你大纲里的一个问题：

```text
瞬态分析通常不是直接进入时间步进
而是先做一个 DC operating point 初始化
```

再看：

- [N_ANP_Transient.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C) 第 839 行附近
  `Transient::doInit()`

这里做的事情主要是：

- 配 breakpoints
- 决定是否先做 DCOP
- 设置 time integration method
- 处理 `.IC` / `.NODESET` / restart / UIC/NOOP
- 需要时分配 transient solver

然后：

- [N_ANP_Transient.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C) 第 1056 行附近
  `Transient::doTranOP()`

这里专门负责 transient 开始前的 DC operating point 计算。

最后：

- [N_ANP_Transient.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_Transient.C) 第 1178 行附近
  `Transient::doLoopProcess()`

这里才是真正的时间步进循环。

所以 `.TRAN` 的主流程可以先记成：

```text
.TRAN
-> Transient::doInit()
-> 先做 doTranOP() 的 DC operating point 初始化
-> 再进入 doLoopProcess() 的 time stepping loop
```

## `.DC` 和 `.TRAN` 共用了什么基础设施

这是第五阶段另一个重点。

看：

- [N_ANP_AnalysisManager.C](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C) 第 408 行附近
  `initializeSolverSystem(...)`

这个函数会重新创建几类核心对象：

- `TimeIntg::DataStore`
- `TimeIntg::WorkingIntegrationMethod`
- `TimeIntg::StepErrorControl`
- `Loader::NonlinearEquationLoader`

再结合头文件里的成员：

- [N_ANP_AnalysisManager.h](../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.h) 第 560 行附近

可以把共用基础设施先归纳成：

### 1. `DataStore`

保存：

- solution / state / store 各类向量
- Jacobian / RHS 指针
- 分析过程中共享的数据

### 2. `WorkingIntegrationMethod`

负责当前 time integration method 的工作对象。  
即使 `.DC` 最后用的是 `NO_TIME_INTEGRATION`，也仍然经过这套统一框架。

### 3. `StepErrorControl`

负责：

- 时间步相关控制
- breakpoints
- stop time / next time / final time

对 `.TRAN` 非常关键，对 `.DC` 也复用了一部分统一接口。

### 4. `NonlinearEquationLoader`

负责把 device 层贡献装配成 nonlinear residual / Jacobian。

这和前一阶段你看的 resistor `loadDAEVectors/loadDAEMatrices` 是直接衔接的。

### 5. `Loader`、`Linear::System`、`Nonlinear::Manager`

这些对象被具体分析类共同使用。

所以第五阶段很值得先建立一个认识：

```text
分析类之间差别最大的部分是“控制流程”
而不是“底层求解基础设施”
```

## 直流工作点和瞬态之间的关系

这一点可以先直接总结。

从当前代码看：

- `.DC` 本质上就是 operating point 求解在不同扫点上的重复执行
- `.TRAN` 通常先做一个 DC operating point 初始化，然后才开始时间步进
- `.OP` 则更像“只请求 operating point”这一种特殊情形

所以三者的关系可以先画成：

```text
.OP
-> 做一次 DC operating point

.DC
-> 在多个 sweep point 上重复做 operating point

.TRAN
-> 先做 operating point 初始化
-> 再进入 transient time stepping
```

这比单纯记“文件在哪”更重要，因为这是第五阶段真正的流程理解。

## 当前可以稳定记住的主线

到这一步，当前最值得记住的一条分析调度主线是：

```text
Simulator::runSimulation()
-> AnalysisManager::run()
-> analysisObject_->run()

如果是 .DC:
  -> DCSweep::doRun()
  -> doInit()
  -> doLoopProcess()
  -> doFinish()

如果是 .TRAN:
  -> Transient::doRun()
  -> doInit()
  -> doTranOP()
  -> doLoopProcess()
  -> doFinish()
```

以及：

```text
.OP
-> dotOpSpecified_
-> 特殊情况下由 AnalysisManager 分配一个 DCSweep 作为主分析
```

## 当前结论

这次可以先稳定得出这些结论：

1. 第五阶段的总调度中心是 `AnalysisManager`
2. `.TRAN` 的主实现类是 `Transient`
3. `.DC` 的主实现类是 `DCSweep`
4. `.OP` 不应简单理解为一个完全独立的主分析类，它更多是 operating point 请求，很多时候落到 `DCSweep` 路径
5. `.TRAN` 和 `.DC` 的差别主要体现在控制流程，不在底层公共求解基础设施
6. `DataStore`、`WorkingIntegrationMethod`、`StepErrorControl`、`NonlinearEquationLoader` 是几类分析共享的关键基础设施
7. 瞬态分析和直流工作点之间的关系非常紧：瞬态通常先做 DCOP 初始化，再进入 time stepping

## 下一步还要继续追踪什么

第五阶段下一步最自然的是继续做两件事里的一个：

1. 继续深挖 `.TRAN` 的时间步进循环  
   重点看：
   - `Transient::doLoopProcess()`
   - 成功步 / 失败步的处理
   - time step acceptance / rejection

2. 继续深挖 `.DC` 的 sweep loop  
   重点看：
   - `DCSweep::doLoopProcess()`
   - 每个 sweep point 怎么更新源
   - 每一步 operating point 求解之后怎么输出

如果只选一个更符合当前主线的，我更建议：

```text
先追 .TRAN
```

因为它最能把：

- analysis control flow
- DCOP
- nonlinear solve
- time integration

这几层一起串起来。
