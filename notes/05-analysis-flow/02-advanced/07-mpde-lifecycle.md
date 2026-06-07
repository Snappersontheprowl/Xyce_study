# mpde lifecycle

记录日期：2026-06-07

## 这篇的定位

这一篇只回答：

```text
MPDE analysis 在分析调度层是怎么被注册、创建并跑起来的？
```

这一篇故意不展开多时间尺度方程本身，只看：

- `.MPDE` 在哪里注册
- `MPDEFactory` 怎样创建 analysis object
- 为什么 `MPDE` 的真正控制流重心不在 `MPDE::doInit()`，而在 `N_MPDE_Manager::run(...)`
- 为什么它最终会回落成“一个 block-vector transient 分析”

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_MPDE.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_MPDE.h)
- [src/AnalysisPKG/N_ANP_MPDE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_MPDE.C)
- [src/MultiTimePDEPKG/N_MPDE_Manager.h](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Manager.h)
- [src/MultiTimePDEPKG/N_MPDE_Manager.C](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Manager.C)

## 当前结论先写在前面

从分析调度视角看，`MPDE` 的主线可以先压成：

```text
registerMPDEFactory(...)
-> AnalysisManager 选中 MPDE analysis object
-> MPDEFactory::create()
-> MPDE::doRun()
-> N_MPDE_Manager::run(...)
   -> initializeAll()
   -> runInitialCondition()
   -> setupMPDEProblem_()
   -> runMPDEProblem_()
```

这一条线和 `AC/NOISE/HB` 的最大不同是：

```text
MPDE 的 analysis object 更像一个薄壳，
真正的生命周期编排主要压在 N_MPDE_Manager 里。
```

## MPDE 在哪里注册

先看：

