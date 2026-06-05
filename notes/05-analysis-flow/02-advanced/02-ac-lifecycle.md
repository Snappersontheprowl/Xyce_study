# ac lifecycle

记录日期：2026-06-05

## 这篇的定位

这一篇只回答：

```text
AC analysis 在分析调度层是怎么被注册、创建并跑起来的？
```

这篇故意不展开 small-signal 数学方程，只看控制流和生命周期。

## 这次读了哪些文件

- [src/AnalysisPKG/N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)
- [src/AnalysisPKG/N_ANP_AnalysisManager.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AnalysisManager.C)
- [src/AnalysisPKG/N_ANP_AC.h](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.h)
- [src/AnalysisPKG/N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)

## 当前结论先写在前面

从分析调度视角看，`AC` 的主线可以先压成：

```text
registerACFactory(...)
-> AnalysisManager 选中 AC analysis object
-> AC::doRun()
-> doInit()
-> doLoopProcess()
-> doFinish()
```

其中最值得先记住的一点是：

```text
AC 不是直接从零开始做频域求解，
而是先做一次 DC operating point，
然后再进入 frequency sweep loop。
```

## AC 在哪里注册

先看：

- [N_ANP_RegisterAnalysis.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_RegisterAnalysis.C)

这里会统一调用：

- `registerACFactory(factory_block);`

再跳到：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `registerACFactory(...)`

这里做了三件关键事：

1. 创建 `ACFactory`
2. `addAnalysisFactory(factory_block, factory);`
3. 注册 `.AC` parser：

```cpp
factory_block.optionsManager_.addCommandParser(".AC", extractACData);
```

所以从注册视角看，`AC` 的入口关系是：

```text
.AC
-> extractACData
-> ACFactory
-> AnalysisManager 可选中的 analysis creator
```

## ACFactory 在创建什么

继续看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `ACFactory::create()`

这里最关键的动作是：

- `analysisManager_.setAnalysisMode(ANP_MODE_AC);`
- `new AC(...)`

然后把：

- analysis params
- time integrator options
- `LINSOL-AC`
- `LINSOL`

这些配置块灌进 `AC` 对象。

这一步从调度角度最值得记住的是：

```text
AC analysis object 不是 AnalysisManager 手写 new 出来的，
而是通过注册好的 ACFactory 统一创建的。
```

## AC::doRun() 的生命周期结构

再看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `AC::doRun()`

它的结构非常清楚：

```cpp
return doInit() && doLoopProcess() && doFinish();
```

所以在控制流层面，`AC` 和前面学过的 `DCSweep` 其实很像：

```text
doInit()
-> doLoopProcess()
-> doFinish()
```

但它的 `doInit()` 语义和 `DCSweep` 又不一样。

## AC::doInit() 在做什么

`AC::doInit()` 里最关键的几步是：

1. 整理 frequency sweep 参数
2. 把 `baseIntegrationMethod_` 设成：
   - `NO_TIME_INTEGRATION`
3. 先求一次 DC operating point
4. 装载 AC 用的 `B` 向量
5. 准备 S-parameter / sensitivity 等额外结构

其中最值得先抓住的是两点。

### 1. AC 仍然先走 DCOP

在 `doInit()` 中会显式调用：

- `nonlinearManager_.solve();`

而且这一步发生在 frequency loop 之前。

这说明从生命周期角度看：

```text
AC 并不是“直接按频率扫点开始算”，
而是先建立一个 DC operating point 作为后续小信号分析的基点。
```

### 2. AC 在控制流上不做 time stepping

它同样把 integration method 设成：

- `NO_TIME_INTEGRATION`

但这里的含义和 `DC sweep` 也不同：

- `DC` 是因为它本来就在做 operating point family
- `AC` 则是因为它不是时域步进分析

所以这一步先从调度层面记成：

```text
AC 不进入 transient 那种 time stepping lifecycle
```

## AC::doLoopProcess() 在做什么

再看：

- [N_ANP_AC.C](../../../vendor/Xyce-7.10.0/src/AnalysisPKG/N_ANP_AC.C)
  里的 `AC::doLoopProcess()`

这里的控制流可以先压成：

```text
更新当前频点
-> 更新 AC 线性系统
-> solveLinearSystem_()
-> 处理成功/失败
```

也就是说，`AC` 的 loop 是：

```text
frequency sweep loop
```

而不是：

- time stepping loop
- parameter stepping loop

这正是它和 `Transient` 在生命周期上的最大区别。

## 这一篇最想让你先吃下来的本质

从分析调度层看，`AC` 的身份可以先这样理解：

```text
它是一个“先做 DCOP，再做 frequency sweep”的 analysis object
```

所以这篇读完之后，最重要的不是记住所有 `AC` 成员，而是先把下面这条控制流站稳：

```text
.AC
-> registerACFactory
-> ACFactory::create
-> AC::doRun
-> doInit 里先做 DCOP
-> doLoopProcess 里做 frequency sweep
```

而关于：

- 小信号线性化
- `G + jωC`
- block matrix

这些内容要放到 [../../06-solver-and-assembly/02-advanced/README.md](../../06-solver-and-assembly/02-advanced/README.md) 那一边讲。

## 现在可以做的自检

你可以先试着回答这两个问题：

1. 为什么说 `AC` 在生命周期上最关键的特征，不是“它也有 doLoopProcess”，而是“它先做 DCOP，再做 frequency sweep”？
2. 为什么这一篇里我们刻意不展开 `G + jωC` 的数学，而只讲 `doInit()` 和 `doLoopProcess()`？