- [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这里统一调用：

- `registerMPDEFactory(factory_block);`

再跳到：

- [N_ANP_MPDE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_MPDE.C)
  里的 `registerMPDEFactory(...)`

这里最值得先记住的几件事是：

1. 创建 `MPDEFactory`
2. `addAnalysisFactory(factory_block, factory);`
3. 注册 `.MPDE` parser：

```cpp
factory_block.optionsManager_.addCommandParser(".MPDE", extractMPDEData);
```

4. 注册 `MPDE` / `MPDEINT` / `TIMEINT-MPDE` / `LINSOL` 这几组配置入口

所以从注册视角看，入口关系是：

```text
.MPDE
-> extractMPDEData
-> MPDEFactory
-> AnalysisManager 可选中的 analysis creator
```

## MPDEFactory 在创建什么

继续看：

- `MPDEFactory::create()`

这里的关键动作是：

- `analysisManager_.setAnalysisMode(ANP_MODE_MPDE);`
- `new MPDE(...)`

然后把四类参数灌进新对象内部的 `mpdeManager_`：

- `setMPDEAnalysisParams(...)`
- `setMPDEOptions(...)`
- `setTransientOptions(...)`
- `setLinSolOptions(...)`

这一点很重要，因为它说明：

```text
MPDE 的 netlist 入口并不只是 .MPDE 本身，
它还会额外吃进 MPDEINT、TIMEINT-MPDE、LINSOL 这些配置。
```

也就是说，`MPDE` 在调度层已经暗示了：

```text
它不是一个“单纯换个 analysisMode 就能跑”的分析，
而是一整套多时间尺度求解环境。
```

## MPDE::doRun() 为什么比 HB/AC 更薄

再看：

- [N_ANP_MPDE.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_MPDE.C)

最值得先抓的是：

- `MPDE::doRun()`

它几乎没有像 `HB::doInit()` 那样在本类里铺开很多阶段，而是直接：

```cpp
mpdeManager_->run(linearSystem_, nonlinearManager_, topology_);
```

所以这里最值得先建立的认识是：

```text
MPDE analysis object 自己并不是主要调度中心，
真正的控制流在 MultiTimePDEPKG 的 N_MPDE_Manager 里。
```

这也是为什么：

- `MPDE::doInit()`
- `MPDE::doLoopProcess()`
- `MPDE::doProcessSuccessfulStep()`

这些函数在当前实现里都非常薄，很多直接返回 `false`，因为真正的运行阶段已经被下沉到 manager。

## N_MPDE_Manager::run(...) 是真正的生命周期主线

再看：

- [N_MPDE_Manager.C](../../../vendor/Xyce-7.10.0/src/MultiTimePDEPKG/N_MPDE_Manager.C)

这里最值得先抓住的是：

- `N_MPDE_Manager::run(...)`

它的顺序很清楚：

1. `initializeAll(...)`
2. `runInitialCondition(...)`
3. `setupMPDEProblem_()`
4. `runMPDEProblem_()`

所以从生命周期视角，可以先把 `MPDE` 理解成：

```text
先准备多时间尺度环境
-> 先构造 MPDE 所需初值
-> 再搭 block-vector MPDE 问题
-> 最后把这个问题交给真正的求解阶段
```

## 为什么 MPDE 要先跑一段“初值阶段”

`N_MPDE_Manager` 里最醒目的一个阶段就是：

- `runInitialCondition(...)`

再往下还能看到它会按配置走不同路径：

- `runDCOP(...)`
- `runStartupPeriods(...)`
- `runTransientIC(...)`

这说明从控制流视角看，`MPDE` 并不假设：

```text
一开始就已经有一份可用的多时间尺度 block 解
```

相反，它经常要先借：

- `DCOP`
- 一段 startup transient
- 一段普通 transient

来构造适合 `MPDE` 的初始块向量和 fast-time 采样点。

所以这一层和 `HB` 很像的一点是：

```text
MPDE 也经常需要借基础分析类型来“喂初值”
```

## setupMPDEProblem_() 在生命周期里做什么

接着看：

- `setupMPDEProblem_()`

这里从调度角度最值得先记的是三类动作：

1. `analysisManager_.resetSolverSystem();`
   - 先把初值阶段用过的 solver 系统拆掉

2. 构造 MPDE 专用基础设施
   - `N_MPDE_Builder`
   - `N_MPDE_Loader`
   - block matrix / block vector

3. 再重新初始化 MPDE phase 的 solver stack
   - `initializeSolverSystem(...)`
   - `nonlinearManager_.initializeAll(...)`

这一层最该先记住的一句是：

```text
MPDE 在真正开跑之前，也像 HB 一样，会先切换到一套新的“问题形状”：
从普通电路系统切到 block-vector / multi-time 的系统。
```

## runMPDEProblem_() 为什么最终又回到了 Transient

这是 `MPDE` 生命周期里最值得先抓住的一点。

看：

- `runMPDEProblem_()`

这里并没有新造一个完全独立的大求解壳，而是：

1. 把 `nextSolution / nextState / daeQ / nextStore` 先灌成 MPDE 初值
2. `analysisManager_.setAnalysisMode(ANP_MODE_TRANSIENT);`
3. 直接构造一个：

```cpp
Transient transient(..., *mpdeLoaderPtr_, ..., this);
```

4. 再让：

```cpp
returnValue = transient.run();
```

所以从生命周期角度最关键的一句话是：

```text
MPDE 并不是抛弃 transient，
而是把“单一时间轴上的 transient”
替换成“以 block-vector MPDE 系统为未知量的 transient 外壳”。
```

这就是 `MPDE` 和 `HB` 的又一个重要分水岭：

- `HB` 更像直接改成周期稳态 nonlinear 平衡
- `MPDE` 更像保留慢时间推进，但把单状态变量换成多时间尺度块变量

## 当前这篇最想让你先吃下来的本质

如果只抓一句话，我希望你先抓住：

```text
MPDE 在调度层的关键，
不是 MPDE 类本身有多复杂，
而是它把真正的生命周期编排下沉到 N_MPDE_Manager，
然后在最终求解阶段重新借用一个“Transient 外壳”
来推进 block-vector 的多时间尺度系统。
```

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么 `MPDE::doRun()` 本身很薄，但这不代表 `MPDE` 生命周期简单？
2. 为什么 `runMPDEProblem_()` 最后重新构造 `Transient transient(..., *mpdeLoaderPtr_, ...)`，从调度角度看反而是合理的？
